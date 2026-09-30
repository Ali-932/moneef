import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';
import '../models/app_settings.dart';
import '../models/category.dart';
import '../models/currency.dart';
import '../models/dashboard.dart';
import '../models/exchange_rate.dart';
import '../models/paginated.dart';
import '../models/transaction.dart';
import 'bootstrap.dart';

// ── categories ──────────────────────────────────────────────────────

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final boot = ref.watch(bootControllerProvider);
  if (boot.stage != BootStage.ready) return <Category>[];
  final api = ref.watch(nativeApiProvider);
  final raw = await api.listCategories();
  return raw
      .cast<Map<String, dynamic>>()
      .map(Category.fromJson)
      .toList(growable: false);
});

/// Categories that already have at least one transaction. Used by the
/// Transactions screen filter chips ("Food", "Entertainment", …).
final usedCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final boot = ref.watch(bootControllerProvider);
  if (boot.stage != BootStage.ready) return <Category>[];
  final api = ref.watch(nativeApiProvider);
  final raw = await api.listCategories(used: true);
  return raw
      .cast<Map<String, dynamic>>()
      .map(Category.fromJson)
      .toList(growable: false);
});

// ── currencies ──────────────────────────────────────────────────────

final currenciesProvider = FutureProvider<List<Currency>>((ref) async {
  final boot = ref.watch(bootControllerProvider);
  if (boot.stage != BootStage.ready) return <Currency>[];
  final api = ref.watch(nativeApiProvider);
  final raw = await api.listCurrencies();
  return raw
      .cast<Map<String, dynamic>>()
      .map(Currency.fromJson)
      .toList(growable: false);
});

// ── profile ─────────────────────────────────────────────────────────

final profileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final boot = ref.watch(bootControllerProvider);
  if (boot.stage != BootStage.ready) return <String, dynamic>{};
  final api = ref.watch(nativeApiProvider);
  return api.getProfile();
});

// ── settings ────────────────────────────────────────────────────────

final settingsProvider = FutureProvider<AppSettings>((ref) async {
  final boot = ref.watch(bootControllerProvider);
  if (boot.stage != BootStage.ready) {
    throw StateError('boot not ready');
  }
  final api = ref.watch(nativeApiProvider);
  final raw = await api.getSettings();
  final settings = AppSettings.fromJson(raw);
  // Cache dark mode so the next cold start paints the right theme instantly
  // (no light flash before settings load).
  unawaited(
    SharedPreferences.getInstance().then(
      (p) => p.setBool(darkModeCacheKey, settings.isDarkMode),
    ),
  );
  return settings;
});

// ── theme ───────────────────────────────────────────────────────────

const darkModeCacheKey = 'moneef.cached_dark_mode';

/// Last-known dark-mode flag, read synchronously before `runApp` (overridden
/// in `main`) so the first frame paints the right theme.
final cachedDarkModeProvider = StateProvider<bool>((_) => false);

final themeModeProvider = Provider<ThemeMode>((ref) {
  final cached = ref.watch(cachedDarkModeProvider);
  final boot = ref.watch(bootControllerProvider);
  final dark = boot.stage != BootStage.ready
      ? cached
      : ref
            .watch(settingsProvider)
            .maybeWhen(data: (s) => s.isDarkMode, orElse: () => cached);
  return dark ? ThemeMode.dark : ThemeMode.light;
});

// ── exchange rates ──────────────────────────────────────────────────

// ── accounts ────────────────────────────────────────────────────────

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final boot = ref.watch(bootControllerProvider);
  if (boot.stage != BootStage.ready) return <Account>[];
  final raw = await ref.watch(nativeApiProvider).listAccounts();
  return raw
      .cast<Map<String, dynamic>>()
      .map(Account.fromJson)
      .toList(growable: false);
});

