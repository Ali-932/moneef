// T2.1 Create transaction → Expense, e2e against the real Go core
// (mobilebridge/_e2e/main.go via RealBridge — see mobilebridge/API.md). One testWidgets
// per leaf of the flow tree:
//
//   2.1.1  one-off, single category
//   2.1.2  one-off, split across 2-3 categories
//   2.1.3a recurring, no end date — weekly
//   2.1.3b recurring, no end date — bi-weekly
//   2.1.3c recurring, no end date — monthly
//   2.1.3d recurring, no end date — yearly
//   2.1.4  recurring with end date — occurrences stop at end date
//   2.1.5  installment plan — total/paid progress
//   2.1.6  foreign currency
//   2.1.7  back-dated, future-dated, timezone boundary
//   2.1.8  category created inline from the picker, then used
//
// Each leaf drives the real Add Transaction UI, then verifies independently
// via bridge.json(...) (source of truth) and, where a UI surface exists for
// it, the rendered screen.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/utils/format.dart' show formatMoney;
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/harness.dart';
import 'real_bridge.dart';

/// Matches the `field(hint)` idiom from transaction_entry_test.dart: a
/// [TextField] (including the one a [TextFormField] builds internally) by
/// its hint text.
Finder field(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

Future<void> pumpAdd(WidgetTester tester, {bool golden = true}) async {
  if (golden) setGoldenSurface(tester);
  await tester.pumpWidget(
    appUnderTest(themeMode: ThemeMode.light, path: '/add'),
  );
  await settle(tester);
}

/// Opens the (always-first, unselected) category picker on the Add
/// Transaction screen and picks [name] via the sheet's search box.
Future<void> selectCategory(WidgetTester tester, String name) async {
  await tester.tap(find.text('Select category').first);
  await settle(tester);
  await tester.enterText(field('Search...'), name);
  await settle(tester);
  // `find.text` also matches the search EditableText itself (its content
  // equals [name] too) — the list tile is built after it, so `.last` picks
  // the actual result row, not the search box.
  await tester.tap(find.text(name).last);
  await settle(tester);
}

Future<void> submit(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Add transaction'));
  await settle(tester);
}

/// Scrolls [finder] on-screen and taps it. `ensureVisible` only jumps the
/// scroll offset — the render tree doesn't reflow until a frame is pumped —
/// so a bare `ensureVisible` immediately followed by `tap` still hit-tests
/// against the pre-scroll (often off-screen) layout. A `pump()` in between
/// is required.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

/// Same reflow requirement as [tapVisible], for text entry.
Future<void> enterTextVisible(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.enterText(finder, text);
}

/// Switches the Material date picker into type-a-date mode and enters
/// [target] exactly, instead of tapping a specific calendar day cell (which
/// would need multi-month navigation for far-future/past dates).
Future<void> pickDate(
  WidgetTester tester, {
  required Finder trigger,
  required DateTime target,
}) async {
  await tapVisible(tester, trigger);
  await settle(tester);
  await tester.tap(find.byIcon(Icons.edit_calendar_outlined));
  await settle(tester);
  final input = find
      .descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byType(TextField),
      )
      .first;
  final text =
      '${target.month.toString().padLeft(2, '0')}/'
      '${target.day.toString().padLeft(2, '0')}/${target.year}';
  await tester.enterText(input, text);
  await settle(tester);
  await tester.tap(find.text('Use date'));
  await settle(tester);
}

Map<String, dynamic> categoryByName(
  RealBridge bridge,
  String name, {
  String type = 'expense',
}) {
  final cats = (bridge.json('listCategories', body: {'type': type}) as List)
      .cast<Map<String, dynamic>>();
  return cats.firstWhere(
    (c) => c['name'] == name,
    orElse: () => throw StateError('no category named "$name"'),
  );
}

List<Map<String, dynamic>> allTransactions(RealBridge bridge) {
  final res =
      bridge.json('listTransactions', body: {}) as Map<String, dynamic>;
  return (res['results'] as List).cast<Map<String, dynamic>>();
}

