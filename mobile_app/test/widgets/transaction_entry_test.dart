import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/analysis.dart';
import 'package:mobile_app/models/dashboard.dart';
import 'package:mobile_app/screens/insights_screen.dart';
import 'package:mobile_app/state/insights_providers.dart';
import 'package:mobile_app/state/providers.dart';
import 'package:mobile_app/utils/format.dart';
import 'package:mobile_app/widgets/common/picker_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/harness.dart';
import '../support/mutable_native_api.dart';

Finder field(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('editing prefilled grouped amounts preserves exact saved money', (
    tester,
  ) async {
    final api = MutableNativeApi()..install();
    final transaction = api.fixtures.transactions.first;
    (transaction['TransactionCategory'] as List).first['amount'] = '640000.75';
    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(
        themeMode: ThemeMode.light,
        path: '/transactions/${transaction['id']}/edit',
      ),
    );
    await settle(tester);
    expect(find.text('640,000.75'), findsOneWidget);
    expect(find.text(r'$640,000.75'), findsOneWidget);
    await tester.enterText(field('0.00').first, '740,000.85');
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await settle(tester);
    final split =
        (api.transactionPayloads.single['transaction_categories'] as List)
            .single;
    expect(split['amount'], '740000.85');
    expect(api.calls['updateTransaction'], 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'create a category inside the picker and save grouped money; both tabs update',
    (tester) async {
      final api = MutableNativeApi()..install();
      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/insights'),
      );
      await settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(InsightsScreen)),
      );
      final oldAnalysis = await container.read(analysisProvider.future);
      await tester.tap(find.text('Home'));
      await settle(tester);
      await tester.tap(find.byTooltip('Add transaction'));
      await settle(tester);

      await tester.enterText(field('e.g. Morning latte'), 'Workshop equipment');
      await tester.enterText(field('0.00').first, '640000.75');
      await settle(tester);
      expect(find.text('640,000.75'), findsOneWidget);
      expect(find.text(r'$640,000.75'), findsOneWidget);
      await tester.tap(find.text('Select category'));
      await settle(tester);
      await tester.enterText(field('Search...'), 'Equipment');
      await settle(tester);
      expect(find.text('No results'), findsOneWidget);
      await tester.tap(find.text('Add new category'));
      await settle(tester);
      expect(find.text('New category'), findsOneWidget);
      await tester.enterText(field('Name'), 'Equipment');
      await tester.ensureVisible(find.text('Create category'));
      await tester.tap(find.text('Create category'));
      await settle(tester);

      expect(find.text('Equipment'), findsOneWidget);
      expect(find.text('640,000.75'), findsOneWidget);
      expect(find.text('Workshop equipment'), findsOneWidget);
      expect(api.fixtures.categories.last['type'], 'expense');
      await tester.tap(find.widgetWithText(FilledButton, 'Add transaction'));
      await settle(tester);
      expect(api.transactionPayloads, hasLength(1));
      final split =
          (api.transactionPayloads.single['transaction_categories'] as List)
              .single;
      expect(split['amount'], '640000.75');
      expect(split['category_id'], api.fixtures.categories.last['id']);
      final dashboard = DashboardSummary.fromJson(api.fixtures.dashboard());
      expect(await container.read(dashboardProvider.future), dashboard);
      expect(
        find.text(formatMoney(dashboard.totalExpense, 'USD')),
        findsWidgets,
      );

      await tester.tap(find.text('Insights').last);
      await settle(tester);
      final analysis = await container.read(analysisProvider.future);
      expect(analysis, AnalysisCharts.fromJson(api.fixtures.analysis()));
      expect(analysis.total, isNot(oldAnalysis.total));
      expect(find.text(formatMoney(analysis.total, 'USD')), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'income category creation keeps the income type and can be cancelled or retried',
    (tester) async {
      final api = MutableNativeApi()..install();
      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.dark, path: '/add', textScale: 1.3),
      );
      await settle(tester);
      await tester.tap(find.text('Income'));
      await settle(tester);
      await tester.enterText(field('e.g. Morning latte'), 'Commission');
      await tester.enterText(field('0.00').first, '640000');
      await tester.tap(find.text('Select category'));
      await settle(tester);
      await tester.tap(find.text('Salary'));
      await settle(tester);
      await tester.tap(find.text('Salary'));
      await settle(tester);
      await tester.tap(find.text('Add new category'));
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('640,000'), findsOneWidget);
      await tester.tap(find.text('Salary'));
      await settle(tester);
      await tester.tap(find.text('Add new category'));
      await settle(tester);
      expect(
        tester.widget<PickerField>(find.byType(PickerField).last).enabled,
        isFalse,
      );
      await tester.enterText(field('Name'), 'Commission income');
      api.failCategory = true;
      await tester.ensureVisible(find.text('Create category'));
      await tester.tap(find.text('Create category'));
      await settle(tester);
      expect(find.text('New category'), findsOneWidget);
      expect(find.text('Commission income'), findsOneWidget);
      api.failCategory = false;
      await tester.tap(find.text('Create category'));
      await settle(tester);
      expect(api.fixtures.categories.last['type'], 'income');
      expect(find.text('Commission income'), findsOneWidget);
      expect(find.text('640,000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
