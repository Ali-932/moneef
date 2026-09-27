import 'package:decimal/decimal.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/analysis.dart';
import 'package:mobile_app/models/recurrence_occurrence.dart';
import 'package:mobile_app/theme.dart';
import 'package:mobile_app/utils/date_range.dart';
import 'package:mobile_app/widgets/insights/insights_widgets.dart';

import '../screenshots/harness.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });

  Future<void> showChart(
    WidgetTester tester,
    Widget chart,
    Brightness brightness,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: chart,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder selectedText(String text) => find.descendant(
    of: find.byKey(const ValueKey('spending-selection')),
    matching: find.text(text),
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'trend hover and hold scrub include zero spending ($brightness)',
      (tester) async {
        final days = [
          AmountPerDay(date: DateTime.utc(2026, 9, 24), amount: Decimal.zero),
          AmountPerDay(
            date: DateTime.utc(2026, 9, 25),
            amount: Decimal.fromInt(10),
          ),
          AmountPerDay(
            date: DateTime.utc(2026, 9, 26),
            amount: Decimal.fromInt(640000),
          ),
        ];
        await showChart(
          tester,
          TrendChart(
            data: aggregateAmountPerDay(days, Aggregation.daily),
            previousAverage: Decimal.fromInt(20),
            currency: 'IQD',
            previousLabel: 'Aug 2026',
          ),
          brightness,
        );
        expect(selectedText('Peak · Sep 26, 2026'), findsOneWidget);
        final rect = tester.getRect(
          find.byKey(const ValueKey('spending-trend-plot')),
        );
        Offset point(int index) =>
            Offset(rect.left + rect.width / 3 * (index + .5), rect.top + 50);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(point(0));
        await tester.pumpAndSettle();
        expect(selectedText('Sep 24, 2026'), findsOneWidget);
        expect(selectedText('IQD 0.00'), findsOneWidget);
        await mouse.moveTo(point(1));
        await tester.pumpAndSettle();
        expect(selectedText('Sep 25, 2026'), findsOneWidget);
        expect(selectedText('IQD 10.00'), findsOneWidget);
        await mouse.removePointer();
        await tester.pumpAndSettle();

        final hold = await tester.startGesture(point(1));
        await tester.pump(
          kLongPressTimeout + const Duration(milliseconds: 100),
        );
        expect(selectedText('IQD 10.00'), findsOneWidget);
        await hold.moveTo(point(2));
        await tester.pumpAndSettle();
        expect(selectedText('Sep 26, 2026'), findsOneWidget);
        expect(selectedText('IQD 640,000.00'), findsOneWidget);
        await hold.moveTo(point(0));
        await tester.pumpAndSettle();
        expect(selectedText('IQD 0.00'), findsOneWidget);
        await hold.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'heatmap shows calendar months and hover/hold amounts ($brightness)',
      (tester) async {
        final days = List.generate(
          8,
          (i) => AmountPerDay(
            date: DateTime.utc(2026, 9, 24 + i),
            amount: Decimal.fromInt(
              i == 2
                  ? 640000
                  : i == 1
                  ? 12345
                  : 0,
            ),
          ),
        );
        await showChart(
          tester,
          SpendingHeatmap(days: days, currency: 'IQD'),
          brightness,
        );
        expect(find.text('September 2026'), findsOneWidget);
        expect(find.text('October 2026'), findsOneWidget);
        expect(find.text('26'), findsOneWidget);
        Finder day(String date) => find.byKey(ValueKey('spending-day-$date'));
        // Friday and Saturday occupy their calendar columns, not the first two cells.
        expect(
          tester.getCenter(day('2026-09-25')).dx,
          lessThan(tester.getCenter(day('2026-09-26')).dx),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(day('2026-10-01')));
        await tester.pumpAndSettle();
        expect(selectedText('Oct 1, 2026'), findsOneWidget);
        expect(selectedText('IQD 0.00'), findsOneWidget);
        await mouse.removePointer();

        final hold = await tester.startGesture(
          tester.getCenter(day('2026-09-25')),
        );
        await tester.pump(
          kLongPressTimeout + const Duration(milliseconds: 100),
        );
        expect(selectedText('IQD 12,345.00'), findsOneWidget);
        await hold.moveTo(tester.getCenter(day('2026-09-26')));
        await tester.pumpAndSettle();
        expect(selectedText('Sep 26, 2026'), findsOneWidget);
        expect(selectedText('IQD 640,000.00'), findsOneWidget);
        await hold.moveTo(tester.getCenter(day('2026-09-27')));
        await tester.pumpAndSettle();
        expect(selectedText('Sep 27, 2026'), findsOneWidget);
        expect(selectedText('IQD 0.00'), findsOneWidget);
        await hold.up();
        await tester.pumpAndSettle();
        await tester.tap(day('2026-09-26'));
        await tester.pumpAndSettle();
        expect(selectedText('IQD 640,000.00'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Coming up renders backend currency and signed amounts ($brightness)',
      (tester) async {
        RecurrenceOccurrence occurrence(
          String type,
          String currency,
          String amount,
        ) => RecurrenceOccurrence.fromJson({
          'id': 1,
          'name': 'Upcoming payment',
          'type': type,
          'amount': amount,
          'currency': currency,
          'date': '2026-10-01T00:00:00Z',
        });
        await showChart(
          tester,
          RecurringSection(
            next: const [],
            timeline: [
              occurrence('expense', 'IQD', '640000'),
              occurrence('income', 'USD', '1500'),
            ],
            currency: 'USD',
          ),
          brightness,
        );
        expect(find.text('-IQD 640,000.00'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView), const Offset(-300, 0));
        await tester.pumpAndSettle();
        expect(find.text(r'+$1,500.00'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('weekly and monthly details identify the actual date range', () {
    final days = [
      AmountPerDay(
        date: DateTime.utc(2026, 9, 24),
        amount: Decimal.fromInt(10),
      ),
      AmountPerDay(
        date: DateTime.utc(2026, 9, 25),
        amount: Decimal.fromInt(20),
      ),
    ];
    expect(
      aggregateAmountPerDay(days, Aggregation.weekly).single.detailLabel,
      'Sep 24 – Sep 25, 2026',
    );
    expect(
      aggregateAmountPerDay(days, Aggregation.monthly).single.detailLabel,
      'September 2026',
    );
  });
}
