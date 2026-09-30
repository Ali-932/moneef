import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/common/picker_field.dart';
import '../widgets/common/date_picker_style.dart';
import '../widgets/common/press_feedback.dart';
import '../widgets/common/skeletons.dart';
import '../widgets/common/design.dart';
import '../widgets/common/staggered_animated_item.dart';
import '../widgets/transaction_row.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 300) return;
    final s = ref.read(transactionsListProvider);
    if (s.loading || s.data == null || !s.data!.hasMore) return;
    ref.read(transactionsListProvider.notifier).loadMore();
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref
          .read(transactionFilterProvider.notifier)
          .update((f) => f.copyWith(search: v));
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(transactionsListProvider);
    final filter = ref.watch(transactionFilterProvider);
    final usedCats = ref.watch(usedCategoriesProvider);

    return Scaffold(
      appBar: const PageHeading(
        title: 'Activity',
        subtitle: 'Every transaction, in one place',
      ),
      body: Column(
        children: [
          _SearchAndFilters(
            controller: _searchController,
            filter: filter,
            onSearchChanged: _onSearchChanged,
            onFilterTap: () => _openFilterSheet(context, filter),
            onDateTap: () => _openDateRangeSheet(context, filter),
          ),
          _ActiveFilterChips(filter: filter),
          _CategoryChips(
            categories: usedCats.maybeWhen(
              data: (d) => d,
              orElse: () => const <Category>[],
            ),
            activeCategoryName: filter.categoryName,
            onSelect: (name) => ref
                .read(transactionFilterProvider.notifier)
                .update((f) => f.copyWith(categoryName: name)),
          ),
          Expanded(
            child: _TransactionsList(
              controller: _scrollController,
              state: list,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet(
    BuildContext context,
    TransactionFilter filter,
  ) async {
    final palette = context.palette;
    final result = await showModalBottomSheet<TransactionFilter>(
      context: context,
      backgroundColor: palette.surface,
      // Without isScrollControlled the sheet is capped at 50% of screen
      // height and Type+Category+Sort+buttons get clipped.
      isScrollControlled: true,
      useSafeArea: true,
      // Root navigator so the sheet paints above the shell's docked FAB.
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FilterSheet(initial: filter),
    );
    if (result != null) {
      ref.read(transactionFilterProvider.notifier).state = result;
    }
  }

  Future<void> _openDateRangeSheet(
    BuildContext context,
    TransactionFilter filter,
  ) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      builder: buildAppDatePicker,
      helpText: 'Activity dates',
      saveText: 'Use range',
      confirmText: 'Use range',
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: filter.dateFrom != null && filter.dateTo != null
          ? DateTimeRange(start: filter.dateFrom!, end: filter.dateTo!)
          : null,
    );
    if (range != null) {
      ref
          .read(transactionFilterProvider.notifier)
          .update((f) => f.copyWith(dateFrom: range.start, dateTo: range.end));
    }
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.filter,
    required this.onSearchChanged,
    required this.onFilterTap,
    required this.onDateTap,
  });

  final TextEditingController controller;
  final TransactionFilter filter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;
  final VoidCallback onDateTap;

  bool get _dateActive => filter.dateFrom != null || filter.dateTo != null;
  bool get _filterActive =>
      filter.type.isNotEmpty ||
      filter.categoryId != null ||
      filter.sort != '-date';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search transactions',
                prefixIcon: Icon(Icons.search, color: palette.muted),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _IconButton(
            icon: Icons.calendar_today_outlined,
            badgeActive: _dateActive,
            onTap: onDateTap,
          ),
          const SizedBox(width: 8),
          _IconButton(
            icon: Icons.tune,
            badgeActive: _filterActive,
            onTap: onFilterTap,
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
    this.badgeActive = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool badgeActive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PressFeedback(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.tile,
              borderRadius: AppRadii.medium,
            ),
            child: Icon(icon, color: palette.ink, size: 20),
          ),
          if (badgeActive)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: palette.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Dismissible chip strip shown when any non-default filter is active.
class _ActiveFilterChips extends ConsumerWidget {
  const _ActiveFilterChips({required this.filter});
  final TransactionFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chips = <_FilterChipData>[];

    if (filter.accountId != null) {
      final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
      final name = accounts
          .where((a) => a.id == filter.accountId)
          .firstOrNull
          ?.name;
      chips.add(
        _FilterChipData(
          label: name == null ? 'One account' : 'Account: $name',
          onRemove: () => ref
              .read(transactionFilterProvider.notifier)
              .update((f) => f.copyWith(clearAccountId: true)),
        ),
      );
    }

    if (filter.type.isNotEmpty) {
      final label = filter.type == 'expense' ? 'Expenses' : 'Income';
      chips.add(
        _FilterChipData(
          label: label,
          onRemove: () => ref
              .read(transactionFilterProvider.notifier)
              .update((f) => f.copyWith(type: '')),
        ),
      );
    }

    if (filter.sort != '-date') {
      final label = switch (filter.sort) {
        'date' => 'Oldest first',
        '-amount' => 'Largest amount',
        'amount' => 'Smallest amount',
        _ => filter.sort,
      };
      chips.add(
        _FilterChipData(
          label: label,
          onRemove: () => ref
              .read(transactionFilterProvider.notifier)
              .update((f) => f.copyWith(sort: '-date')),
        ),
      );
    }

    if (filter.dateFrom != null || filter.dateTo != null) {
      final from = filter.dateFrom;
      final to = filter.dateTo;
      String label;
      if (from != null && to != null) {
        label = '${formatDateLong(from)} – ${formatDateLong(to)}';
      } else if (from != null) {
        label = 'From ${formatDateLong(from)}';
      } else {
        label = 'Until ${formatDateLong(to!)}';
      }
      chips.add(
        _FilterChipData(
          label: label,
          onRemove: () => ref
              .read(transactionFilterProvider.notifier)
              .update((f) => f.copyWith(clearDates: true)),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: chips.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final palette = context.palette;
            final c = chips[i];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: c.onRemove,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  borderRadius: AppRadii.pill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.label,
                      style: TextStyle(
                        color: palette.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.close, size: 12, color: palette.ink),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FilterChipData {
  const _FilterChipData({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.activeCategoryName,
    required this.onSelect,
  });

  final List<Category> categories;
  final String activeCategoryName;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      // Trailing fade signals more chips are scrollable off-screen, matching
      // Insights' _DateRangeBar.
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [Colors.transparent, Colors.black],
          stops: [0.0, 0.08],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _Chip(
              label: 'Recent',
              selected: activeCategoryName.isEmpty,
              onTap: () => onSelect(''),
            ),
            for (final c in categories) ...[
              const SizedBox(width: 8),
              _Chip(
                label: c.name,
                selected: c.name == activeCategoryName,
                onTap: () => onSelect(c.name),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bg = selected ? palette.primarySoft : palette.tile;
    final fg = selected ? palette.ink : palette.muted;
    final duration = MediaQuery.of(context).disableAnimations
        ? AppMotion.reducedFallback
        : AppMotion.chip;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!selected) {
          HapticFeedback.selectionClick();
          onTap();
        }
      },
      child: AnimatedContainer(
        duration: duration,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: AppRadii.pill),
        child: AnimatedDefaultTextStyle(
          duration: duration,
          style: DefaultTextStyle.of(context).style.copyWith(
            color: fg,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _TransactionsList extends ConsumerWidget {
  const _TransactionsList({required this.controller, required this.state});

  final ScrollController controller;
  final TransactionsListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.error != null && state.data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            userMessage(state.error!),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.negativeText),
          ),
        ),
      );
    }
    if (state.data == null) {
      return ListView(
        padding: const EdgeInsets.only(top: 4),
        physics: const NeverScrollableScrollPhysics(),
        children: const [TransactionListSkeleton(itemCount: 8, carded: false)],
      );
    }
    final txns = state.data!.results;
    if (txns.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(transactionsListProvider.notifier).refresh(),
        child: const _EmptyState(),
      );
    }
    final groups = _groupByDay(txns);
    return RefreshIndicator(
      onRefresh: () => ref.read(transactionsListProvider.notifier).refresh(),
      child: ListView.builder(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: groups.length + 1,
        itemBuilder: (context, i) {
          if (i == groups.length) {
            if (state.loading) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!state.data!.hasMore) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Center(
                  child: Text(
                    "You're all caught up.",
                    style: TextStyle(color: context.palette.subtle),
                  ),
                ),
              );
            }
            return const SizedBox(height: 32);
          }
          final g = groups[i];
          return StaggeredAnimatedItem(
            key: ValueKey(g.label),
            index: i,
            shouldStagger: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TransactionGroupHeader(
                  label: g.label,
                  dailyTotal: g.dailyTotal,
                  currencyCode: g.currency,
                ),
                for (final t in g.items)
                  TransactionRow(
                    transaction: t,
                    onTap: () => context.push('/transactions/${t.id}'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(Icons.receipt_long_outlined, size: 48, color: palette.subtle),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'No transactions yet.\nTap the + button to add one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted),
          ),
        ),
      ],
    );
  }
}

class _DayGroup {
  _DayGroup(this.label, this.currency);
  final String label;
  final String currency;
  final List<Transaction> items = [];
  Decimal dailyTotal = Decimal.zero;
}

List<_DayGroup> _groupByDay(List<Transaction> txns) {
  final groups = <String, _DayGroup>{};
  final now = DateTime.now();
  for (final t in txns) {
    final label = formatGroupLabel(t.date, now: now);
    final g = groups.putIfAbsent(label, () => _DayGroup(label, t.currencyCode));
    g.items.add(t);
    final amt = t.totalAmount;
    g.dailyTotal += t.type == 'income' ? amt : -amt;
  }
  return groups.values.toList(growable: false);
}

// ── filter sheet ────────────────────────────────────────────────────

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});
  final TransactionFilter initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late TransactionFilter _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cats = ref
        .watch(categoriesProvider)
        .maybeWhen(data: (d) => d, orElse: () => const <Category>[]);
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    final labelStyle = TextStyle(
      color: palette.muted,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle — outside the scroll view so it stays pinned.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.divider,
                borderRadius: AppRadii.small,
              ),
            ),
          ),
          // Scrollable filter body — protects against small screens and
          // larger category lists overflowing the sheet.
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Type', style: labelStyle),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _seg(
                        context,
                        'All',
                        _draft.type == '',
                        () =>
                            setState(() => _draft = _draft.copyWith(type: '')),
                      ),
                      const SizedBox(width: 8),
                      _seg(
                        context,
                        'Expense',
                        _draft.type == 'expense',
                        () => setState(
                          () => _draft = _draft.copyWith(type: 'expense'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _seg(
                        context,
                        'Income',
                        _draft.type == 'income',
                        () => setState(
                          () => _draft = _draft.copyWith(type: 'income'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Category', style: labelStyle),
                  const SizedBox(height: 8),
                  PickerFormField<int>(
                    title: 'Category',
                    value: _draft.categoryId,
                    placeholder: 'All categories',
                    nullOptionLabel: 'All categories',
                    items: [for (final c in cats) c.id],
                    labelBuilder: (id) {
                      for (final c in cats) {
                        if (c.id == id) return c.name;
                      }
                      return '';
                    },
                    onChanged: (v) => setState(
                      () => _draft = v == null
                          ? _draft.copyWith(clearCategoryId: true)
                          : _draft.copyWith(categoryId: v),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Sort', style: labelStyle),
                  const SizedBox(height: 8),
                  PickerFormField<String>(
                    title: 'Sort',
                    value: _draft.sort,
                    placeholder: 'Sort',
                    items: const ['-date', 'date', '-amount', 'amount'],
                    labelBuilder: (v) => switch (v) {
                      '-date' => 'Newest first',
                      'date' => 'Oldest first',
                      '-amount' => 'Largest amount',
                      'amount' => 'Smallest amount',
                      _ => v,
                    },
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(sort: v ?? '-date'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Action row pinned to the bottom of the sheet so users can
          // always reach Apply / Reset regardless of scroll position.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const TransactionFilter()),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadii.medium,
                      ),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_draft),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.accentFill,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadii.medium,
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, String label, bool on, VoidCallback onTap) {
    final palette = context.palette;
    final duration = MediaQuery.of(context).disableAnimations
        ? AppMotion.reducedFallback
        : AppMotion.chip;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.emphasized,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? palette.primary : palette.tile,
            borderRadius: AppRadii.medium,
          ),
          child: AnimatedDefaultTextStyle(
            duration: duration,
            style: DefaultTextStyle.of(context).style.copyWith(
              color: on ? palette.card : palette.ink,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
