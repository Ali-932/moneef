// E2E flow tree for T5 Recurrences (/profile/recurrences), driven against
// the REAL Go core over dart:ffi (see RealBridge) with real UI interaction
// where a UI path exists. See the accompanying report for the full tree;
// each `testWidgets` below is one leaf, named with its leaf id.
//
// Root cause citations for bugs found while writing these tests point at
// the Go core (internal/transactions/service/transaction_service.go,
// internal/models/transaction.go) and the Flutter layer
// (mobile_app/lib/screens/recurrences_screen.dart,
// mobile_app/lib/models/recurrence_occurrence.dart).
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/theme.dart';
import 'package:mobile_app/utils/format.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/harness.dart';
import 'real_bridge.dart';

// ── local test helpers (this file only) ─────────────────────────────────

/// Finds a seeded category id by exact name + type (both are global,
/// profile_id-null defaults seeded on Init — see mobilebridge/seed_defaults.go).
int categoryId(RealBridge bridge, String type, String name) {
  final list = (bridge.json('listCategories', body: {'type': type}) as List)
      .cast<Map<String, dynamic>>();
  final match = list.cast<Map<String, dynamic>?>().firstWhere(
    (c) => c!['name'] == name,
    orElse: () => null,
  );
  if (match == null) {
    throw StateError('seeded category "$name"/$type not found: $list');
  }
  return (match['id'] as num).toInt();
}

/// Builds the CreateTransaction payload for a recurring transaction, per
/// mobilebridge/API.md's "recurrent subscription" shape.
Map<String, dynamic> recurringPayload({
  required String name,
  required String type,
  required String currency,
  required DateTime date,
  required String freq,
  required int categoryId,
  required String amount,
  bool hasEndDate = false,
  DateTime? endDate,
  String? totalAmount,
  String? paidPreviously,
}) {
  final body = <String, dynamic>{
    'transaction_name': name,
    'currency_code': currency,
    'transaction_type': type,
    'date': date.toUtc().toIso8601String(),
    'is_recurrent': true,
    'recurrent_freq': freq,
    'is_active_recurrent': true,
    'transaction_categories': [
      {'category_id': categoryId, 'amount': amount},
    ],
  };
  if (hasEndDate) {
    body['recurrent_has_end_date'] = true;
    body['recurrent_end_date'] = endDate!.toUtc().toIso8601String();
    body['recurrent_total_amount'] = totalAmount;
    body['recurrent_paid_previously'] = paidPreviously;
  }
  return body;
}

Map<String, dynamic> findByName(Object? raw, String name) {
  final list = (raw as List).cast<Map<String, dynamic>>();
  return list.firstWhere(
    (r) => r['name'] == name,
    orElse: () => throw StateError('"$name" not found among: $list'),
  );
}

List<Map<String, dynamic>> allByName(Object? raw, String name) {
  final list = (raw as List).cast<Map<String, dynamic>>();
  return list.where((r) => r['name'] == name).toList();
}