/// An account's 20 latest [Transaction]s and [Transfer]s, newest first.
final accountActivityProvider = FutureProvider.family<List<Object>, int>((
  ref,
  accountId,
) async {
  final api = ref.watch(nativeApiProvider);
  final page = PaginatedTransactions.fromJson(
    await api.listTransactions({
      'account_id': accountId,
      'sort': '-date',
      'per_page': 20,
    }),
  );
  final transfers = (await api.listTransfers(
    accountId,
  )).cast<Map<String, dynamic>>().map(Transfer.fromJson);
  DateTime dateOf(Object o) => o is Transaction ? o.date : (o as Transfer).date;
  final items = <Object>[...page.results, ...transfers]
    ..sort((a, b) => dateOf(b).compareTo(dateOf(a)));
  return items.take(20).toList(growable: false);
});

final exchangeRatesProvider = FutureProvider<List<ExchangeRate>>((ref) async {
  final boot = ref.watch(bootControllerProvider);
  if (boot.stage != BootStage.ready) return <ExchangeRate>[];
  final api = ref.watch(nativeApiProvider);
  final raw = await api.listExchangeRates();
  return raw
      .cast<Map<String, dynamic>>()
      .map(ExchangeRate.fromJson)
      .toList(growable: false);
});

/// Currencies usable in transactions: the default currency, plus USD and every
/// currency with a USD rate once the default itself converts to USD.
final availableCurrenciesProvider = FutureProvider<List<Currency>>((ref) async {
  final boot = ref.watch(bootControllerProvider);
  if (boot.stage != BootStage.ready) return <Currency>[];

  final settings = await ref.watch(settingsProvider.future);
  final master = await ref.watch(currenciesProvider.future);
  final rates = await ref.watch(exchangeRatesProvider.future);

  final byCode = {for (final c in master) c.code: c};

  final base = settings.currencyCode;
  final codes = <String>{base};
  if (base == 'USD' || rates.any((r) => r.from == base)) {
    codes.add('USD');
    for (final r in rates) {
      if (r.from.isNotEmpty) codes.add(r.from);
    }
  }

  final result = <Currency>[];
  for (final code in codes) {
    result.add(byCode[code] ?? Currency(code: code, name: code, symbol: ''));
  }
  result.sort((a, b) => a.code.compareTo(b.code));
  return result;
});

// ── transactions list filter ────────────────────────────────────────

class TransactionFilter {
  const TransactionFilter({
    this.type = '',
    this.categoryId,
    this.categoryName = '',
    this.dateFrom,
    this.dateTo,
    this.search = '',
    this.sort = '-date',
    this.accountId,
  });

  final String type;
  final int? categoryId;
  final String categoryName;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String search;
  final String sort;
  final int? accountId;

  /// Whether anything narrows the list (sort order doesn't).
  bool get isFiltering =>
      type.isNotEmpty ||
      categoryId != null ||
      categoryName.isNotEmpty ||
      dateFrom != null ||
      dateTo != null ||
      search.isNotEmpty ||
      accountId != null;

  TransactionFilter copyWith({
    String? type,
    int? categoryId,
    String? categoryName,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? search,
    String? sort,
    int? accountId,
    bool clearCategoryId = false,
    bool clearDates = false,
    bool clearAccountId = false,
  }) {
    return TransactionFilter(
      type: type ?? this.type,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      categoryName: categoryName ?? this.categoryName,
      dateFrom: clearDates ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDates ? null : (dateTo ?? this.dateTo),
      search: search ?? this.search,
      sort: sort ?? this.sort,
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
    );
  }

  Map<String, dynamic> toRequest({required int page, int perPage = 20}) {
    return {
      'type': type,
      if (categoryId != null) 'category_id': categoryId,
      'category_name': categoryName,
      if (dateFrom != null) 'date_from': dateFrom!.toUtc().toIso8601String(),
      if (dateTo != null) 'date_to': dateTo!.toUtc().toIso8601String(),
      'search': search,
      'sort': sort,
      if (accountId != null) 'account_id': accountId,
      'page': page,
      'per_page': perPage,
    };
  }
}

final transactionFilterProvider = StateProvider<TransactionFilter>(
  (_) => const TransactionFilter(),
);

