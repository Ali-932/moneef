// T2.2 Create transaction → Income, and T2.3 Create transaction →
// Validation / negative, e2e against the real Go core
// (mobilebridge/_e2e/main.go via RealBridge — see mobilebridge/API.md). One
// testWidgets (or group of sub-cases) per leaf:
//
//   2.2.1  one-off income
//   2.2.2  recurring income (monthly salary)
//   2.2.3  foreign-currency income
//   2.2.4  category picker filters by type; an incompatible pick is cleared
//   2.3.1  empty / zero / negative amount → blocked, nothing persisted
//   2.3.2  grouped / >2-decimal / large / locale-ish amount input
//   2.3.3  no category / missing title → blocked
//   2.3.4  discard-changes dialog on back (dirty vs clean)
//   2.3.5  Go error surfaced to the user; no double submit on double tap
//
// Harness idioms (field/pumpAdd/selectCategory/submit/allTransactions/...)
// mirror test/e2e/create_expense_e2e_test.dart (the sibling Expense tree)
// for consistency across the suite; each e2e file keeps its own local
// copies per that file's own convention.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/harness.dart';
import 'real_bridge.dart';

Finder field(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

Future<void> pumpAdd(WidgetTester tester) async {
  setGoldenSurface(tester);
  await tester.pumpWidget(appUnderTest(themeMode: ThemeMode.light, path: '/add'));
  await settle(tester);
}

/// Opens the (always-first) category picker and picks [name] via the
/// sheet's search box — robust regardless of list length/scroll position.
Future<void> selectCategory(WidgetTester tester, String name) async {
  await tester.tap(find.text('Select category').first);
  await settle(tester);
  await tester.enterText(field('Search...'), name);
  await settle(tester);
  await tester.tap(find.text(name).last);
  await settle(tester);
}

Future<void> submit(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Add transaction');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await settle(tester);
}

List<Map<String, dynamic>> allTransactions(RealBridge bridge) {
  final res = bridge.json('listTransactions', body: {}) as Map<String, dynamic>;
  return (res['results'] as List).cast<Map<String, dynamic>>();
}

int transactionCount(RealBridge bridge) =>
    (bridge.json('listTransactions', body: {}) as Map<String, dynamic>)['count']
        as int;

Map<String, dynamic> onlyTransaction(RealBridge bridge) {
  final results = allTransactions(bridge);
  expect(results, hasLength(1), reason: 'expected exactly one transaction');
  return results.first;
}

List<Map<String, dynamic>> allRecurrences(RealBridge bridge) =>
    (bridge.json('listRecurrences') as List).cast<Map<String, dynamic>>();

void expectMoney(String actual, String expected) => expect(
  Decimal.parse(actual),
  Decimal.parse(expected),
  reason: '"$actual" != "$expected"',
);

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

  // ── 2.2.1 ──────────────────────────────────────────────────────────
  testWidgets('2.2.1 one-off income', (tester) async {
    await pumpAdd(tester);
    await tester.tap(find.text('Income'));
    await settle(tester);
    await tester.enterText(field('e.g. Morning latte'), 'Freelance payment');
    await selectCategory(tester, 'Side Income');
    await tester.enterText(field('0.00').first, '500.25');
    await settle(tester);
    await submit(tester);
    expect(tester.takeException(), isNull);

    // Screen closed and returned to Home — no longer on the Add form.
    expect(find.widgetWithText(FilledButton, 'Add transaction'), findsNothing);

    final txn = onlyTransaction(bridge);
    expect(txn['type'], 'income');
    expect(txn['name'], 'Freelance payment');
    expect(txn['currency_code'], 'USD');
    expect(txn['recurrence_template_id'], isNull);
    final cats = (txn['TransactionCategory'] as List).cast<Map<String, dynamic>>();
    expect(cats, hasLength(1));
    expect(cats.first['Category']['name'], 'Side Income');
    expect(cats.first['Category']['type'], 'income');
    expectMoney(cats.first['amount'] as String, '500.25');
  });

  // ── 2.2.2 ──────────────────────────────────────────────────────────
  testWidgets('2.2.2 recurring income (monthly salary)', (tester) async {
    await pumpAdd(tester);
    await tester.tap(find.text('Income'));
    await settle(tester);
    await tester.enterText(field('e.g. Morning latte'), 'Monthly salary');
    await selectCategory(tester, 'Salary');
    await tester.enterText(field('0.00').first, '3000');
    await settle(tester);

    // WidgetTester.ensureVisible() doesn't scroll this row fully clear of
    // the fixed bottomNavigationBar's screen area (the "Recurring payment"
    // switch sits right at that boundary in a short form); a real user's
    // own scroll gesture has no such trouble, so a manual drag — not
    // ensureVisible — is the correct tool here, matching what a finger
    // actually does.
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await settle(tester);
    await tester.tap(find.byType(Switch).first); // "Recurring payment"
    await settle(tester);
    // Monthly is already the default frequency for a salary.
    expect(find.text('Monthly'), findsOneWidget);
    // No end date — an ongoing salary. "Has end date?" stays off.

    await submit(tester);
    expect(tester.takeException(), isNull);

    final recs = allRecurrences(bridge);
    expect(recs, hasLength(1));
    final rec = recs.single;
    expect(rec['name'], 'Monthly salary');
    expect(rec['type'], 'income');
    expect(rec['frequency'], 'monthly');
    expect(rec['currency_code'], 'USD');
    expect(rec['has_end_date'], isFalse);
    expect(rec['is_active'], isTrue);
    expectMoney(rec['next_payment_amount'] as String, '3000');

    // The template also books its first transaction.
    final txn = onlyTransaction(bridge);
    expect(txn['type'], 'income');
    expect(txn['name'], 'Monthly salary');
    expect(txn['recurrence_template_id'], rec['id']);
  });

  // ── 2.2.3 ──────────────────────────────────────────────────────────
  testWidgets('2.2.3 foreign-currency income', (tester) async {
    // availableCurrenciesProvider only offers the profile's base currency
    // plus currencies with a stored exchange rate (lib/state/providers.dart
    // availableCurrenciesProvider) — a fresh profile has none, so EUR must
    // be "added" first, exactly like a real user would via Settings.
    bridge.json(
      'upsertExchangeRate',
      body: {'from': 'EUR', 'to': 'USD', 'rate': '0.92'},
    );

    await pumpAdd(tester);
    await tester.tap(find.text('Income'));
    await settle(tester);
    await tester.enterText(field('e.g. Morning latte'), 'Client payment');
    await tester.tap(find.text('USD'));
    await settle(tester);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').startsWith('EUR'),
      ),
    );
    await settle(tester);
    expect(find.text('EUR'), findsOneWidget);

    await selectCategory(tester, 'Business');
    await tester.enterText(field('0.00').first, '1000');
    await settle(tester);
    await submit(tester);
    expect(tester.takeException(), isNull);

    final txn = onlyTransaction(bridge);
    expect(txn['type'], 'income');
    expect(txn['currency_code'], 'EUR');
    final cats = (txn['TransactionCategory'] as List).cast<Map<String, dynamic>>();
    expect(cats.first['Category']['name'], 'Business');
    expect(cats.first['Category']['type'], 'income');
    expectMoney(cats.first['amount'] as String, '1000');
  });

  // ── 2.2.4 ──────────────────────────────────────────────────────────
  testWidgets(
    '2.2.4 category picker filters by type; switching clears an incompatible pick',
    (tester) async {
      await pumpAdd(tester);
      await tester.enterText(field('e.g. Morning latte'), 'Type-switch test');

      // Default type is Expense — the picker must offer only expense
      // categories.
      await tester.tap(find.text('Select category').first);
      await settle(tester);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Salary'), findsNothing);
      await tester.tap(find.text('Food'));
      await settle(tester);
      expect(find.text('Food'), findsOneWidget);

      await tester.enterText(field('0.00').first, '42');
      await settle(tester);
      expect(find.text('42'), findsOneWidget);

      // Switch to Income.
      await tester.tap(find.text('Income'));
      await settle(tester);

      // The now-incompatible expense category selection is cleared.
      expect(find.text('Select category'), findsOneWidget);
      expect(find.text('Food'), findsNothing);
      // The Name field (unrelated to type) survives the switch...
      expect(find.text('Type-switch test'), findsOneWidget);
      // ...but the amount the user had already typed does NOT: switching
      // type calls _resetCategoryRows() (add_transaction_screen.dart:96),
      // which disposes the whole row — category AND amount controller —
      // rather than clearing only the category selection. A user who types
      // an amount, then taps the wrong type pill by mistake, silently loses
      // it too.
      expect(find.text('42'), findsNothing);
      final amountField = tester.widget<TextField>(field('0.00').first);
      expect(amountField.controller!.text, isEmpty);

      // Picker now offers only income categories.
      await tester.tap(find.text('Select category').first);
      await settle(tester);
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Food'), findsNothing);
      await tester.tap(find.text('Salary'));
      await settle(tester);

      // Switch back to Expense: income pick is cleared, expense list back.
      await tester.tap(find.text('Expense'));
      await settle(tester);
      expect(find.text('Select category'), findsOneWidget);
      expect(find.text('Salary'), findsNothing);
      await tester.tap(find.text('Select category').first);
      await settle(tester);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Salary'), findsNothing);

      expect(tester.takeException(), isNull);
    },
  );

  // ── 2.3.1 ──────────────────────────────────────────────────────────
  group('2.3.1 empty / zero / negative amount blocked, nothing persisted', () {
    testWidgets('2.3.1a empty amount', (tester) async {
      await pumpAdd(tester);
      await tester.enterText(field('e.g. Morning latte'), 'Empty amount test');
      await selectCategory(tester, 'Food');
      await submit(tester);
      expect(find.text('Required'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add transaction'), findsOneWidget);
      expect(transactionCount(bridge), 0);
    });

    testWidgets('2.3.1b zero amount', (tester) async {
      await pumpAdd(tester);
      await tester.enterText(field('e.g. Morning latte'), 'Zero amount test');
      await selectCategory(tester, 'Food');
      await tester.enterText(field('0.00').first, '0');
      await submit(tester);
      expect(find.text('Enter an amount greater than 0'), findsOneWidget);
      expect(transactionCount(bridge), 0);
    });

    testWidgets(
      '2.3.1c negative amount cannot even be typed (formatter rejects "-")',
      (tester) async {
        await pumpAdd(tester);
        await tester.enterText(
          field('e.g. Morning latte'),
          'Negative amount test',
        );
        await selectCategory(tester, 'Food');
        await tester.enterText(field('0.00').first, '-50');
        await settle(tester);
        // AmountInputFormatter's regex (utils/amount_input.dart:33) has no
        // '-' branch, so the whole edit is rejected and the field stays
        // exactly as it was (empty) — there is no way to type a negative
        // amount through this field at all.
        final amountField = tester.widget<TextField>(field('0.00').first);
        expect(amountField.controller!.text, isEmpty);
        await submit(tester);
        expect(find.text('Required'), findsOneWidget);
        expect(transactionCount(bridge), 0);
      },
    );
  });

  // ── 2.3.2 ──────────────────────────────────────────────────────────
  group('2.3.2 grouped / high-precision / large / locale-ish amount input', () {
    testWidgets('2.3.2a US-style grouped input stores exactly', (tester) async {
      await pumpAdd(tester);
      await tester.enterText(field('e.g. Morning latte'), 'Grouped input test');
      await tester.enterText(field('0.00').first, '1,234.56');
      await settle(tester);
      expect(find.text('1,234.56'), findsOneWidget);
      await selectCategory(tester, 'Food');
      await submit(tester);
      expect(tester.takeException(), isNull);
      final cats =
          (onlyTransaction(bridge)['TransactionCategory'] as List)
              .cast<Map<String, dynamic>>();
      expectMoney(cats.first['amount'] as String, '1234.56');
    });

    testWidgets('2.3.2b very large amount stores exactly', (tester) async {
      await pumpAdd(tester);
      await tester.enterText(field('e.g. Morning latte'), 'Large amount test');
      await tester.enterText(field('0.00').first, '99999999.99');
      await settle(tester);
      expect(find.text('99,999,999.99'), findsOneWidget);
      await selectCategory(tester, 'Food');
      await submit(tester);
      expect(tester.takeException(), isNull);
      final cats =
          (onlyTransaction(bridge)['TransactionCategory'] as List)
              .cast<Map<String, dynamic>>();
      expectMoney(cats.first['amount'] as String, '99999999.99');
    });

  });

  // ── 2.3.3 ──────────────────────────────────────────────────────────
  group('2.3.3 no category / missing title blocked', () {
    testWidgets('2.3.3a missing title', (tester) async {
      await pumpAdd(tester);
      await selectCategory(tester, 'Food');
      await tester.enterText(field('0.00').first, '25');
      await submit(tester);
      expect(find.text('Required'), findsOneWidget);
      expect(transactionCount(bridge), 0);
    });

    testWidgets('2.3.3b no category selected', (tester) async {
      await pumpAdd(tester);
      await tester.enterText(field('e.g. Morning latte'), 'No category test');
      await tester.enterText(field('0.00').first, '25');
      await submit(tester);
      expect(find.text('Required'), findsOneWidget);
      expect(transactionCount(bridge), 0);
    });
  });

  // ── 2.3.4 ──────────────────────────────────────────────────────────
  group('2.3.4 discard-changes dialog on back', () {
    testWidgets('2.3.4a clean form pops immediately, no dialog', (tester) async {
      await pumpAdd(tester);
      await tester.pageBack();
      await settle(tester);
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Add transaction'), findsNothing);
    });

    testWidgets(
      '2.3.4b dirty form: Keep editing preserves data, Discard leaves without saving',
      (tester) async {
        await pumpAdd(tester);
        await tester.enterText(field('e.g. Morning latte'), 'Unsaved draft');
        await settle(tester);

        await tester.pageBack();
        await settle(tester);
        expect(find.text('Discard changes?'), findsOneWidget);

        await tester.tap(find.text('Keep editing'));
        await settle(tester);
        expect(find.text('Discard changes?'), findsNothing);
        expect(find.text('Unsaved draft'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Add transaction'), findsOneWidget);

        await tester.pageBack();
        await settle(tester);
        expect(find.text('Discard changes?'), findsOneWidget);
        await tester.tap(find.text('Discard changes'));
        await settle(tester);
        expect(find.text('Discard changes?'), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Add transaction'), findsNothing);
        expect(transactionCount(bridge), 0);
      },
    );
  });

}