void main() {
  final bridge = RealBridge.instance;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bridge.resetWithProfile(); // fresh DB, profile id 1, default currency USD
    bridge.install();
  });

  // ── 5.1 List shows each recurrence with correct frequency/amount/next date ──

  testWidgets('5.1.1 weekly recurrence — bridge + list row correctness', (
    tester,
  ) async {
    final catId = categoryId(bridge, 'expense', 'Food');
    final date = DateTime.now().toUtc();
    bridge.json(
      'createTransaction',
      body: recurringPayload(
        name: 'Weekly Groceries',
        type: 'expense',
        currency: 'USD',
        date: date,
        freq: 'weekly',
        categoryId: catId,
        amount: '25.00',
      ),
    );

    final tpl = findByName(bridge.json('listRecurrences'), 'Weekly Groceries');
    expect(tpl['frequency'], 'weekly');
    expect(tpl['currency_code'], 'USD');
    expect(tpl['is_active'], isTrue);
    expect(tpl['has_end_date'], isFalse);
    expect(
      Decimal.parse(tpl['next_payment_amount'] as String),
      Decimal.parse('25.00'),
    );
    final expectedNext = date.add(const Duration(days: 7));
    final actualNext = DateTime.parse(tpl['next_date'] as String);
    expect(
      actualNext.difference(expectedNext).inSeconds.abs(),
      lessThan(2),
      reason: 'weekly next_date should be exactly start date + 7 days',
    );

    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(themeMode: ThemeMode.light, path: '/profile/recurrences'),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Weekly Groceries'), findsOneWidget);
    expect(find.text('Next ${formatDateLong(actualNext)}'), findsOneWidget);
    expect(find.text('Expense · Weekly'), findsOneWidget);
    expect(
      find.text(formatMoney(-Decimal.parse('25.00'), 'USD')),
      findsOneWidget,
    );
  });

  testWidgets('5.1.2 bi-weekly recurrence — bridge + list row correctness', (
    tester,
  ) async {
    final catId = categoryId(bridge, 'expense', 'Utilities');
    final date = DateTime.now().toUtc();
    bridge.json(
      'createTransaction',
      body: recurringPayload(
        name: 'Biweekly Cleaner',
        type: 'expense',
        currency: 'USD',
        date: date,
        freq: 'bi-weekly',
        categoryId: catId,
        amount: '40.00',
      ),
    );

    final tpl = findByName(bridge.json('listRecurrences'), 'Biweekly Cleaner');
    expect(tpl['frequency'], 'bi-weekly');
    final expectedNext = date.add(const Duration(days: 14));
    final actualNext = DateTime.parse(tpl['next_date'] as String);
    expect(actualNext.difference(expectedNext).inSeconds.abs(), lessThan(2));

    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(themeMode: ThemeMode.light, path: '/profile/recurrences'),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Next ${formatDateLong(actualNext)}'), findsOneWidget);
    expect(
      find.text(formatMoney(-Decimal.parse('40.00'), 'USD')),
      findsOneWidget,
    );
  });

  testWidgets('5.1.3 monthly recurrence — bridge + list row correctness', (
    tester,
  ) async {
    final catId = categoryId(bridge, 'expense', 'Entertainment');
    // Pick "today" but nudge to day 15 so the +1 month step never lands on a
    // short month for this particular case — the day-15..31 edge is covered
    // deterministically by 5.2.2.
    final now = DateTime.now().toUtc();
    final date = DateTime.utc(now.year, now.month, 15, 12);
    bridge.json(
      'createTransaction',
      body: recurringPayload(
        name: 'Monthly Streaming',
        type: 'expense',
        currency: 'USD',
        date: date,
        freq: 'monthly',
        categoryId: catId,
        amount: '12.00',
      ),
    );

    final tpl = findByName(bridge.json('listRecurrences'), 'Monthly Streaming');
    expect(tpl['frequency'], 'monthly');
    final actualNext = DateTime.parse(tpl['next_date'] as String);
    expect(actualNext.day, 15);

    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(themeMode: ThemeMode.light, path: '/profile/recurrences'),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Next ${formatDateLong(actualNext)}'), findsOneWidget);
  });

  testWidgets('5.1.4 yearly recurrence — bridge + list row correctness', (
    tester,
  ) async {
    final catId = categoryId(bridge, 'income', 'Salary');
    final now = DateTime.now().toUtc();
    final date = DateTime.utc(now.year, now.month, 15, 9);
    bridge.json(
      'createTransaction',
      body: recurringPayload(
        name: 'Yearly Bonus',
        type: 'income',
        currency: 'USD',
        date: date,
        freq: 'yearly',
        categoryId: catId,
        amount: '500.00',
      ),
    );

    final tpl = findByName(bridge.json('listRecurrences'), 'Yearly Bonus');
    expect(tpl['frequency'], 'yearly');
    expect(tpl['type'], 'income');
    final actualNext = DateTime.parse(tpl['next_date'] as String);
    expect(actualNext.year, date.year + 1);
    expect(actualNext.month, date.month);
    expect(actualNext.day, 15);

    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(themeMode: ThemeMode.light, path: '/profile/recurrences'),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Yearly Bonus'), findsOneWidget);
    expect(find.text('Income · Yearly'), findsOneWidget);
    expect(
      find.text(formatMoney(Decimal.parse('500.00'), 'USD', signed: true)),
      findsOneWidget,
    );
  });

  testWidgets(
    '5.1.5 end-dated installment recurrence — list shows doc-matching fields',
    (tester) async {
      // Mirrors mobilebridge/API.md's own worked example numbers exactly so this
      // leaf is a straight spec-conformance check.
      final catId = categoryId(bridge, 'expense', 'Entertainment');
      final date = DateTime.now().toUtc();
      final endDate = date.add(const Duration(days: 365));
      bridge.json(
        'createTransaction',
        body: recurringPayload(
          name: 'Netflix',
          type: 'expense',
          currency: 'USD',
          date: date,
          freq: 'monthly',
          categoryId: catId,
          amount: '15.00',
          hasEndDate: true,
          endDate: endDate,
          totalAmount: '180.00',
          paidPreviously: '30.00',
        ),
      );

      final tpl = findByName(bridge.json('listRecurrences'), 'Netflix');
      expect(tpl['has_end_date'], isTrue);
      expect(
        Decimal.parse(tpl['total_amount_to_pay'] as String),
        Decimal.parse('180.00'),
      );
      expect(
        Decimal.parse(tpl['amount_paid_previously'] as String),
        Decimal.parse('30.00'),
      );
      expect(
        Decimal.parse(tpl['next_payment_amount'] as String),
        Decimal.parse('15.00'),
      );
      expect(
        Decimal.parse(tpl['amount_left_to_pay'] as String),
        Decimal.parse('135.00'),
      );

      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/profile/recurrences'),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Netflix'), findsOneWidget);
      expect(
        find.text(formatMoney(-Decimal.parse('15.00'), 'USD')),
        findsOneWidget,
      );
    },
  );

  testWidgets('5.1.6 recurrence shows its own currency and expense direction', (
    tester,
  ) async {
    // Profile default currency is USD (resetWithProfile()). Create a
    // recurrence in EUR and confirm the list preserves its currency.
    final catId = categoryId(bridge, 'expense', 'Travel');
    final date = DateTime.now().toUtc();
    bridge.json(
      'createTransaction',
      body: recurringPayload(
        name: 'Paris Rent',
        type: 'expense',
        currency: 'EUR',
        date: date,
        freq: 'monthly',
        categoryId: catId,
        amount: '50.00',
      ),
    );

    // The wire contract is correct: currency_code is really "EUR".
    final tpl = findByName(bridge.json('listRecurrences'), 'Paris Rent');
    expect(tpl['currency_code'], 'EUR');

    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(themeMode: ThemeMode.light, path: '/profile/recurrences'),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);

    expect(
      find.text(formatMoney(-Decimal.parse('50.00'), 'EUR')),
      findsOneWidget,
    );
    expect(
      find.text(formatMoney(-Decimal.parse('50.00'), 'USD')),
      findsNothing,
    );
    expect(find.text('Expense · Monthly'), findsOneWidget);
  });

  testWidgets(
    '5.1.7 a recurrence started in the past books what is due and moves next_date forward',
    (tester) async {
      // A finance app's "next payment" should never sit in the past. There
      // is no job anywhere in the codebase that advances
      // RecurrenceTemplate.NextDate after creation (grepped cmd/, internal/
      // for a scheduler/cron — only currency_rate_cron.go exists), so a
      // recurrence whose last period boundary has already elapsed shows a
      // stale, already-past "next" date forever.
      final catId = categoryId(bridge, 'expense', 'Shopping');
      final date = DateTime.now().toUtc().subtract(const Duration(days: 21));
      bridge.json(
        'createTransaction',
        body: recurringPayload(
          name: 'Old Weekly Thing',
          type: 'expense',
          currency: 'USD',
          date: date,
          freq: 'weekly',
          categoryId: catId,
          amount: '9.00',
        ),
      );

      final tpl = findByName(
        bridge.json('listRecurrences'),
        'Old Weekly Thing',
      );
      final nextDate = DateTime.parse(tpl['next_date'] as String);
      // Root cause: internal/transactions/service/transaction_service.go:164
      // sets NextDate = CalculateNextOccurrence(startDate, freq) exactly
      // once, at creation, and nothing ever recomputes it.
      expect(nextDate.isAfter(DateTime.now().toUtc()), isTrue);
      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/profile/recurrences'),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      // The UI renders whatever stale date the core hands it, with no
      // "overdue" affordance.
      expect(
        find.text('Next ${formatDateLong(nextDate)}'),
        findsOneWidget,
      );
    },
  );

  testWidgets('5.1.8 Home "Coming up" shows a recurring income as income', (
    tester,
  ) async {
    final catId = categoryId(bridge, 'income', 'Salary');
    bridge.json(
      'createTransaction',
      body: recurringPayload(
        name: 'Upcoming Salary',
        type: 'income',
        currency: 'USD',
        date: DateTime.now().toUtc(),
        freq: 'weekly',
        categoryId: catId,
        amount: '1234.56',
      ),
    );

    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(themeMode: ThemeMode.light, path: '/home'),
    );
    await settle(tester);
    for (
      var i = 0;
      i < 10 && find.text('Coming up').evaluate().isEmpty;
      i++
    ) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pump();
    }
    await settle(tester);
    expect(tester.takeException(), isNull);
    // Recent shows today's booked payment as +$1,234.56; the next one is
    // in "Coming up" as $1,234.56. Totals also show $1,234.56, so look only
    // inside the rows named after the recurrence.
    expect(find.textContaining(RegExp(r'^-.*1,234\.56')), findsNothing);
    final amount = find.descendant(
      of: find.ancestor(
        of: find.text('Upcoming Salary'),
        matching: find.byType(Row),
      ),
      matching: find.text(formatMoney(Decimal.parse('1234.56'), 'USD')),
    );
    expect(amount, findsOneWidget);
    final palette = tester.element(amount).palette;
    expect(tester.widget<Text>(amount).style?.color, palette.positiveText);
  });

  // ── 5.2 Timeline occurrences correct per frequency + end date ───────────

  testWidgets('5.2.1 weekly timeline occurrences are 7 days apart in-window', (
    tester,
  ) async {
    final catId = categoryId(bridge, 'expense', 'Food');
    final date = DateTime.now().toUtc();
    bridge.json(
      'createTransaction',
      body: recurringPayload(
        name: 'Weekly Timeline Check',
        type: 'expense',
        currency: 'USD',
        date: date,
        freq: 'weekly',
        categoryId: catId,
        amount: '25.00',
      ),
    );

    final occurrences = allByName(
      bridge.json('recurrenceTimeline'),
      'Weekly Timeline Check',
    );
    expect(occurrences.length, greaterThanOrEqualTo(4));
    final dates =
        occurrences.map((o) => DateTime.parse(o['date'] as String)).toList()
          ..sort();
    for (var i = 1; i < dates.length; i++) {
      expect(
        dates[i].difference(dates[i - 1]).inHours,
        7 * 24,
        reason: 'consecutive weekly occurrences must be exactly 7 days apart',
      );
    }

    // Cross-check against the Insights "Coming up" timeline strip. It sits
    // below the fold in the Overview tab's ListView, so scroll it into view
    // first (a plain ListView(children: ...) still lazily builds offscreen
    // slivers — find.text finds nothing until it's scrolled in).
    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(themeMode: ThemeMode.light, path: '/insights'),
    );
    await settle(tester);
    for (var i = 0; i < 10 && find.text('Coming up').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pump();
    }
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Weekly Timeline Check'), findsWidgets);

    // Scope to the horizontal timeline so the separate next-payment rows
    // cannot hide a broken currency mapping in recurrence occurrences.
    final timeline = find.byWidgetPredicate(
      (w) => w is ListView && w.scrollDirection == Axis.horizontal,
    );
    expect(
      find.descendant(of: timeline, matching: find.text(r'-$25.00')),
      findsWidgets,
    );
    expect(find.text(formatMoney(-Decimal.parse('25.00'), '')), findsNothing);
  });

  testWidgets(
    '5.2.2 monthly recurrence on Jan 31 next falls on Feb 28',
    (tester) async {
      // Deterministic, clock-independent: CalculateNextOccurrence uses raw
      // time.AddDate (pkg/utils/date_frequency.go:19), which does NOT clamp
      // day-of-month, so it overflows past a short February into March —
      // whereas the *later* addFrequency used by the timeline projector
      // (internal/transactions/service/transaction_service.go:333-341)
      // explicitly clamps via daysInMonth. The two "advance one month"
      // implementations disagree.
      final catId = categoryId(bridge, 'expense', 'Housing');
      final date = DateTime.utc(2099, 1, 31); // future: nothing booked yet
      bridge.json(
        'createTransaction',
        body: recurringPayload(
          name: 'Jan31 Monthly Rent',
          type: 'expense',
          currency: 'USD',
          date: date,
          freq: 'monthly',
          categoryId: catId,
          amount: '1000.00',
        ),
      );

      final tpl = findByName(
        bridge.json('listRecurrences'),
        'Jan31 Monthly Rent',
      );
      final actualNext = DateTime.parse(tpl['next_date'] as String).toUtc();

      // Sensible, expected behavior (matches the clamped semantics the app
      // itself uses one call site over, for the timeline): last day of Feb.
      final sensibleNext = DateTime.utc(2099, 2, 28);
      expect(
        actualNext.year == sensibleNext.year &&
            actualNext.month == sensibleNext.month &&
            actualNext.day == sensibleNext.day,
        isTrue,
        reason:
            'BUG: monthly recurrence anchored on Jan 31 should next fall on '
            'Feb 28 (clamped, like addFrequency does), but next_date is '
            '$actualNext — it skipped February into March entirely',
      );
    },
  );

  testWidgets(
    '5.2.3 yearly recurrence on Feb 29 next falls on Feb 28',
    (tester) async {
      // Same root cause as 5.2.2, applied to the yearly case.
      final catId = categoryId(bridge, 'expense', 'Insurance');
      final date = DateTime.utc(2028, 2, 29); // 2028 is a leap year
      bridge.json(
        'createTransaction',
        body: recurringPayload(
          name: 'Leap Day Policy',
          type: 'expense',
          currency: 'USD',
          date: date,
          freq: 'yearly',
          categoryId: catId,
          amount: '300.00',
        ),
      );

      final tpl = findByName(bridge.json('listRecurrences'), 'Leap Day Policy');
      final actualNext = DateTime.parse(tpl['next_date'] as String).toUtc();

      final sensibleNext = DateTime.utc(2029, 2, 28); // 2029 is not a leap year
      expect(
        actualNext.year == sensibleNext.year &&
            actualNext.month == sensibleNext.month &&
            actualNext.day == sensibleNext.day,
        isTrue,
        reason:
            'BUG: yearly recurrence anchored on Feb 29 should next fall on '
            'Feb 28 2029 (clamped), but next_date is $actualNext — it '
            'skipped into March',
      );
    },
  );

  testWidgets(
    '5.2.4 timeline stops at the recurrence end_date',
    (tester) async {
      // GetActiveRecurrenceTemplatesForProfile only excludes a template
      // whose *whole* end_date already elapsed before the window
      // (internal/transactions/repository/recurrence_repository.go:73-80).
      // Inside GetRecurrenceTimeline's per-occurrence projection loop
      // (internal/transactions/service/transaction_service.go:401-454),
      // nothing ever compares a projected date against tpl.EndDate — so an
      // end-dated recurrence whose end_date falls inside the 30-day window
      // still yields occurrences after it ended.
      final catId = categoryId(bridge, 'expense', 'Debt');
      final date = DateTime.now().toUtc();
      final endDate = date.add(const Duration(days: 10));
      bridge.json(
        'createTransaction',
        body: recurringPayload(
          name: 'Short Loan',
          type: 'expense',
          currency: 'USD',
          date: date,
          freq: 'weekly',
          categoryId: catId,
          amount: '25.00',
          hasEndDate: true,
          endDate: endDate,
          totalAmount: '999.00',
          paidPreviously: '0.00',
        ),
      );

      final occurrences = allByName(
        bridge.json('recurrenceTimeline'),
        'Short Loan',
      );
      expect(occurrences, isNotEmpty);
      final pastEndDate = occurrences
          .map((o) => DateTime.parse(o['date'] as String))
          .where((d) => d.isAfter(endDate))
          .toList();
      expect(
        pastEndDate,
        isEmpty,
        reason:
            'BUG: timeline returned ${pastEndDate.length} occurrence(s) after '
            'end_date ($endDate): $pastEndDate',
      );
    },
  );

  // ── 5.3 Delete recurrence: confirm / cancel; effect on linked transactions ──

  testWidgets('5.3.1 delete recurrence — Cancel keeps the recurrence', (
    tester,
  ) async {
    final catId = categoryId(bridge, 'expense', 'Food');
    bridge.json(
      'createTransaction',
      body: recurringPayload(
        name: 'Cancel Me Not',
        type: 'expense',
        currency: 'USD',
        date: DateTime.now().toUtc(),
        freq: 'weekly',
        categoryId: catId,
        amount: '10.00',
      ),
    );

    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(themeMode: ThemeMode.light, path: '/profile/recurrences'),
    );
    await settle(tester);
    expect(find.text('Cancel Me Not'), findsOneWidget);

    await tester.tap(find.byTooltip('Payment actions'));
    await settle(tester);
    await tester.tap(find.text('Delete recurring payment'));
    await settle(tester);
    expect(find.text('Delete recurring transaction?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Cancel Me Not'), findsOneWidget);
    expect(bridge.callCount('deleteRecurrence'), 0);
    expect(
      findByName(bridge.json('listRecurrences'), 'Cancel Me Not'),
      isNotNull,
    );
  });

  testWidgets(
    '5.3.2 delete recurrence — Confirm removes it from the list and DB',
    (tester) async {
      final catId = categoryId(bridge, 'expense', 'Food');
      bridge.json(
        'createTransaction',
        body: recurringPayload(
          name: 'Delete Me',
          type: 'expense',
          currency: 'USD',
          date: DateTime.now().toUtc(),
          freq: 'weekly',
          categoryId: catId,
          amount: '10.00',
        ),
      );
      final tplId =
          (findByName(bridge.json('listRecurrences'), 'Delete Me')['id'] as num)
              .toInt();

      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/profile/recurrences'),
      );
      await settle(tester);
      expect(find.text('Delete Me'), findsOneWidget);

      await tester.tap(find.byTooltip('Payment actions'));
      await settle(tester);
      await tester.tap(find.text('Delete recurring payment'));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(bridge.callCount('deleteRecurrence'), 1);
      final deleteCall = bridge.calls.lastWhere(
        (c) => c.method == 'deleteRecurrence',
      );
      expect(deleteCall.arguments, containsPair('id', tplId));

      // Per mobilebridge/API.md's DeleteRecurrence contract, this must succeed
      // and the row must disappear from both the UI and the DB.
      expect(
        find.text('Delete Me'),
        findsNothing,
        reason:
            'row should be gone from the list after a confirmed delete '
            '(if this fails, deleteRecurrence likely threw — see 5.3.3 for '
            'the FK root cause)',
      );
      expect(allByName(bridge.json('listRecurrences'), 'Delete Me'), isEmpty);
    },
  );

  testWidgets(
    '5.3.3 delete recurrence — effect on the already-booked linked transaction',
    (tester) async {
      // CreateTransaction with is_recurrent always books a first
      // transaction FK'd to the new template in the same call
      // (internal/transactions/service/transaction_service.go:39-100), so
      // *every* recurrence has at least one linked transaction by
      // construction. mobilebridge/API.md documents DeleteRecurrence as leaving
      // that transaction in place with a now-dangling
      // recurrence_template_id. Transaction.RecurrenceTemplate has no
      // `constraint:OnDelete:...` tag (internal/models/transaction.go:24-25)
      // and FKs are migrated+enforced
      // (internal/db/db.go:38, DisableForeignKeyConstraintWhenMigrating:
      // false, `_foreign_keys=on`), so SQLite's default NO ACTION FK may
      // instead reject the delete outright — directly contradicting the
      // documented behavior. This leaf observes which actually happens.
      final catId = categoryId(bridge, 'expense', 'Food');
      bridge.json(
        'createTransaction',
        body: recurringPayload(
          name: 'Linked Recurrence',
          type: 'expense',
          currency: 'USD',
          date: DateTime.now().toUtc(),
          freq: 'weekly',
          categoryId: catId,
          amount: '10.00',
        ),
      );
      final tplId =
          (findByName(bridge.json('listRecurrences'), 'Linked Recurrence')['id']
                  as num)
              .toInt();
      final linkedTxn = findByName(
        (bridge.json('listTransactions', body: {})
            as Map<String, dynamic>)['results'],
        'Linked Recurrence',
      );
      expect((linkedTxn['recurrence_template_id'] as num).toInt(), tplId);

      Object? deleteError;
      try {
        bridge.json('deleteRecurrence', id: tplId);
      } catch (e) {
        deleteError = e;
      }

      if (deleteError != null) {
        // Confirms the FK-constraint-blocks-delete hypothesis: the
        // documented "dangling FK" behavior is unreachable for any
        // recurrence that has ever booked a transaction — i.e. all of them.
        expect(
          allByName(bridge.json('listRecurrences'), 'Linked Recurrence'),
          isNotEmpty,
          reason:
              'delete threw ($deleteError) — recurrence should still be there',
        );
      } else {
        // Documented behavior: template gone, transaction stays.
        expect(
          allByName(bridge.json('listRecurrences'), 'Linked Recurrence'),
          isEmpty,
        );
        final stillThere = findByName(
          (bridge.json('listTransactions', body: {})
              as Map<String, dynamic>)['results'],
          'Linked Recurrence',
        );
        expect(stillThere['id'], linkedTxn['id']);
      }
      // The one thing that must never happen either way: silently losing
      // the booked transaction.
      final txnAfter = allByName(
        (bridge.json('listTransactions', body: {})
            as Map<String, dynamic>)['results'],
        'Linked Recurrence',
      );
      expect(
        txnAfter,
        isNotEmpty,
        reason: 'the booked transaction must never disappear',
      );
    },
  );

  testWidgets(
    '5.4.2 a payment bigger than what is left to pay is refused',
    (tester) async {
      // Only 10.00 is left on this loan, so a 20.00 installment is refused
      // instead of being saved in full with a negative balance.
      final catId = categoryId(bridge, 'expense', 'Debt');
      final date = DateTime.now().toUtc();
      expect(
        () => bridge.json(
          'createTransaction',
          body: recurringPayload(
            name: 'Almost Paid Off Loan',
            type: 'expense',
            currency: 'USD',
            date: date,
            freq: 'monthly',
            categoryId: catId,
            amount: '20.00',
            hasEndDate: true,
            endDate: date.add(const Duration(days: 60)),
            totalAmount: '100.00',
            paidPreviously: '90.00',
          ),
        ),
        throwsA(anything),
      );
      expect(bridge.json('listRecurrences'), isEmpty);
    },
  );
}