// ── transactions list (paged + accumulating) ────────────────────────

class TransactionsListState {
  const TransactionsListState({
    this.page = 1,
    this.loading = false,
    this.error,
    this.data,
  });

  final int page;
  final bool loading;
  final Object? error;
  final PaginatedTransactions? data;

  TransactionsListState copyWith({
    int? page,
    bool? loading,
    Object? error,
    PaginatedTransactions? data,
    bool clearError = false,
  }) {
    return TransactionsListState(
      page: page ?? this.page,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      data: data ?? this.data,
    );
  }
}

class TransactionsListController extends StateNotifier<TransactionsListState> {
  TransactionsListController(this._ref) : super(const TransactionsListState()) {
    _ref.listen<TransactionFilter>(transactionFilterProvider, (_, __) {
      refresh();
    });
    final boot = _ref.read(bootControllerProvider);
    if (boot.stage == BootStage.ready) {
      refresh();
    } else {
      _ref.listen<BootState>(bootControllerProvider, (_, next) {
        if (next.stage == BootStage.ready && state.data == null) {
          refresh();
        }
      });
    }
  }

  final Ref _ref;

  Future<void> refresh() async {
    state = state.copyWith(page: 1, loading: true, clearError: true);
    try {
      final page = await _fetch(1);
      state = state.copyWith(page: 1, loading: false, data: page);
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    final current = state.data;
    if (state.loading || current == null || !current.hasMore) return;
    final next = state.page + 1;
    state = state.copyWith(loading: true);
    try {
      final more = await _fetch(next);
      state = state.copyWith(
        page: next,
        loading: false,
        data: current.append(more),
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<PaginatedTransactions> _fetch(int page) async {
    final api = _ref.read(nativeApiProvider);
    final filter = _ref.read(transactionFilterProvider);
    final raw = await api.listTransactions(filter.toRequest(page: page));
    return PaginatedTransactions.fromJson(raw);
  }
}

final transactionsListProvider =
    StateNotifierProvider<TransactionsListController, TransactionsListState>((
      ref,
    ) {
      return TransactionsListController(ref);
    });

// ── single transaction ──────────────────────────────────────────────

final transactionByIdProvider = FutureProvider.family<Transaction, int>((
  ref,
  id,
) async {
  final api = ref.watch(nativeApiProvider);
  final raw = await api.getTransaction(id);
  return Transaction.fromJson(raw);
});

// ── dashboard ───────────────────────────────────────────────────────

enum DashboardPeriodKind { thisMonth, lastMonth, thisYear }

extension DashboardPeriodKindRange on DashboardPeriodKind {
  ({DateTime from, DateTime to, String label}) range(DateTime now) {
    switch (this) {
      case DashboardPeriodKind.thisMonth:
        final from = DateTime(now.year, now.month, 1);
        final to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return (from: from, to: to, label: _monthLabel(now));
      case DashboardPeriodKind.lastMonth:
        final from = DateTime(now.year, now.month - 1, 1);
        final to = DateTime(now.year, now.month, 0, 23, 59, 59);
        return (from: from, to: to, label: _monthLabel(from));
      case DashboardPeriodKind.thisYear:
        final from = DateTime(now.year, 1, 1);
        final to = DateTime(now.year, 12, 31, 23, 59, 59);
        return (from: from, to: to, label: '${now.year}');
    }
  }
}

String _monthLabel(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[d.month - 1]} ${d.year}';
}

final dashboardPeriodProvider = StateProvider<DashboardPeriodKind>(
  (_) => DashboardPeriodKind.thisMonth,
);

final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  final boot = ref.watch(bootControllerProvider);
  if (boot.stage != BootStage.ready) {
    throw StateError('boot not ready');
  }
  final api = ref.watch(nativeApiProvider);
  final period = ref.watch(dashboardPeriodProvider);
  final range = period.range(DateTime.now());
  final raw = await api.dashboard(from: range.from, to: range.to);
  return DashboardSummary.fromJson(raw);
});
