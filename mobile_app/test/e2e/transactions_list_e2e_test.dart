// T4 Transactions list (/transactions) — real-core e2e coverage.
//
// Flow tree covered (see task for the assignment; ids below match the
// `testWidgets` names so a failing test maps straight back to a leaf):
//
// T4.1   Ordering (newest first, ties) + pagination
// T4.2.1 Filters · type
// T4.2.2 Filters · category (sheet picker, category_id)
// T4.2.3 Filters · date range
// T4.2.4 Filters · search text
// T4.2.5 Filters · combined (AND semantics + chip/sheet category conflict)
// T4.2.6 Filters · clear
// T4.2.7 Filters · sort (bonus leaf — same sheet, found while reading code)
// T4.3.1 Empty state · no data at all
// T4.3.2 Empty state · no filter match
// T4.4.1 List refreshes after create (via /add UI)
// T4.4.2 List refreshes after edit done elsewhere
// T4.4.3 List refreshes after delete done elsewhere
//
// Every leaf drives the real UI (tap/enterText/pickers) against the real Go
// core over FFI, then verifies independently against bridge.json(...) and/or
// bookkeeping of exactly what was seeded, plus what's actually rendered.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/transactions_screen.dart';
import 'package:mobile_app/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/harness.dart';
import 'real_bridge.dart';

Finder field(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

Finder labeledField(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

// The only ListView with an explicit controller is the main paged list
// (category chips / active-filter chips are plain, controller-less
// ListViews) — this is what makes it possible to scroll *just* the list.
Finder mainList() =>
    find.byWidgetPredicate((w) => w is ListView && w.controller != null);

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TransactionsScreen)));

TransactionsListState listState(WidgetTester tester) =>
    containerOf(tester).read(transactionsListProvider);

DateTime dayAgo(int n, {int hour = 12}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour).subtract(Duration(days: n));
}

Map<String, dynamic> firstCategory(RealBridge bridge, String type) {
  final all = (bridge.json('listCategories', body: {}) as List)
      .cast<Map<String, dynamic>>();
  return all.firstWhere((c) => c['type'] == type);
}

// The filter sheet's category picker (unlike /add's) lists ALL categories
// regardless of type, and default seed data has same-named categories under
// both types (e.g. "Business", "Gifts" each exist as both expense and
// income) — so tests that need to tap a specific, unambiguous category by
// name create their own uniquely-named one instead of reusing seed data.
int _uniqueCatSeq = 0;
Map<String, dynamic> uniqueCategory(RealBridge bridge, String type) {
  final name = 'ZTest${type}Cat${_uniqueCatSeq++}';
  return bridge.json('createCategory', body: {'name': name, 'type': type})
      as Map<String, dynamic>;
}

void seedTxn(
  RealBridge bridge, {
  required String name,
  required String type,
  required int categoryId,
  required DateTime date,
  String merchant = '',
  String amount = '10.00',
}) {
  bridge.json(
    'createTransaction',
    body: {
      'transaction_name': name,
      'currency_code': 'USD',
      'transaction_type': type,
      'date': date.toUtc().toIso8601String(),
      if (merchant.isNotEmpty) 'merchant_name': merchant,
      'transaction_categories': [
        {'category_id': categoryId, 'amount': amount},
      ],
    },
  );
}

List<String> namesOf(List<dynamic> raw) =>
    raw.cast<Map<String, dynamic>>().map((t) => t['name'] as String).toList();

Future<void> openFilterSheet(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.tune));
  await settle(tester);
}

Future<void> applyFilterSheet(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
  await settle(tester);
}

