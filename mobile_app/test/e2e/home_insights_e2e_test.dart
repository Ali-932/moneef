// E2E coverage for T7 "Home & Insights" against the REAL Go core (see
// mobilebridge/_e2e/main.go + test/e2e/real_bridge.dart — no mocks).
//
// Tree:
//   7.1 Home totals (income/expense/net/recent) match seeded data incl.
//       splits and multi-currency with exchange rates.
//   7.2 Date range changes recompute correctly (month boundaries, a
//       transaction at 23:59 local on the last day, timezone/UTC
//       conversion divergence between Home and Insights).
//   7.3 Insights tabs: overview / analysis (category breakdown sums) /
//       patterns (+ refresh, a seeded clear concentration pattern).
//   7.4 Cross-tab invalidation after create/delete via the real UI.
//
// 7.2's timezone leaf (`7.2c`) reproduces a bug that only shows up when the
// host's local timezone is *ahead* of UTC. This machine's ambient TZ is
// already +3 which is enough, but for a deterministic repro on any host run
// this file with:
//   TZ=Asia/Tokyo flutter test test/e2e/home_insights_e2e_test.dart
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_app/utils/format.dart';
import 'package:mobile_app/widgets/insights/insights_widgets.dart'
    show StatCard, QuickStatsCard, CategoryDonut, PatternList, PatternStatCards;

import '../screenshots/harness.dart';
import 'real_bridge.dart';

// ---------------------------------------------------------------------------
// Helpers (local to this file only — nothing under lib/ or the harness is
// touched).
// ---------------------------------------------------------------------------