Map<String, dynamic> onlyTransaction(RealBridge bridge) {
  final results = allTransactions(bridge);
  expect(results, hasLength(1), reason: 'expected exactly one transaction');
  return results.first;
}

List<Map<String, dynamic>> allRecurrences(RealBridge bridge) =>
    (bridge.json('listRecurrences') as List).cast<Map<String, dynamic>>();

List<Map<String, dynamic>> recurrenceTimeline(RealBridge bridge) =>
    (bridge.json('recurrenceTimeline') as List).cast<Map<String, dynamic>>();

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

  // ── 2.1.1 ────────────────────────────────────────────────────────────
  testWidgets('2.1.1 one-off, single category', (tester) async {
    await pumpAdd(tester);
    await tester.enterText(field('e.g. Morning latte'), 'Coffee run');
    await tester.enterText(field('e.g. Blue Bottle'), 'Blue Bottle');
    await tester.enterText(
      field('e.g. Team lunch'),
      'Pre-meeting caffeine',
    );
    await selectCategory(tester, 'Food');
    await tester.enterText(field('0.00').first, '4.50');
    await settle(tester);
    expect(
      find.text(formatMoney(Decimal.parse('4.50'), 'USD')),
      findsOneWidget,
    );

    await submit(tester);
    expect(tester.takeException(), isNull);

    final txn = onlyTransaction(bridge);
    expect(txn['name'], 'Coffee run');
    expect(txn['merchant_name'], 'Blue Bottle');
    expect(txn['notes'], 'Pre-meeting caffeine');
    expect(txn['type'], 'expense');
    expect(txn['currency_code'], 'USD');
    final cats = (txn['TransactionCategory'] as List)
        .cast<Map<String, dynamic>>();
    expect(cats, hasLength(1));
    expectMoney(cats.first['amount'] as String, '4.50');
    expect(cats.first['Category']['name'], 'Food');

    // Rendered UI: the Activity tab shows the new row.
    await tester.pumpWidget(
      appUnderTest(themeMode: ThemeMode.light, path: '/transactions'),
    );
    await settle(tester);
    expect(find.text('Coffee run'), findsOneWidget);
  });

  // ── 2.1.2 ────────────────────────────────────────────────────────────
  testWidgets('2.1.2 one-off, split across categories', (tester) async {
    await pumpAdd(tester);
    await tester.enterText(field('e.g. Morning latte'), 'Grocery run');
    await tester.tap(find.text('Add category split'));
    await settle(tester);
    await tester.tap(find.text('Add category split'));
    await settle(tester);

    await selectCategory(tester, 'Food');
    await tester.enterText(field('0.00').at(0), '10.00');
    await settle(tester);
    await selectCategory(tester, 'Transport');
    await tester.enterText(field('0.00').at(1), '5.25');
    await settle(tester);
    await selectCategory(tester, 'Shopping');
    await tester.enterText(field('0.00').at(2), '7.25');
    await settle(tester);

    expect(
      find.text(formatMoney(Decimal.parse('22.50'), 'USD')),
      findsOneWidget,
    );
    await submit(tester);
    expect(tester.takeException(), isNull);

    final txn = onlyTransaction(bridge);
    final cats = (txn['TransactionCategory'] as List)
        .cast<Map<String, dynamic>>();
    expect(cats, hasLength(3));
    final byCat = {
      for (final c in cats) c['Category']['name'] as String: c['amount'] as String,
    };
    expectMoney(byCat['Food']!, '10.00');
    expectMoney(byCat['Transport']!, '5.25');
    expectMoney(byCat['Shopping']!, '7.25');
    final sum = cats.fold(
      Decimal.zero,
      (s, c) => s + Decimal.parse(c['amount'] as String),
    );
    expect(sum, Decimal.parse('22.50'));
  });

  // ── 2.1.3 a-d ────────────────────────────────────────────────────────
  Future<void> createRecurringNoEnd(
    WidgetTester tester,
    String name,
    String pickerLabel, // label as shown in the Frequency sheet
  ) async {
    await pumpAdd(tester);
    await tester.enterText(field('e.g. Morning latte'), name);
    await selectCategory(tester, 'Utilities');
    await tester.enterText(field('0.00').first, '9.99');
    await settle(tester);
    // The recurrence section sits below the fold — scroll it on-screen
    // before tapping, or the tap lands on whatever the bottom bar paints
    // at that same offset instead.
    await tapVisible(tester, find.byType(Switch).first); // "Recurring payment"
    await settle(tester);
    if (pickerLabel != 'Monthly') {
      await tapVisible(tester, find.text('Monthly')); // default selection
      await settle(tester);
      await tester.tap(find.text(pickerLabel));
      await settle(tester);
    }
    await submit(tester);
    expect(tester.takeException(), isNull);
  }

  Future<void> expectRecurrenceGap(
    RealBridge bridge,
    String apiFrequency, {
    int? exactGapDays,
    // recurrenceTimeline only projects a fixed 30-day forward/backward
    // window (see mobilebridge/API.md § RecurrenceTimeline), so a yearly cadence
    // whose *next* occurrence lands ~365 days out has just the backward-
    // projected "today" entry inside that window — 1, not 2. Nothing wrong
    // with the product here, just the window size vs. the cadence.
    int minOccurrences = 2,
  }) async {
    final recs = allRecurrences(bridge);
    expect(recs, hasLength(1));
    final rec = recs.first;
    expect(rec['frequency'], apiFrequency);
    expect(rec['has_end_date'], isFalse);
    expect(rec['is_active'], isTrue);
    expect(rec['next_date'], isNotNull);

    final occurrences =
        recurrenceTimeline(bridge)
            .where((e) => e['id'] == rec['id'])
            .map((e) => DateTime.parse(e['date'] as String))
            .toList()
          ..sort();
    expect(
      occurrences.length,
      greaterThanOrEqualTo(minOccurrences),
      reason:
          'expected at least $minOccurrences projected occurrence(s) in the timeline',
    );
    if (exactGapDays != null) {
      expect(
        occurrences[1].difference(occurrences[0]).inDays,
        exactGapDays,
      );
    }
  }

  testWidgets('2.1.3a recurring weekly, no end date', (tester) async {
    await createRecurringNoEnd(tester, 'Gym membership', 'Weekly');
    await expectRecurrenceGap(bridge, 'weekly', exactGapDays: 7);

    await tester.pumpWidget(
      appUnderTest(themeMode: ThemeMode.light, path: '/profile/recurrences'),
    );
    await settle(tester);
    expect(find.text('Gym membership'), findsOneWidget);
    expect(find.textContaining('Weekly'), findsWidgets);
  });

  testWidgets('2.1.3b recurring bi-weekly, no end date', (tester) async {
    await createRecurringNoEnd(tester, 'Cleaning service', 'Bi-weekly');
    await expectRecurrenceGap(bridge, 'bi-weekly', exactGapDays: 14);
  });

  testWidgets('2.1.3c recurring monthly, no end date', (tester) async {
    await createRecurringNoEnd(tester, 'Streaming plan', 'Monthly');
    await expectRecurrenceGap(bridge, 'monthly');
    final gap = recurrenceTimeline(bridge)
        .map((e) => DateTime.parse(e['date'] as String))
        .toList()
      ..sort();
    expect(
      gap[1].difference(gap[0]).inDays,
      inInclusiveRange(27, 31),
      reason: 'monthly cadence should land ~one calendar month apart',
    );
  });

  testWidgets('2.1.3d recurring yearly, no end date', (tester) async {
    await createRecurringNoEnd(tester, 'Domain renewal', 'Yearly');
    // Only the backward-projected "today" entry falls inside the 30-day
    // timeline window for a yearly cadence — assert cadence via next_date
    // directly instead of a same-window gap.
    await expectRecurrenceGap(bridge, 'yearly', minOccurrences: 1);
    final rec = allRecurrences(bridge).first;
    final nextDate = DateTime.parse(rec['next_date'] as String);
    final gapDays = nextDate.difference(DateTime.now().toUtc()).inDays;
    expect(
      gapDays,
      inInclusiveRange(360, 366),
      reason: 'yearly next_date should land ~one year after creation',
    );
  });

  // ── 2.1.4 ────────────────────────────────────────────────────────────
  testWidgets(
    '2.1.4 recurring with end date stops occurrences at end date',
    (tester) async {
      await pumpAdd(tester);
      await tester.enterText(
        field('e.g. Morning latte'),
        'Short-term standing order',
      );
      await selectCategory(tester, 'Utilities');
      await tester.enterText(field('0.00').at(0), '20.00');
      await settle(tester);

      await tapVisible(tester, find.byType(Switch).at(0)); // Recurring
      await settle(tester);
      await tapVisible(tester, find.text('Monthly'));
      await settle(tester);
      await tester.tap(find.text('Weekly'));
      await settle(tester);

      await tapVisible(tester, find.byType(Switch).at(1)); // Has end date?
      await settle(tester);

      final today = DateTime.now();
      final endDate = DateTime(
        today.year,
        today.month,
        today.day,
      ).add(const Duration(days: 15));
      await pickDate(
        tester,
        trigger: find.byIcon(Icons.calendar_today_outlined).last,
        target: endDate,
      );

      await enterTextVisible(tester, field('0.00').at(1), '80.00'); // total
      await tester.enterText(field('0.00').at(2), '0.00'); // paid previously
      await settle(tester);

      await submit(tester);
      expect(tester.takeException(), isNull);

      final recs = allRecurrences(bridge);
      expect(recs, hasLength(1));
      final rec = recs.first;
      expect(rec['frequency'], 'weekly');
      expect(rec['has_end_date'], isTrue);
      final storedEnd = DateTime.parse(rec['end_date'] as String);
      expect(
        storedEnd.isAtSameMomentAs(endDate.toUtc()),
        isTrue,
        reason:
            'stored end_date ${storedEnd.toIso8601String()} vs picked '
            '${endDate.toUtc().toIso8601String()}',
      );

      final occurrences = recurrenceTimeline(bridge)
          .where((e) => e['id'] == rec['id'])
          .map((e) => DateTime.parse(e['date'] as String))
          .toList();
      expect(occurrences, isNotEmpty);
      for (final occ in occurrences) {
        expect(
          occ.isAfter(storedEnd),
          isFalse,
          reason: 'occurrence $occ booked after end date $storedEnd',
        );
      }
      expect(
        occurrences.length,
        greaterThanOrEqualTo(2),
        reason: 'weekly cadence over 15 days should book at least twice',
      );
    },
  );

  // ── 2.1.5 ────────────────────────────────────────────────────────────
  testWidgets(
    '2.1.5 installment plan tracks paid-vs-total progress',
    (tester) async {
      await pumpAdd(tester);
      await tester.enterText(
        field('e.g. Morning latte'),
        'Laptop installment',
      );
      await selectCategory(tester, 'Shopping');
      await tester.enterText(field('0.00').at(0), '100.00');
      await settle(tester);

      await tapVisible(tester, find.byType(Switch).at(0)); // Recurring
      await settle(tester);
      // Monthly is already the default frequency — leave as-is.
      await tapVisible(tester, find.byType(Switch).at(1)); // Has end date?
      await settle(tester);

      final today = DateTime.now();
      final endDate = DateTime(
        today.year,
        today.month,
        today.day,
      ).add(const Duration(days: 180));
      await pickDate(
        tester,
        trigger: find.byIcon(Icons.calendar_today_outlined).last,
        target: endDate,
      );

      await enterTextVisible(tester, field('0.00').at(1), '600.00'); // total
      await tester.enterText(field('0.00').at(2), '200.00'); // already paid
      await settle(tester);
      await submit(tester);
      expect(tester.takeException(), isNull);

      // Creating a recurring transaction books its first installment
      // immediately (mobilebridge/API.md § CreateTransaction), so that "100" is a
      // real, separate Transaction row — on top of the 200 the user already
      // declared as paid before they started tracking the plan here.
      final firstPayment = onlyTransaction(bridge);
      expect(firstPayment['name'], 'Laptop installment');
      expectMoney(
        (firstPayment['TransactionCategory'] as List)
                .cast<Map<String, dynamic>>()
                .first['amount']
            as String,
        '100.00',
      );

      final rec = allRecurrences(bridge).first;
      expectMoney(rec['total_amount_to_pay'] as String, '600.00');
      expectMoney(rec['amount_paid_previously'] as String, '200.00');
      // 600 total - 200 paid-before-tracking - 100 just-booked-first-payment.
      expectMoney(rec['amount_left_to_pay'] as String, '300.00');

      // UI check: the Recurring payments screen lists the template, but —
      // see the filed finding — renders none of the progress numbers the
      // backend just computed (no "$200 of $600", no progress bar).
      await tester.pumpWidget(
        appUnderTest(
          themeMode: ThemeMode.light,
          path: '/profile/recurrences',
        ),
      );
      await settle(tester);
      expect(find.textContaining('Laptop installment'), findsOneWidget);
      expect(find.textContaining('200'), findsNothing);
      expect(find.textContaining('600'), findsNothing);
      expect(find.textContaining('400'), findsNothing);
    },
  );

  // ── 2.1.6 ────────────────────────────────────────────────────────────
  testWidgets(
    '2.1.6 foreign currency: stored as-is, converted on the dashboard',
    (tester) async {
      bridge.json(
        'upsertExchangeRate',
        body: {'from': 'EUR', 'to': 'USD', 'rate': '1.50'},
      );

      await pumpAdd(tester);
      await tester.enterText(field('e.g. Morning latte'), 'Berlin dinner');
      await tester.tap(find.text('USD'));
      await settle(tester);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').startsWith('EUR'),
        ),
      );
      await settle(tester);
      expect(find.text('EUR'), findsOneWidget);

      await selectCategory(tester, 'Food');
      await tester.enterText(field('0.00').first, '40.00');
      await settle(tester);
      expect(
        find.text(formatMoney(Decimal.parse('40.00'), 'EUR')),
        findsOneWidget,
      );

      await submit(tester);
      expect(tester.takeException(), isNull);

      final txn = onlyTransaction(bridge);
      expect(txn['currency_code'], 'EUR');
      final cats = (txn['TransactionCategory'] as List)
          .cast<Map<String, dynamic>>();
      expectMoney(cats.first['amount'] as String, '40.00');

      final dashboard =
          bridge.json('dashboard', body: {}) as Map<String, dynamic>;
      expect(dashboard['currency_code'], 'USD');
      // 40 EUR * 1.50 (EUR→USD) = 60.00 USD — see
      // pkg/utils/currency_convert.go:ConvertedAmount.
      expectMoney(dashboard['total_expense'] as String, '60.00');
    },
  );

  // ── 2.1.7 ────────────────────────────────────────────────────────────
  testWidgets(
    '2.1.7 back-dated, future-dated, and timezone-boundary dates store exactly',
    (tester) async {
      // Back-dated: explicit past date picked via the date field.
      await pumpAdd(tester);
      await tester.enterText(field('e.g. Morning latte'), 'Old receipt');
      await selectCategory(tester, 'Food');
      await tester.enterText(field('0.00').first, '5.00');
      await settle(tester);
      final backTarget = DateTime(2022, 3, 10);
      await pickDate(
        tester,
        trigger: find.byIcon(Icons.calendar_today_outlined).first,
        target: backTarget,
      );
      await submit(tester);
      expect(tester.takeException(), isNull);

      // Future-dated: explicit future date.
      await pumpAdd(tester);
      await tester.enterText(
        field('e.g. Morning latte'),
        'Prepaid subscription',
      );
      await selectCategory(tester, 'Entertainment');
      await tester.enterText(field('0.00').first, '9.00');
      await settle(tester);
      final futureTarget = DateTime(DateTime.now().year + 1, 6, 15);
      await pickDate(
        tester,
        trigger: find.byIcon(Icons.calendar_today_outlined).first,
        target: futureTarget,
      );
      await submit(tester);
      expect(tester.takeException(), isNull);

      // Timezone boundary: an *untouched* date keeps DateTime.now()'s real
      // time-of-day; an *explicitly picked* date (above, and the case
      // below) collapses to LOCAL midnight. In a positive-UTC-offset
      // timezone (this host is UTC+3, see `timedatectl`), local midnight's
      // UTC instant falls on the PREVIOUS UTC calendar day. Both paths must
      // still round-trip through the Go core exactly as submitted, with no
      // extra clamping/rounding of the app's own.
      final beforePump = DateTime.now();
      await pumpAdd(tester);
      await tester.enterText(
        field('e.g. Morning latte'),
        'Untouched-date expense',
      );
      await selectCategory(tester, 'Food');
      await tester.enterText(field('0.00').first, '1.00');
      await settle(tester);
      await submit(tester);
      final afterSubmit = DateTime.now();
      expect(tester.takeException(), isNull);

      Map<String, dynamic> byName(String n) =>
          allTransactions(bridge).firstWhere((t) => t['name'] == n);

      final backStored = DateTime.parse(byName('Old receipt')['date'] as String);
      expect(
        backStored.isAtSameMomentAs(backTarget.toUtc()),
        isTrue,
        reason:
            'stored ${backStored.toIso8601String()} vs picked '
            '${backTarget.toUtc().toIso8601String()}',
      );

      final futureStored =
          DateTime.parse(byName('Prepaid subscription')['date'] as String);
      expect(
        futureStored.isAtSameMomentAs(futureTarget.toUtc()),
        isTrue,
        reason:
            'stored ${futureStored.toIso8601String()} vs picked '
            '${futureTarget.toUtc().toIso8601String()}',
      );

      final untouchedStored =
          DateTime.parse(byName('Untouched-date expense')['date'] as String);
      expect(
        untouchedStored.isAfter(
          beforePump.subtract(const Duration(seconds: 5)),
        ),
        isTrue,
      );
      expect(
        untouchedStored.isBefore(afterSubmit.add(const Duration(seconds: 5))),
        isTrue,
      );
      // Demonstrates the boundary in a reproducible way (no need to fake
      // the wall clock at 23:30/00:30): an untouched submission keeps real
      // time-of-day, so — in a non-UTC timezone — it is NOT the same
      // instant as "picked local midnight of today".
      final localMidnightUtc =
          DateTime(beforePump.year, beforePump.month, beforePump.day).toUtc();
      if (beforePump.timeZoneOffset != Duration.zero) {
        expect(untouchedStored.isAtSameMomentAs(localMidnightUtc), isFalse);
      }
    },
  );

  // ── 2.1.8 ────────────────────────────────────────────────────────────
  testWidgets(
    '2.1.8 category created inline from the picker, then used',
    (tester) async {
      await pumpAdd(tester);
      await tester.enterText(
        field('e.g. Morning latte'),
        'Aquarium membership',
      );
      await tester.enterText(field('0.00').first, '25.00');
      await settle(tester);

      await tester.tap(find.text('Select category'));
      await settle(tester);
      await tester.enterText(field('Search...'), 'Zoo Membership');
      await settle(tester);
      expect(find.text('No results'), findsOneWidget);

      await tester.tap(find.text('Add new category'));
      await settle(tester);
      expect(find.text('New category'), findsOneWidget);
      await tester.enterText(field('Name'), 'Zoo Membership');
      await tester.ensureVisible(find.text('Create category'));
      await tester.tap(find.text('Create category'));
      await settle(tester);

      // Back on the form, the row now shows the freshly created category.
      expect(find.text('Zoo Membership'), findsOneWidget);
      await submit(tester);
      expect(tester.takeException(), isNull);

      final created = categoryByName(bridge, 'Zoo Membership');
      expect(created['type'], 'expense');

      final txn = onlyTransaction(bridge);
      final cats = (txn['TransactionCategory'] as List)
          .cast<Map<String, dynamic>>();
      expect(cats.first['category_id'], created['id']);
      expectMoney(cats.first['amount'] as String, '25.00');
    },
  );
}
