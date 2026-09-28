import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app/screens/recurrences_screen.dart';
import 'package:mobile_app/state/insights_providers.dart';
import 'package:mobile_app/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/harness.dart';
import 'real_bridge.dart';
import 'recurrences_e2e_test.dart' show categoryId, recurringPayload;

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

Future<void> changeDate(
  WidgetTester tester,
  String label,
  DateTime date,
) async {
  final trigger = find.byWidgetPredicate(
    (w) => w is InputDecorator && w.decoration.labelText == label,
  );
  await tester.ensureVisible(trigger);
  await tester.tap(trigger);
  await settle(tester);
  await tester.tap(find.byIcon(Icons.edit_calendar_outlined));
  await settle(tester);
  await tester.enterText(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.byType(TextField),
    ),
    DateFormat('MM/dd/yyyy').format(date),
  );
  await tester.tap(find.text('Use date'));
  await settle(tester);
}

void main() {
  final bridge = RealBridge.instance;
  late int id;
  Map<String, dynamic> stored() =>
      (bridge.json('listRecurrences') as List).single as Map<String, dynamic>;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bridge.resetWithProfile();
    bridge.install();
    bridge.json(
      'createTransaction',
      body: recurringPayload(
        name: 'Rent',
        type: 'expense',
        currency: 'IQD',
        date: DateTime.now().toUtc(),
        freq: 'monthly',
        categoryId: categoryId(bridge, 'expense', 'Food'),
        amount: '500000.00',
      ),
    );
    id = (stored()['id'] as num).toInt();
  });

  Future<void> open(WidgetTester tester, {bool throughList = false}) async {
    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(
        themeMode: ThemeMode.dark,
        path: throughList
            ? '/profile/recurrences'
            : '/profile/recurrences/$id/edit',
      ),
    );
    await settle(tester);
    if (throughList) {
      await tester.tap(find.byTooltip('Payment actions'));
      await settle(tester);
      await tester.tap(find.text('Edit recurring payment'));
      await settle(tester);
    }
    expect(find.text('Edit recurring payment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'edit through list saves all schedule fields and refreshes Home and Insights',
    (tester) async {
      final original = stored();
      await open(tester, throughList: true);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).last),
      );
      final subscriptions = [
        container.listen(dashboardProvider, (_, _) {}),
        container.listen(analysisProvider, (_, _) {}),
        container.listen(recurrenceTimelineProvider, (_, _) {}),
      ];
      addTearDown(() {
        for (final sub in subscriptions) {
          sub.close();
        }
      });
      await settle(tester);
      final calls = {
        for (final method in ['dashboard', 'analysis', 'recurrenceTimeline'])
          method: bridge.callCount(method),
      };

      await tester.enterText(field('Name'), 'Updated rent');
      await tester.tap(find.text('Monthly'));
      await settle(tester);
      await tester.tap(find.text('Weekly'));
      await settle(tester);
      expect(tester.testTextInput.isVisible, isFalse);
      final next = DateTime.now().add(const Duration(days: 5));
      final end = next.add(const Duration(days: 60));
      await changeDate(tester, 'Next payment date', next);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Active'));
      await tester.tap(find.widgetWithText(SwitchListTile, 'Set an end date'));
      await settle(tester);
      await changeDate(tester, 'End date', end);
      await tester.ensureVisible(field('Merchant (optional)'));
      await tester.enterText(field('Merchant (optional)'), 'Landlord');
      await tester.ensureVisible(field('Notes (optional)'));
      await tester.enterText(field('Notes (optional)'), 'Paid on Fridays');
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(RecurrencesScreen), findsOneWidget);
      expect(find.text('Updated rent'), findsOneWidget);
      expect(find.text('Expense · Weekly · Paused'), findsOneWidget);
      expect(find.text('-IQD 500,000.00'), findsOneWidget);
      final after = stored();
      expect(after['name'], 'Updated rent');
      expect(after['frequency'], 'weekly');
      expect(after['is_active'], false);
      expect(after['has_end_date'], true);
      expect(after['merchant_name'], 'Landlord');
      expect(after['notes'], 'Paid on Fridays');
      expect(
        DateUtils.isSameDay(
          DateTime.parse(after['next_date'] as String).toLocal(),
          next,
        ),
        true,
      );
      expect(
        DateUtils.isSameDay(
          DateTime.parse(after['end_date'] as String).toLocal(),
          end,
        ),
        true,
      );
      for (final key in [
        'type',
        'currency_code',
        'next_payment_amount',
        'transaction_category',
      ]) {
        expect(after[key], original[key]);
      }
      final txs = bridge.json('listTransactions', body: {}) as Map;
      expect((txs['results'] as List).single['name'], 'Rent');
      for (final method in calls.keys) {
        expect(
          bridge.callCount(method),
          greaterThan(calls[method]!),
          reason: '$method was not refreshed',
        );
      }
      await tester.tap(find.byTooltip('Payment actions'));
      await settle(tester);
      await tester.tap(find.text('Edit recurring payment'));
      await settle(tester);
      expect(
        tester.widget<TextField>(field('Name')).controller!.text,
        'Updated rent',
      );
      expect(
        tester.widget<TextField>(field('Merchant (optional)')).controller!.text,
        'Landlord',
      );
      expect(
        tester.widget<TextField>(field('Notes (optional)')).controller!.text,
        'Paid on Fridays',
      );
    },
  );

  testWidgets('disabling end date and clearing optional details persists', (
    tester,
  ) async {
    final next = stored()['next_date'];
    bridge.json(
      'updateRecurrence',
      id: id,
      body: {
        'name': 'Rent',
        'frequency': 'monthly',
        'next_date': next,
        'has_end_date': true,
        'end_date': DateTime.now()
            .add(const Duration(days: 365))
            .toUtc()
            .toIso8601String(),
        'is_active': false,
        'merchant_name': 'Landlord',
        'notes': 'Old note',
      },
    );
    await open(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Active'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Set an end date'));
    await settle(tester);
    await tester.ensureVisible(field('Merchant (optional)'));
    await tester.enterText(field('Merchant (optional)'), '');
    await tester.ensureVisible(field('Notes (optional)'));
    await tester.enterText(field('Notes (optional)'), '');
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await settle(tester);
    final after = stored();
    expect(after['has_end_date'], false);
    expect(after['end_date'], isNull);
    expect(after['is_active'], true);
    expect(after['merchant_name'], '');
    expect(after['notes'], '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('discard confirmation protects unsaved recurrence edits', (
    tester,
  ) async {
    await open(tester, throughList: true);
    await tester.enterText(field('Name'), 'Do not save');
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await settle(tester);
    expect(
      tester.widget<TextField>(field('Name')).controller!.text,
      'Do not save',
    );
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.text('Discard changes'));
    await settle(tester);
    expect(find.byType(RecurrencesScreen), findsOneWidget);
    expect(stored()['name'], 'Rent');
    expect(bridge.callCount('updateRecurrence'), 0);
  });

  testWidgets('invalid name and end date never reach the database', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(field('Name'), '  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await settle(tester);
    expect(find.text('Enter a name'), findsOneWidget);
    await tester.enterText(field('Name'), 'Valid name');
    await tester.tap(find.widgetWithText(SwitchListTile, 'Set an end date'));
    await settle(tester);
    await changeDate(
      tester,
      'End date',
      DateTime.now().subtract(const Duration(days: 60)),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await settle(tester);
    expect(
      find.text('End date must be on or after the next payment'),
      findsOneWidget,
    );
    expect(bridge.callCount('updateRecurrence'), 0);
    expect(stored()['name'], 'Rent');
  });

  testWidgets('failed save keeps the draft available for retry', (
    tester,
  ) async {
    await open(tester, throughList: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('moneef/api'), (
          call,
        ) async {
          if (call.method == 'updateRecurrence') {
            throw PlatformException(
              code: 'MOBILE_ERROR',
              message: 'Could not save changes. Please try again.',
            );
          }
          return bridge.invoke(call.method, call.arguments as Map?);
        });
    await tester.enterText(field('Name'), 'Retry rent');
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await settle(tester);
    expect(
      find.text('Could not save changes. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(field('Name')).controller!.text,
      'Retry rent',
    );
    expect(stored()['name'], 'Rent');
    bridge.install();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await settle(tester);
    expect(stored()['name'], 'Retry rent');
    expect(find.byType(RecurrencesScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