Finder field(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

Decimal d(String s) => Decimal.parse(s);

String money(String amount, [String currency = 'USD']) =>
    formatMoney(d(amount), currency);

/// Scrolls [text] into view (Home's page is taller than the golden phone
/// surface, so most of it starts off-screen) and asserts it is present.
/// Works for both plain `Text` and [MoneyText] (which renders a `Text`
/// internally), so callers don't need to care which one a given amount is
/// wrapped in.
Future<void> expectVisibleText(WidgetTester tester, String text) async {
  final finder = find.text(text, skipOffstage: false);
  expect(finder, findsWidgets, reason: 'expected to find "$text" anywhere on screen');
  await tester.ensureVisible(finder.first);
  await settle(tester);
  expect(find.text(text), findsWidgets);
}

int catId(List<dynamic> categories, String name, String type) {
  final match = categories.cast<Map<String, dynamic>>().firstWhere(
    (c) => c['name'] == name && c['type'] == type,
    orElse: () => throw StateError('category $name/$type not found'),
  );
  return (match['id'] as num).toInt();
}

/// Creates a transaction directly through the real Go core (bypassing the
/// UI) — used to seed fixtures precisely, including dates/currencies the UI
/// form cannot express (no time-of-day picker, no arbitrary currency without
/// first adding it).
void seedTx(
  RealBridge bridge, {
  required String name,
  required String type,
  required DateTime date,
  required List<(int, String)> splits,
  String currency = 'USD',
  String merchant = '',
}) {
  bridge.json(
    'createTransaction',
    body: {
      'transaction_name': name,
      'currency_code': currency,
      'transaction_type': type,
      'date': date.toUtc().toIso8601String(),
      if (merchant.isNotEmpty) 'merchant_name': merchant,
      'transaction_categories': [
        for (final s in splits) {'category_id': s.$1, 'amount': s.$2},
      ],
    },
  );
}

/// Mirrors `DashboardPeriodKindRange.range()` in lib/state/providers.dart —
/// Home's "This month" / "Last month" / "This year" boundaries (local time).
({DateTime from, DateTime to}) homeMonthRange(DateTime now, {int offset = 0}) {
  final from = DateTime(now.year, now.month + offset, 1);
  final to = DateTime(now.year, now.month + offset + 1, 0, 23, 59, 59);
  return (from: from, to: to);
}

({DateTime from, DateTime to}) homeYearRange(DateTime now) =>
    (from: DateTime(now.year, 1, 1), to: DateTime(now.year, 12, 31, 23, 59, 59));

/// Mirrors `dateRangeFromPreset(DateRangePreset.thisMonth, now)` in
/// lib/utils/date_range.dart — Insights' "This Month" boundaries (UTC-label
/// of the *local* calendar date, NOT a true local->UTC conversion).
DateTime insightsThisMonthStart(DateTime now) =>
    DateTime.utc(now.year, now.month, 1);

DateTime insightsTodayEnd(DateTime now) {
  final today = DateTime.utc(now.year, now.month, now.day);
  return DateTime.utc(today.year, today.month, today.day, 23, 59, 59, 999);
}

Map<String, dynamic> dashboardOf(RealBridge bridge, {DateTime? from, DateTime? to}) {
  return bridge.json(
    'dashboard',
    body: {
      if (from != null) 'date_from': from.toUtc().toIso8601String(),
      if (to != null) 'date_to': to.toUtc().toIso8601String(),
    },
  ) as Map<String, dynamic>;
}

Map<String, dynamic> analysisOf(
  RealBridge bridge, {
  required DateTime from,
  required DateTime to,
  String currency = 'USD',
}) {
  return bridge.json(
    'analysis',
    body: {
      'start_date': from.toUtc().toIso8601String(),
      'end_date': to.toUtc().toIso8601String(),
      'currency': currency,
    },
  ) as Map<String, dynamic>;
}

void main() {
  final bridge = RealBridge.instance;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bridge.resetWithProfile();
    bridge.install();
  });

  // ── 7.1 ──────────────────────────────────────────────────────────────
  group('7.1 Home totals match seeded data', () {
    testWidgets(
      '7.1 income, expense, net, splits, multi-currency and recent list exactly match the Go core',
      (tester) async {
        final categories = bridge.json('listCategories', body: {}) as List;
        final foodId = catId(categories, 'Food', 'expense');
        final transportId = catId(categories, 'Transport', 'expense');
        final salaryId = catId(categories, 'Salary', 'income');

        // Safely mid-month so both a UTC-anchored and a local-anchored
        // "this month" window agree, regardless of host timezone.
        final now = DateTime.now();
        final mid = DateTime.utc(now.year, now.month, 15, 12);

        // 1 EUR = 1.10 USD.
        bridge.json(
          'upsertExchangeRate',
          body: {'from': 'EUR', 'to': 'USD', 'rate': '1.10'},
        );

        seedTx(
          bridge,
          name: 'Groceries',
          type: 'expense',
          date: mid,
          splits: [(foodId, '40.00')],
          merchant: 'SuperMart',
        );
        seedTx(
          bridge,
          name: 'Weekend Trip',
          type: 'expense',
          date: mid,
          splits: [(foodId, '15.00'), (transportId, '25.00')],
        );
        seedTx(
          bridge,
          name: 'Berlin Shopping',
          type: 'expense',
          date: mid,
          currency: 'EUR',
          splits: [(foodId, '100.00')],
        );
        seedTx(
          bridge,
          name: 'Paycheck',
          type: 'income',
          date: mid,
          splits: [(salaryId, '200.00')],
        );

        // ---- independent ground truth (hand-derived from the seed) ----
        // total_expense = 40 + 15 + 25 + (100 * 1.10) = 190.00
        // total_income  = 200.00
        // balance       = 10.00
        // top category  = Food (40 + 15 + 110 = 165.00) over Transport (25.00)
        // top merchant  = SuperMart (only tx with a merchant) = 40.00
        // biggest split = Berlin Shopping's single 110.00 split
        final expExpense = d('190.00');
        final expIncome = d('200.00');
        final expBalance = d('10.00');
        final expFoodTotal = d('165.00');
        final expShare = ((165 / 190) * 100).toStringAsFixed(0); // "87"

        // ---- verify against the Go core directly (DB truth) ----
        final dash = dashboardOf(bridge);
        expect(d(dash['total_expense'] as String), expExpense);
        expect(d(dash['total_income'] as String), expIncome);
        expect(d(dash['balance'] as String), expBalance);
        final qs = dash['quick_stats'] as Map<String, dynamic>;
        final topCat = qs['top_category'] as Map<String, dynamic>;
        expect(topCat['category_name'], 'Food');
        expect(d(topCat['total_amount'] as String), expFoodTotal);
        expect((qs['top_merchant'] as Map)['name'], 'SuperMart');
        expect(d((qs['top_merchant'] as Map)['amount'] as String), d('40.00'));
        expect(
          d((qs['biggest_transaction'] as Map)['amount'] as String),
          d('110.00'),
        );
        expect((dash['recent_transactions'] as List), hasLength(4));

        // BUG: quick_stats.avg_transaction divides the EXPENSE total by the
        // count of ALL transactions (income included), not just expense
        // ones. internal/dashboard/repository/dashboard_repository.go's
        // GetTransactionCount has no `type = 'expense'` filter (unlike its
        // sibling internal/analysis/repository/analysis_repository.go
        // version, which does filter — see analysisOf assertions in 7.3).
        // count(all tx) = 4, so avg_transaction = 190.00 / 4 = 47.50, not
        // the average expense (190.00 / 3 = 63.33) a user would expect.
        expect(qs['transaction_count'], 4);
        expect(d(qs['avg_transaction'] as String), d('47.50'));

        // ---- verify against the real rendered UI ----
        await tester.pumpWidget(
          appUnderTest(themeMode: ThemeMode.light, path: '/home'),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);

        // Home's page is taller than the golden phone surface — each check
        // scrolls its own target into view like a real user would, so none
        // of these depend on a shared scroll position.
        await expectVisibleText(tester, money('10.00')); // net
        await expectVisibleText(tester, money('190.00')); // expenses flow bar
        await expectVisibleText(tester, money('200.00')); // income flow bar
        await expectVisibleText(tester, money('165.00')); // top category
        await expectVisibleText(tester, '$expShare%');
        for (final name in ['Paycheck', 'Berlin Shopping', 'Weekend Trip', 'Groceries']) {
          await expectVisibleText(tester, name);
        }
        // The numerator/denominator mismatch bug is visible on-screen too
        // (in the "In numbers" quick-stats card).
        await expectVisibleText(tester, money('47.50'));
      },
    );
  });

  // ── 7.2 ──────────────────────────────────────────────────────────────
  group('7.2 Date range changes recompute correctly', () {
    testWidgets('7.2a switching Home\'s period selector recomputes totals per real month boundaries', (
      tester,
    ) async {
      final categories = bridge.json('listCategories', body: {}) as List;
      final foodId = catId(categories, 'Food', 'expense');
      final now = DateTime.now();
      final thisMonthMid = DateTime.utc(now.year, now.month, 15, 12);
      final lastMonthMid = DateTime.utc(now.year, now.month - 1, 15, 12);

      seedTx(
        bridge,
        name: 'Current Month Item',
        type: 'expense',
        date: thisMonthMid,
        splits: [(foodId, '60.00')],
      );
      seedTx(
        bridge,
        name: 'Old Dinner',
        type: 'expense',
        date: lastMonthMid,
        splits: [(foodId, '45.00')],
      );

      await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/home'));
      await settle(tester);

      // Defaults to "This month" — only the current-month item counts.
      await expectVisibleText(tester, money('60.00'));
      // The globally-most-recent item still shows even once we switch the
      // period below — Home's "Recent activity" list is NOT period-scoped
      // (dashboard's GetRecentTransactions ignores date_from/date_to; see
      // internal/dashboard/repository/dashboard_repository.go:30-41).
      await expectVisibleText(tester, 'Current Month Item');

      await tester.tap(find.text('Last month'));
      await settle(tester);
      await expectVisibleText(tester, money('45.00'));
      // Still shows the *current*-month item in "Recent activity" while the
      // header totals are for last month — same non-period-scoped list.
      await expectVisibleText(tester, 'Current Month Item');

      await tester.tap(find.text('This year'));
      await settle(tester);
      final lastMonthAnchor = DateTime(now.year, now.month - 1, 15);
      final sameYear = lastMonthAnchor.year == now.year;
      final expectedYearTotal = sameYear ? d('105.00') : d('60.00');
      await expectVisibleText(tester, money(expectedYearTotal.toString()));

      expect(tester.takeException(), isNull);
    });

    testWidgets('7.2b a transaction at 23:59:59 local on the last day of the month sits on the inclusive boundary', (
      tester,
    ) async {
      // No UI path exists to set a transaction's time-of-day (the date
      // picker in lib/screens/add_transaction_screen.dart's _DateField only
      // picks a calendar date — showDatePicker has no time component), so
      // this edge case can only be exercised directly through the bridge.
      final categories = bridge.json('listCategories', body: {}) as List;
      final foodId = catId(categories, 'Food', 'expense');
      final now = DateTime.now();
      final lastDay = DateTime(now.year, now.month + 1, 0).day;
      final boundary = DateTime(now.year, now.month, lastDay, 23, 59, 59);

      seedTx(
        bridge,
        name: 'Last Minute',
        type: 'expense',
        date: boundary,
        splits: [(foodId, '9.99')],
      );

      final thisMonth = homeMonthRange(now);
      final nextMonth = homeMonthRange(now, offset: 1);

      final inThisMonth = dashboardOf(bridge, from: thisMonth.from, to: thisMonth.to);
      expect(
        d(inThisMonth['total_expense'] as String),
        d('9.99'),
        reason: 'a transaction at exactly 23:59:59 on the last day must be '
            'included in that month (inclusive upper bound)',
      );

      final inNextMonth = dashboardOf(bridge, from: nextMonth.from, to: nextMonth.to);
      expect(
        d(inNextMonth['total_expense'] as String),
        Decimal.zero,
        reason: 'it must not leak forward into the following month',
      );

      await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/home'));
      await settle(tester);
      await expectVisibleText(tester, money('9.99'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('7.2c BUG: Home and Insights disagree on "this month" for a same-day transaction under a positive UTC offset', (
      tester,
    ) async {
      final now = DateTime.now();
      if (!now.timeZoneOffset.isNegative && now.timeZoneOffset == Duration.zero) {
        // No offset: local==UTC, so this specific divergence cannot occur.
        // Run with `TZ=Asia/Tokyo flutter test ...` for a deterministic repro.
        markTestSkipped('host timezone offset is 0; re-run with TZ=Asia/Tokyo');
        return;
      }
      if (now.timeZoneOffset.inMinutes <= 5) {
        markTestSkipped(
          'host timezone offset (${now.timeZoneOffset}) is too small to '
          'safely clear the 00:05 buffer used below; re-run with '
          'TZ=Asia/Tokyo',
        );
        return;
      }

      final categories = bridge.json('listCategories', body: {}) as List;
      final foodId = catId(categories, 'Food', 'expense');

      // A transaction dated *today*, just after local midnight on the 1st
      // of the current month.
      final txLocal = DateTime(now.year, now.month, 1, 0, 5);
      seedTx(
        bridge,
        name: 'Midnight Snack',
        type: 'expense',
        date: txLocal,
        splits: [(foodId, '42.00')],
      );

      // Home ("This month"): real local-midnight -> UTC conversion, so the
      // transaction is correctly on-or-after the start boundary.
      final home = homeMonthRange(now);
      final homeDash = dashboardOf(bridge, from: home.from, to: home.to);
      expect(d(homeDash['total_expense'] as String), d('42.00'));

      // Insights ("This Month"): lib/utils/date_range.dart's
      // dateRangeFromPreset() builds the start boundary from
      // `DateTime.utc(now.year, now.month, 1)` — the *local* Y/M/D
      // components relabeled as UTC, not a real local->UTC conversion like
      // Home uses. Under a positive UTC offset this start boundary is later
      // than it should be, so a transaction from just after local midnight
      // (which converts to *before* UTC midnight) is wrongly excluded.
      final insightsStart = insightsThisMonthStart(now);
      final insightsEnd = insightsTodayEnd(now);
      final insightsAnalysis = analysisOf(bridge, from: insightsStart, to: insightsEnd);
      expect(
        d(insightsAnalysis['total'] as String),
        Decimal.zero,
        reason:
            'lib/utils/date_range.dart:55-60 dateRangeFromPreset(thisMonth) '
            'mislabels a local calendar date as UTC instead of converting '
            'local midnight to UTC (contrast with '
            'DashboardPeriodKindRange.range() in lib/state/providers.dart:'
            '310-327, which converts correctly) — a real transaction from '
            'earlier today is silently dropped from Insights\' "This Month" '
            'while Home\'s "This month" correctly includes it.',
      );

      // ---- the same mismatch is visible in the live rendered UI ----
      await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/home'));
      await settle(tester);
      await expectVisibleText(tester, money('42.00'));

      await tester.tap(find.text('Insights').last);
      await settle(tester);
      final expensesCard = tester.widget<StatCard>(
        find.widgetWithText(StatCard, 'Expenses'),
      );
      expect(
        expensesCard.amount,
        Decimal.zero,
        reason: 'Insights\' Overview shows \$0.00 in Expenses for the same '
            'period/transaction that Home just showed \$42.00 for.',
      );
      expect(tester.takeException(), isNull);
    });
  });

  // ── 7.3 ──────────────────────────────────────────────────────────────
  group('7.3 Insights tabs', () {
    testWidgets(
      '7.3 overview + analysis category breakdown sums to total; patterns detects and refreshes a clear concentration pattern',
      (tester) async {
        final categories = bridge.json('listCategories', body: {}) as List;
        final foodId = catId(categories, 'Food', 'expense');
        final transportId = catId(categories, 'Transport', 'expense');
        final salaryId = catId(categories, 'Salary', 'income');

        // Safely in the past (for the "Last 30 days" pattern-period check
        // below) and — barring a test run in the first half hour of a new
        // month — within "this month"/"month-to-date" too.
        final seedDate = DateTime.now().subtract(const Duration(minutes: 30));

        const foodAmounts = ['20', '25', '18', '22', '19', '24', '21', '23', '20'];
        const transportAmounts = ['10', '12', '11'];
        for (final a in foodAmounts) {
          seedTx(
            bridge,
            name: 'Food $a',
            type: 'expense',
            date: seedDate,
            splits: [(foodId, a)],
          );
        }
        for (final a in transportAmounts) {
          seedTx(
            bridge,
            name: 'Transport $a',
            type: 'expense',
            date: seedDate,
            splits: [(transportId, a)],
          );
        }
        seedTx(
          bridge,
          name: 'Paycheck',
          type: 'income',
          date: seedDate,
          splits: [(salaryId, '500.00')],
        );
        // 12 expense tx total: Food=192.00, Transport=33.00, total=225.00.
        // 12 > CategoryBasedSpendingDetector.MinTransactions() (10), so it
        // fires: top_category, high_concentration (Food >=30%) and
        // very_high_concentration (Food+Transport = 100% >= 80%).

        await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/insights'));
        await settle(tester);
        expect(tester.takeException(), isNull);

        // ---- Overview tab (default) ----
        final incomeCard = tester.widget<StatCard>(
          find.widgetWithText(StatCard, 'Income'),
        );
        expect(incomeCard.amount, d('500.00'));
        var expensesCard = tester.widget<StatCard>(
          find.widgetWithText(StatCard, 'Expenses'),
        );
        expect(expensesCard.amount, d('225.00'));

        var donut = tester.widgetList<CategoryDonut>(find.byType(CategoryDonut)).first;
        expect(donut.total, d('225.00'));
        final donutSum = donut.categories.fold(Decimal.zero, (a, c) => a + c.totalAmount);
        expect(donutSum, donut.total, reason: 'category breakdown must sum to the total');
        final food = donut.categories.firstWhere((c) => c.categoryName == 'Food');
        final transport = donut.categories.firstWhere((c) => c.categoryName == 'Transport');
        expect(food.totalAmount, d('192.00'));
        expect(transport.totalAmount, d('33.00'));

        // ---- Analysis tab (no Income/Expenses StatCards here — those are
        // Overview-only; Analysis leads with QuickStatsCard instead) ----
        await tester.tap(find.text('Analysis'));
        await settle(tester);
        donut = tester.widgetList<CategoryDonut>(find.byType(CategoryDonut)).first;
        expect(donut.total, d('225.00'));
        expect(
          donut.categories.fold(Decimal.zero, (a, c) => a + c.totalAmount),
          donut.total,
        );
        final quickStats = tester.widget<QuickStatsCard>(find.byType(QuickStatsCard));
        // Unlike the dashboard package's bug in 7.1, the analysis package's
        // GetTransactionCount *does* filter type='expense' — count is 12,
        // not 13 (income included).
        expect(quickStats.stats.transactionCount, 12);

        // ---- Patterns tab ----
        await tester.tap(find.text('Patterns'));
        await settle(tester);
        // Visiting the tab already triggers a refresh (patternsProvider
        // always calls refreshPatterns — see insights_providers.dart).
        var patternList = tester.widget<PatternList>(find.byType(PatternList));
        final types = patternList.patterns.map((p) => p.patternType).toSet();
        expect(types, containsAll(<String>{
          'top_category',
          'high_concentration',
          'very_high_concentration',
        }));
        for (final p in patternList.patterns) {
          final meta = p.metadata!;
          expect(meta['category'], 'Food');
        }
        final statCards = tester.widget<PatternStatCards>(find.byType(PatternStatCards));
        expect(statCards.patterns.length, patternList.patterns.length);

        // Manual "Analyze" refresh works and reports success.
        await tester.tap(find.text('Analyze'));
        await settle(tester);
        expect(find.text('Patterns updated'), findsOneWidget);
        patternList = tester.widget<PatternList>(find.byType(PatternList));
        expect(
          patternList.patterns.map((p) => p.patternType).toSet(),
          types,
        );

        // Switching the period chip still finds the same concentration
        // pattern (all seed data is within the last 30 days).
        await tester.tap(find.text('Range: All time'));
        await settle(tester);
        await tester.tap(find.text('Last 30 days'));
        await settle(tester);
        patternList = tester.widget<PatternList>(find.byType(PatternList));
        expect(
          patternList.patterns.map((p) => p.patternType).toSet(),
          types,
          reason: 'all seed data is within the last 30 days, so switching '
              'the period should find the same patterns',
        );

        expect(tester.takeException(), isNull);

        // BUG: API.md documents that RefreshPatterns "writes the detected
        // patterns into the patterns table ... Subsequent Patterns() calls
        // return the freshly-stored set." mobilebridge/patterns.go's
        // RefreshPatterns (lines 37-68) never does this — it only calls
        // pattern_engine.GetUserPatterns and returns the result, unlike its
        // HTTP-handler sibling internal/patterns/pattern_handler.go:91-108
        // (RefreshPatternsHandler), which upserts via
        // repository.UpsertPatterns inside a DB transaction for the
        // all-time case. So the mobile bridge's cheap "instant read" fast
        // path (Patterns()) never reflects a refresh that went through
        // RefreshPatterns() — it stays permanently empty for this profile,
        // even though the UI just displayed 3 patterns computed from it.
        final cached = bridge.json('patterns') as List;
        expect(
          cached.length,
          patternList.patterns.length,
          reason: 'per API.md, Patterns() should return the set that the '
              'Analyze tap above just wrote via RefreshPatterns — instead '
              'it is always empty because mobilebridge/patterns.go:37-68 never '
              'persists.',
        );
      },
    );
  });

  // ── 7.4 ──────────────────────────────────────────────────────────────
  group('7.4 Cross-tab invalidation', () {
    testWidgets('7.4 creating then deleting a transaction via the real UI updates Home and Insights without restart', (
      tester,
    ) async {
      await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/home'));
      await settle(tester);
      await expectVisibleText(tester, money('0.00'));
      await expectVisibleText(tester, 'Start with your first transaction');

      // ---- create via the real UI ----
      await tester.tap(find.byTooltip('Add transaction'));
      await settle(tester);
      await tester.enterText(field('e.g. Morning latte'), 'Grocery Run');
      await tester.enterText(field('0.00').first, '25.50');
      await tester.ensureVisible(find.text('Select category', skipOffstage: false));
      await settle(tester);
      await tester.tap(find.text('Select category'));
      await settle(tester);
      await tester.tap(find.text('Food'));
      await settle(tester);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Add transaction', skipOffstage: false),
      );
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add transaction'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      // Home rebuilds live (no restart) once the create invalidates
      // dashboardProvider — see TransactionsMutationController._invalidateAll
      // in lib/state/transactions_controller.dart.
      await expectVisibleText(tester, money('25.50'));
      await expectVisibleText(tester, 'Grocery Run');
      final afterCreate = dashboardOf(bridge);
      expect(d(afterCreate['total_expense'] as String), d('25.50'));

      // Insights reflects it too, live, without navigating away and back.
      await tester.tap(find.text('Insights').last);
      await settle(tester);
      final expensesCard = tester.widget<StatCard>(
        find.widgetWithText(StatCard, 'Expenses'),
      );
      expect(expensesCard.amount, d('25.50'));

      // ---- delete via the real UI ----
      await tester.tap(find.text('Home'));
      await settle(tester);
      await tester.ensureVisible(find.text('Grocery Run', skipOffstage: false).first);
      await settle(tester);
      await tester.tap(find.text('Grocery Run').first);
      await settle(tester);
      await tester.tap(find.byTooltip('Delete transaction'));
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      // Back on Home (detail screen pops on delete), live-updated again.
      await expectVisibleText(tester, money('0.00'));
      await expectVisibleText(tester, 'Start with your first transaction');
      final afterDelete = dashboardOf(bridge);
      expect(d(afterDelete['total_expense'] as String), Decimal.zero);

      await tester.tap(find.text('Insights').last);
      await settle(tester);
      final expensesAfterDelete = tester.widget<StatCard>(
        find.widgetWithText(StatCard, 'Expenses'),
      );
      expect(expensesAfterDelete.amount, Decimal.zero);
      expect(tester.takeException(), isNull);
    });
  });
}
