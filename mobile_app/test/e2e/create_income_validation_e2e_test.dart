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
import 'package:flutter/gestures.dart';
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

    testWidgets(
      '2.3.2c BUG: more than 2 decimal places is silently rounded away on save',
      (tester) async {
        await pumpAdd(tester);
        await tester.enterText(
          field('e.g. Morning latte'),
          'Three decimals test',
        );
        await tester.enterText(field('0.00').first, '1234.567');
        await settle(tester);
        // The UI happily accepts and displays all 3 decimals with no
        // warning that they will not be honored.
        expect(find.text('1,234.567'), findsOneWidget);
        await selectCategory(tester, 'Food');
        await submit(tester);
        expect(tester.takeException(), isNull);
        final cats =
            (onlyTransaction(bridge)['TransactionCategory'] as List)
                .cast<Map<String, dynamic>>();
        // BUG: pkg/types/money.go Money.Scan() unconditionally rounds every
        // value read back from the DB to config.AmountRounding (=2, see
        // internal/config/constants.go:6) — the write path stores the raw
        // "1234.567" untouched (Value() does not round), but every read
        // (list/get/dashboard/analysis) silently returns "1234.57" instead.
        // The amount the user typed and saw on screen is not what any
        // screen will ever show them again, with zero warning at input
        // time despite the field accepting arbitrary decimal places.
        expect(
          cats.first['amount'],
          '1234.567',
          reason:
              'BUG: 1234.567 as typed/displayed is silently rounded to '
              '1234.57 on read-back (pkg/types/money.go Money.Scan), no '
              'warning shown anywhere in the UI',
        );
      },
    );

    testWidgets(
      '2.3.2d BUG: EU-style decimal-comma input ("1.234,56") is silently '
      'misparsed as 1.23456',
      (tester) async {
        await pumpAdd(tester);
        await tester.enterText(field('e.g. Morning latte'), 'EU format test');
        await tester.enterText(field('0.00').first, '1.234,56');
        await settle(tester);
        final amountField = tester.widget<TextField>(field('0.00').first);
        // BUG: AmountInputFormatter/parseAmountInput (utils/amount_input.dart)
        // unconditionally strip every comma before validating, with no
        // awareness of comma-as-decimal-separator locales. "1.234,56" —
        // the EU/many-non-US way to write 1234.56 — has its comma stripped
        // down to "1.23456", which the digits-plus-one-dot regex happily
        // accepts: the amount silently becomes ~1000x smaller than typed,
        // with no error shown. It should either be rejected outright or
        // interpreted correctly — never silently corrupted in magnitude.
        expect(
          amountField.controller!.text,
          isNot('1.23456'),
          reason:
              'BUG: EU-style "1.234,56" (meaning 1234.56) silently became '
              '"${amountField.controller!.text}" — a ~1000x understatement '
              'with no error shown to the user',
        );
      },
    );
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

  // ── 2.3.5 ──────────────────────────────────────────────────────────
  group('2.3.5 Go error surfaced; no silent failure; no double submit', () {
    testWidgets(
      '2.3.5a BUG: a category deleted mid-edit does not block submission — '
      'the transaction silently saves with a dangling category reference',
      (tester) async {
        final cat = bridge.json(
          'createCategory',
          body: {'name': 'Freelance Gig', 'type': 'income', 'icon': '', 'color': ''},
        ) as Map<String, dynamic>;
        final catId = (cat['id'] as num).toInt();

        await pumpAdd(tester);
        await tester.tap(find.text('Income'));
        await settle(tester);
        await tester.enterText(field('e.g. Morning latte'), 'Stale category test');
        await selectCategory(tester, 'Freelance Gig');
        await tester.enterText(field('0.00').first, '75');
        await settle(tester);

        // Simulate the category disappearing after it was picked (e.g. the
        // user deleted it in another session) — the Add form's cached
        // category list is unaware, exactly like a real race.
        bridge.json('deleteCategory', id: catId);

        await submit(tester);
        expect(tester.takeException(), isNull);

        // What actually happens is worse than a surfaced error: creation
        // *succeeds* — no SnackBar, no block — leaving a permanently
        // dangling category_id.
        //
        // Root cause, traced all the way down: internal/db/db.go:38 opens
        // the DB with DSN "...?_foreign_keys=on&_journal_mode=WAL", but the
        // driver actually in use (github.com/glebarez/sqlite →
        // github.com/glebarez/go-sqlite, a modernc.org/sqlite wrapper) does
        // not recognize a bare "_foreign_keys" query parameter at all — its
        // own doc comment (go-sqlite/sqlite.go:1544-1546) spells out the
        // real syntax: "_pragma=foreign_keys(1)". "_foreign_keys=on" is
        // silently ignored, so `PRAGMA foreign_keys` stays 0 (confirmed by
        // querying it directly against a freshly migrated DB opened with
        // this exact DSN). The FK *constraints themselves* are present in
        // the schema (confirmed via `PRAGMA foreign_key_list`,
        // `category_id → categories.id ON DELETE CASCADE`) — they are
        // simply never enforced. This is not specific to categories or to
        // this screen: it silently disables referential-integrity
        // enforcement for every foreign key in the whole app (Transaction→
        // Profile, TransactionCategory→Transaction, RecurrenceTemplate→
        // Profile, ...), and the mobile_app CLAUDE.md's documented
        // connection string carries the same broken parameter.
        expect(find.byType(SnackBar), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Add transaction'), findsNothing);
        expect(
          transactionCount(bridge),
          0,
          reason:
              'BUG: creating a transaction against a category deleted a '
              'moment earlier should be rejected (API.md documents '
              '"record not found if a category id does not belong to the '
              'profile"), but it silently succeeded instead, because FK '
              'enforcement is off (internal/db/db.go:38 "_foreign_keys=on" '
              'is not a parameter the glebarez/sqlite driver understands — '
              'see go-sqlite/sqlite.go:1544-1546, it needs '
              '"_pragma=foreign_keys(1)"). Persisted transaction now carries '
              'category_id=$catId, which no longer exists.',
        );

        // Show the actual damage: reading the transaction back returns a
        // TransactionCategory whose Category preload silently comes back
        // as the Go zero value (id 0, empty name/icon/color) — any screen
        // rendering this transaction's category (list row, detail screen,
        // analysis-by-category chart) gets a blank/garbage entry forever,
        // with nothing to signal *why*.
        final txn = onlyTransaction(bridge);
        final cats = (txn['TransactionCategory'] as List).cast<Map<String, dynamic>>();
        expect(cats.first['category_id'], catId);
        expect(
          cats.first['Category']['name'],
          isNotEmpty,
          reason:
              'BUG: the persisted transaction\'s category now resolves to '
              'a blank/zero-value Category (id 0, name "") because '
              'category_id $catId no longer exists — every future read of '
              'this transaction silently renders a broken category',
        );
      },
    );

    testWidgets(
      '2.3.5b BUG: double-tapping submit before the button disables can '
      'create two transactions',
      (tester) async {
        await pumpAdd(tester);
        await tester.enterText(field('e.g. Morning latte'), 'Double tap test');
        await selectCategory(tester, 'Food');
        await tester.enterText(field('0.00').first, '10');
        await settle(tester);

        // A plain `await tester.tap(button); await tester.tap(button);`
        // (no pump() between them) is NOT enough to exercise this race:
        // RealBridge's FFI call is fully synchronous end-to-end, so the
        // first `await tester.tap()` already drains the whole microtask
        // chain through _submit() → ctrl.create() → the native call and
        // back before that `await` even returns — there is no window left
        // for a second sequential tap to land "mid-flight". A real device
        // has a genuine async gap (JNI hop to the platform thread, see
        // mobilebridge/API.md § RefreshPatterns "Performance notes"), and two
        // fast taps CAN both be dispatched by the OS before Flutter paints
        // the disabled frame. The only way to reproduce that here is to
        // dispatch two full down+up taps back-to-back with zero `await`
        // between them, so Dart never gets a chance to drain the
        // microtask queue between tap #1 and tap #2 — the closest a
        // widget test can get to two fingers landing in the same turn.
        final button = find.widgetWithText(FilledButton, 'Add transaction');
        final box = tester.renderObject(button) as RenderBox;
        final center = box.localToGlobal(box.size.center(Offset.zero));
        final binding = tester.binding;
        binding.handlePointerEvent(PointerDownEvent(pointer: 101, position: center));
        binding.handlePointerEvent(PointerUpEvent(pointer: 101, position: center));
        binding.handlePointerEvent(PointerDownEvent(pointer: 102, position: center));
        binding.handlePointerEvent(PointerUpEvent(pointer: 102, position: center));
        await settle(tester);
        expect(tester.takeException(), isNull);

        // BUG, confirmed: add_transaction_screen.dart _submit() has no
        // `if (_busy) return;` guard at its top. Its only in-flight
        // protection is the *rebuilt* button's `_busy ? null : _submit`
        // (around line 378), which only takes effect after Flutter paints
        // a new frame. Two taps landing before that frame both run
        // _submit()'s full body, including its own `await
        // ctrl.create(draft)` — no shared lock stops the second one.
        expect(
          transactionCount(bridge),
          1,
          reason:
              'BUG: two taps landing in the same turn (no frame between '
              'them to disable the button) created '
              '${transactionCount(bridge)} transactions instead of 1 — '
              'add_transaction_screen.dart _submit() has no in-flight '
              'guard of its own',
        );
      },
    );
  });
}