// The category picker sheet lists every category (20+ by default) in a
// fixed-height scrollable; a category near the end alphabetically may be
// built but scrolled out of the hit-testable viewport. Searching narrows the
// list to a single, always-on-screen match instead of scrolling blind.
Future<void> pickCategoryInSheet(WidgetTester tester, String name) async {
  await tester.enterText(field('Search...'), name);
  await settle(tester);
  await tester.tap(find.text(name).last);
  await settle(tester);
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

  // ── T4.1 — ordering + pagination ────────────────────────────────────
  testWidgets('T4.1 ordering (newest first, ties) + pagination', (tester) async {
    final expenseCat = firstCategory(bridge, 'expense');
    final expectedNames = <String>{};

    // 57 uniquely-dated transactions (ranks 1..19 and 21..58 by "days ago" —
    // 20 is reserved for the tie cluster) + 3 sharing the exact same instant
    // at daysAgo(20), which straddles the page-1/page-2 boundary (rank
    // 20/21/22 of 60, with per_page hardcoded to 20 by the UI).
    for (final n in [for (var i = 1; i <= 19; i++) i, for (var i = 21; i <= 58; i++) i]) {
      final name = 'Ordered $n';
      seedTxn(bridge, name: name, type: 'expense', categoryId: expenseCat['id'] as int, date: dayAgo(n));
      expectedNames.add(name);
    }
    for (var k = 0; k < 3; k++) {
      final name = 'Tie $k';
      seedTxn(bridge, name: name, type: 'expense', categoryId: expenseCat['id'] as int, date: dayAgo(20));
      expectedNames.add(name);
    }
    expect(expectedNames.length, 60);

    setGoldenSurface(tester);
    await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/transactions'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    // Page 1: exactly 20 rows, hasMore true.
    var state = listState(tester);
    expect(state.data, isNotNull);
    expect(state.data!.results, hasLength(20));
    expect(state.data!.hasMore, isTrue);

    // Scroll until the backend says there's nothing left, then a couple more
    // drags so the (lazily-built) footer itself scrolls into view.
    for (var i = 0; i < 30 && listState(tester).data!.hasMore; i++) {
      await tester.drag(mainList(), const Offset(0, -700));
      await settle(tester);
    }
    state = listState(tester);
    expect(state.data!.hasMore, isFalse, reason: 'did not reach the end of the list after scrolling');
    for (var i = 0; i < 5; i++) {
      await tester.drag(mainList(), const Offset(0, -700));
      await settle(tester);
    }
    expect(find.textContaining("You're all caught up"), findsOneWidget);

    final gotNames = state.data!.results.map((t) => t.name).toList();
    // No dupes / no gaps / everything reachable.
    expect(gotNames.toSet(), expectedNames, reason: 'paginated set must exactly equal what was seeded (no dupes, no gaps)');
    expect(gotNames, hasLength(60));

    // Strict "newest first" order for the unambiguous (non-tied) items.
    // (Tie sub-order is intentionally not asserted — the backend has no
    // documented/explicit tiebreaker for equal dates; see bug report.)
    final nonTieDates = state.data!.results
        .where((t) => !t.name.startsWith('Tie'))
        .map((t) => t.date)
        .toList();
    for (var i = 0; i + 1 < nonTieDates.length; i++) {
      expect(
        nonTieDates[i].isAfter(nonTieDates[i + 1]) || nonTieDates[i].isAtSameMomentAs(nonTieDates[i + 1]),
        isTrue,
        reason: 'row $i (${nonTieDates[i]}) must not be older than row ${i + 1} (${nonTieDates[i + 1]})',
      );
    }
  });

  // ── T4.2.1 — filter: type ───────────────────────────────────────────
  testWidgets('T4.2.1 filter by type', (tester) async {
    final expCat = firstCategory(bridge, 'expense');
    final incCat = firstCategory(bridge, 'income');
    for (var i = 0; i < 5; i++) {
      seedTxn(bridge, name: 'Exp$i', type: 'expense', categoryId: expCat['id'] as int, date: dayAgo(i + 1));
    }
    for (var i = 0; i < 4; i++) {
      seedTxn(bridge, name: 'Inc$i', type: 'income', categoryId: incCat['id'] as int, date: dayAgo(i + 1));
    }

    setGoldenSurface(tester);
    await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/transactions'));
    await settle(tester);
    expect(listState(tester).data!.results, hasLength(9));

    await openFilterSheet(tester);
    await tester.tap(find.text('Expense'));
    await applyFilterSheet(tester);

    var shown = listState(tester).data!.results.map((t) => t.name).toSet();
    expect(shown, {'Exp0', 'Exp1', 'Exp2', 'Exp3', 'Exp4'});
    final dbExpense = namesOf((bridge.json('listTransactions', body: {'type': 'expense'}) as Map)['results'] as List);
    expect(shown, dbExpense.toSet(), reason: 'UI must match bridge.json(listTransactions, type=expense)');
    expect(find.text('Inc0'), findsNothing);

    await openFilterSheet(tester);
    await tester.tap(find.text('Income'));
    await applyFilterSheet(tester);

    shown = listState(tester).data!.results.map((t) => t.name).toSet();
    expect(shown, {'Inc0', 'Inc1', 'Inc2', 'Inc3'});
    expect(find.text('Exp0'), findsNothing);
  });

  // ── T4.2.2 — filter: category ───────────────────────────────────────
  testWidgets('T4.2.2 filter by category (sheet picker)', (tester) async {
    final catA = uniqueCategory(bridge, 'expense');
    final catB = uniqueCategory(bridge, 'expense');
    seedTxn(bridge, name: 'AlphaOnly', type: 'expense', categoryId: catA['id'] as int, date: dayAgo(1));
    seedTxn(bridge, name: 'BetaOnly', type: 'expense', categoryId: catB['id'] as int, date: dayAgo(2));

    setGoldenSurface(tester);
    await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/transactions'));
    await settle(tester);

    await openFilterSheet(tester);
    await tester.tap(find.text('All categories'));
    await settle(tester);
    await pickCategoryInSheet(tester, catA['name'] as String);
    await applyFilterSheet(tester);

    final shown = listState(tester).data!.results.map((t) => t.name).toSet();
    expect(shown, {'AlphaOnly'});
    final dbMatch = namesOf(
      (bridge.json('listTransactions', body: {'category_id': catA['id']}) as Map)['results'] as List,
    );
    expect(shown, dbMatch.toSet());
    expect(find.text('BetaOnly'), findsNothing);
    expect(find.text('AlphaOnly'), findsOneWidget);
  });

  // ── T4.2.3 — filter: date range ─────────────────────────────────────
  testWidgets('T4.2.3 filter by date range (inclusive of the whole end day)', (tester) async {
    final cat = firstCategory(bridge, 'expense');
    final now = DateTime.now();
    // A fixed window entirely in the past so it never collides with "today".
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 40));
    final end = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 20));

    seedTxn(bridge, name: 'BeforeRange', type: 'expense', categoryId: cat['id'] as int,
        date: start.subtract(const Duration(days: 1, hours: 12)));
    seedTxn(bridge, name: 'MidRange', type: 'expense', categoryId: cat['id'] as int,
        date: start.add(const Duration(days: 5, hours: 9)));
    // On the LAST day of the range, but not at local midnight — this is the
    // case that exposes the end-of-day bug.
    seedTxn(bridge, name: 'LastDayEvening', type: 'expense', categoryId: cat['id'] as int,
        date: end.add(const Duration(hours: 18)));

    setGoldenSurface(tester);
    await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/transactions'));
    await settle(tester);

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await settle(tester);
    String two(int v) => v.toString().padLeft(2, '0');
    String fmt(DateTime d) => '${two(d.month)}/${two(d.day)}/${d.year}';
    await tester.enterText(labeledField('Start Date'), fmt(start));
    await tester.enterText(labeledField('End Date'), fmt(end));
    await settle(tester);
    await tester.tap(find.text('Use range'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    final shown = listState(tester).data!.results.map((t) => t.name).toSet();
    expect(
      shown,
      {'MidRange', 'LastDayEvening'},
      reason: 'A date-range filter must include the entire end day, not just up to local midnight '
          '(mobile_app/lib/screens/transactions_screen.dart _openDateRangeSheet sends range.end '
          'verbatim as date_to with no time component, so transactions.date <= date_to in '
          'internal/transactions/repository/transaction_repository.go excludes anything on the end '
          'day after midnight).',
    );
  });

  // ── T4.2.4 — filter: search text ────────────────────────────────────
  testWidgets('T4.2.4 filter by search text (name or merchant)', (tester) async {
    final cat = firstCategory(bridge, 'expense');
    seedTxn(bridge, name: 'Morning latte', type: 'expense', categoryId: cat['id'] as int, date: dayAgo(1), merchant: 'Blue Bottle');
    seedTxn(bridge, name: 'Grocery run', type: 'expense', categoryId: cat['id'] as int, date: dayAgo(2), merchant: 'Latte House');
    seedTxn(bridge, name: 'Taxi ride', type: 'expense', categoryId: cat['id'] as int, date: dayAgo(3), merchant: 'City Cabs');

    setGoldenSurface(tester);
    await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/transactions'));
    await settle(tester);

    await tester.enterText(field('Search transactions'), 'latte');
    await settle(tester); // 40 * 50ms = 2000ms, comfortably past the 300ms debounce.

    final shown = listState(tester).data!.results.map((t) => t.name).toSet();
    // Matches both the transaction named "Morning latte" AND the one whose
    // merchant contains "Latte" (search is name OR merchant_name, LIKE).
    expect(shown, {'Morning latte', 'Grocery run'});
    final dbMatch = namesOf(
      (bridge.json('listTransactions', body: {'search': 'latte'}) as Map)['results'] as List,
    );
    expect(shown, dbMatch.toSet());
    expect(find.text('Taxi ride'), findsNothing);
  });

  // ── T4.2.5 — filter: combined ───────────────────────────────────────
  testWidgets('T4.2.5 combined filters (AND semantics + chip/sheet category conflict)', (tester) async {
    final catA = uniqueCategory(bridge, 'expense');
    final catB = uniqueCategory(bridge, 'expense');
    seedTxn(bridge, name: 'Alpha1', type: 'expense', categoryId: catA['id'] as int, date: dayAgo(1));
    seedTxn(bridge, name: 'Alpha2', type: 'expense', categoryId: catA['id'] as int, date: dayAgo(2));
    seedTxn(bridge, name: 'Beta1', type: 'expense', categoryId: catB['id'] as int, date: dayAgo(3));

    setGoldenSurface(tester);
    await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/transactions'));
    await settle(tester);

    // Positive case: type + category + search all narrowing consistently.
    await tester.enterText(field('Search transactions'), 'Alpha');
    await settle(tester);
    await openFilterSheet(tester);
    await tester.tap(find.text('Expense'));
    await tester.tap(find.text('All categories'));
    await settle(tester);
    await pickCategoryInSheet(tester, catA['name'] as String);
    await applyFilterSheet(tester);

    var shown = listState(tester).data!.results.map((t) => t.name).toSet();
    expect(shown, {'Alpha1', 'Alpha2'}, reason: 'type+category+search should AND together correctly');
    final dbMatch = namesOf(
      (bridge.json('listTransactions', body: {'type': 'expense', 'category_id': catA['id'], 'search': 'Alpha'}) as Map)['results']
          as List,
    );
    expect(shown, dbMatch.toSet());

    // Now clear the search so the category chip row is visible/relevant, and
    // tap a *different* category's chip. Product intent: the chip is a
    // quick-switch shortcut and should replace the active category, not AND
    // with whatever was set via the sheet.
    await tester.enterText(field('Search transactions'), '');
    await settle(tester);
    await tester.tap(find.text(catB['name'] as String));
    await settle(tester);

    shown = listState(tester).data!.results.map((t) => t.name).toSet();
    expect(
      shown,
      {'Beta1'},
      reason: 'Tapping a category chip must switch the active category filter, not AND with a stale '
          'category_id from the filter sheet. TransactionFilter.copyWith(categoryName: name) in '
          'mobile_app/lib/state/providers.dart leaves the old categoryId untouched, so toRequest() '
          'sends BOTH category_id and category_name — ListTransactionsQuery in '
          'internal/transactions/repository/transaction_repository.go joins on both independently, '
          'requiring a transaction to match both, which none do.',
    );
  });

  // ── T4.2.6 — filter: clear ──────────────────────────────────────────
  testWidgets('T4.2.6 clear filters', (tester) async {
    final expCat = firstCategory(bridge, 'expense');
    final incCat = firstCategory(bridge, 'income');
    seedTxn(bridge, name: 'Foo1', type: 'expense', categoryId: expCat['id'] as int, date: dayAgo(1));
    seedTxn(bridge, name: 'Foo2', type: 'expense', categoryId: expCat['id'] as int, date: dayAgo(2));
    seedTxn(bridge, name: 'Bar1', type: 'income', categoryId: incCat['id'] as int, date: dayAgo(3));

    setGoldenSurface(tester);
    await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/transactions'));
    await settle(tester);

    // Positive check: removing one chip clears only that filter dimension.
    await openFilterSheet(tester);
    await tester.tap(find.text('Income'));
    await applyFilterSheet(tester);
    expect(listState(tester).data!.results.map((t) => t.name).toSet(), {'Bar1'});
    expect(find.text('Income'), findsOneWidget); // the active-filter chip
    await tester.tap(find.text('Income')); // tap the chip itself to remove it
    await settle(tester);
    expect(
      listState(tester).data!.results.map((t) => t.name).toSet(),
      {'Foo1', 'Foo2', 'Bar1'},
      reason: 'removing the type chip should clear only the type filter',
    );

    // Search + Reset: Reset must clear the applied filter server-side...
    await tester.enterText(field('Search transactions'), 'Foo');
    await settle(tester);
    expect(listState(tester).data!.results.map((t) => t.name).toSet(), {'Foo1', 'Foo2'});
    await openFilterSheet(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
    await settle(tester);

    expect(
      listState(tester).data!.results.map((t) => t.name).toSet(),
      {'Foo1', 'Foo2', 'Bar1'},
      reason: 'Reset must clear the applied search filter',
    );
    // ...but the search TextField is a separate, un-synced controller, so it
    // still shows the stale query even though the applied filter is gone.
    final searchBox = tester.widget<TextField>(field('Search transactions'));
    expect(
      searchBox.controller!.text,
      isEmpty,
      reason: 'After Reset in the filter sheet, the search box still visually shows "Foo" even '
          'though the underlying filter.search was cleared to "" — the _SearchAndFilters '
          'TextEditingController in mobile_app/lib/screens/transactions_screen.dart is never '
          'synced back when the filter is reset from elsewhere, which is misleading: the list is '
          'unfiltered but the search box implies a search is still active.',
    );
  });

  // ── T4.2.7 — filter: sort (bonus; same sheet, found reading the code) ─
  testWidgets('T4.2.7 sort order (bonus leaf)', (tester) async {
    final cat = firstCategory(bridge, 'expense');
    seedTxn(bridge, name: 'Cheap', type: 'expense', categoryId: cat['id'] as int, date: dayAgo(3), amount: '1.00');
    seedTxn(bridge, name: 'Mid', type: 'expense', categoryId: cat['id'] as int, date: dayAgo(2), amount: '5.00');
    seedTxn(bridge, name: 'Pricey', type: 'expense', categoryId: cat['id'] as int, date: dayAgo(1), amount: '9.00');

    setGoldenSurface(tester);
    await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/transactions'));
    await settle(tester);
    // Default is "Newest first": Pricey, Mid, Cheap.
    expect(listState(tester).data!.results.map((t) => t.name).toList(), ['Pricey', 'Mid', 'Cheap']);

    await openFilterSheet(tester);
    await tester.tap(find.text('Newest first'));
    await settle(tester);
    await tester.tap(find.text('Oldest first'));
    await settle(tester);
    await applyFilterSheet(tester);

    expect(
      listState(tester).data!.results.map((t) => t.name).toList(),
      ['Cheap', 'Mid', 'Pricey'],
      reason: '"Oldest first" sends sort="date" (mobile_app/lib/state/providers.dart toRequest), but '
          'ListTransactionsQuery in internal/transactions/repository/transaction_repository.go only '
          'recognizes "date_asc"/"amount_asc"/"amount_desc" — every other value (including the app\'s '
          'own "-date"/"date"/"-amount"/"amount") silently falls through to the default "date desc", '
          'so every non-default sort option in the app is a no-op.',
    );
  });

  // ── T4.3.1 — empty state: no data ───────────────────────────────────
  testWidgets('T4.3.1 empty state — no data at all', (tester) async {
    setGoldenSurface(tester);
    await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/transactions'));
    await settle(tester);
    expect(listState(tester).data!.results, isEmpty);
    expect(find.textContaining('No transactions yet'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
  });

  // ── T4.3.2 — empty state: no filter match ───────────────────────────
  testWidgets('T4.3.2 empty state — filters exclude everything', (tester) async {
    final cat = firstCategory(bridge, 'expense');
    seedTxn(bridge, name: 'Something', type: 'expense', categoryId: cat['id'] as int, date: dayAgo(1));

    setGoldenSurface(tester);
    await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/transactions'));
    await settle(tester);

    await tester.enterText(field('Search transactions'), 'zzz-no-such-transaction');
    await settle(tester);
    expect(listState(tester).data!.results, isEmpty);
    expect(find.text('No transactions match these filters.'), findsOneWidget);

    expect(
      find.textContaining('Tap the + button to add one'),
      findsNothing,
      reason: 'The user has 1 transaction; it is only hidden by an active search filter. '
          '_EmptyState in mobile_app/lib/screens/transactions_screen.dart renders the exact same '
          '"No transactions yet. Tap the + button to add one." copy regardless of whether there is '
          'genuinely no data or the current filters just match nothing — telling someone with data '
          'to "add one" is misleading and does not suggest clearing filters.',
    );
  });

  // ── T4.4.1 — refresh after create via /add UI ───────────────────────
  testWidgets('T4.4.1 list refreshes after create via /add, no manual refresh', (tester) async {
    final cat = firstCategory(bridge, 'expense');
    seedTxn(bridge, name: 'Old1', type: 'expense', categoryId: cat['id'] as int, date: dayAgo(5));
    seedTxn(bridge, name: 'Old2', type: 'expense', categoryId: cat['id'] as int, date: dayAgo(6));

    setGoldenSurface(tester);
    await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/transactions'));
    await settle(tester);
    expect(listState(tester).data!.results, hasLength(2));

    await tester.tap(find.byTooltip('Add transaction'));
    await settle(tester);
    await tester.enterText(field('e.g. Morning latte'), 'Brand new expense');
    await tester.enterText(field('0.00').first, '42.00');
    await tester.tap(find.text('Select category'));
    await settle(tester);
    await tester.tap(find.text(cat['name'] as String).last);
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add transaction'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    // Back on /transactions, without any pull-to-refresh.
    expect(find.byType(TransactionsScreen), findsOneWidget, reason: 'should have popped back to the list');
    final results = listState(tester).data!.results;
    expect(results.map((t) => t.name), contains('Brand new expense'));
    expect(results.first.name, 'Brand new expense', reason: 'the new transaction (dated now) must sort to the top');
    expect(find.text('Brand new expense'), findsOneWidget);
  });

  // ── T4.4.2 — refresh after edit elsewhere ───────────────────────────
  testWidgets('T4.4.2 list refreshes after edit done from the detail screen', (tester) async {
    final cat = firstCategory(bridge, 'expense');
    seedTxn(bridge, name: 'Old Name', type: 'expense', categoryId: cat['id'] as int, date: dayAgo(1));

    setGoldenSurface(tester);
    await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/transactions'));
    await settle(tester);
    expect(find.text('Old Name'), findsOneWidget);

    await tester.tap(find.text('Old Name'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Edit transaction'));
    await settle(tester);
    await tester.enterText(field('e.g. Morning latte'), 'New Name');
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await settle(tester);
    expect(find.byType(TransactionsScreen), findsOneWidget);

    expect(
      listState(tester).data!.results.map((t) => t.name),
      contains('New Name'),
      reason: 'list should reflect the edit without a manual refresh',
    );
    expect(find.text('New Name'), findsOneWidget);
    expect(find.text('Old Name'), findsNothing);
  });

  // ── T4.4.3 — refresh after delete elsewhere ─────────────────────────
  testWidgets('T4.4.3 list refreshes after delete done from the detail screen', (tester) async {
    final cat = firstCategory(bridge, 'expense');
    seedTxn(bridge, name: 'Keep Me', type: 'expense', categoryId: cat['id'] as int, date: dayAgo(1));
    seedTxn(bridge, name: 'Delete Me', type: 'expense', categoryId: cat['id'] as int, date: dayAgo(2));

    setGoldenSurface(tester);
    await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/transactions'));
    await settle(tester);
    expect(listState(tester).data!.results, hasLength(2));

    await tester.tap(find.text('Delete Me'));
    await settle(tester);
    await tester.tap(find.byTooltip('Delete transaction'));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    expect(find.byType(TransactionsScreen), findsOneWidget, reason: 'delete pops straight back to the list');
    final results = listState(tester).data!.results;
    expect(results.map((t) => t.name), isNot(contains('Delete Me')));
    expect(results.map((t) => t.name), contains('Keep Me'));
    expect(find.text('Delete Me'), findsNothing);
    expect(find.text('Keep Me'), findsOneWidget);
  });
}
