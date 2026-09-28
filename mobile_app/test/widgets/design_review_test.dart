import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/analysis.dart';
import 'package:mobile_app/theme.dart';
import 'package:mobile_app/widgets/insights/insights_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screenshots/fixtures.dart';
import '../screenshots/harness.dart';
import '../screenshots/mock_native_api.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await loadRealFonts();
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final path in [
      '/home',
      '/transactions',
      '/insights',
      '/profile',
      '/add',
      '/profile/categories',
      '/profile/recurrences',
      '/profile/recurrences/2/edit',
      '/transactions/4',
    ]) {
      testWidgets('$path fits a narrow phone at large text in $mode', (
        tester,
      ) async {
        installNativeApiMock(
          path.startsWith('/profile/recurrences')
              ? Fixtures.recurringPaymentsReview()
              : Fixtures(),
        );
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          appUnderTest(themeMode: mode, path: path, textScale: 1.3),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        // Exercise the rest of each scrollable screen, including form options.
        final list = find.byType(ListView);
        if (list.evaluate().isNotEmpty) {
          for (var i = 0; i < 3; i++) {
            await tester.drag(list.first, const Offset(0, -480));
            await settle(tester, frames: 8);
            expect(tester.takeException(), isNull);
          }
        }
      });
    }
  }

  testWidgets(
    'category selection displays actual amount and percentage, then resets',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(
            body: SizedBox(
              width: 380,
              child: CategoryDonut(
                categories: [
                  CategorySummary(
                    categoryId: 1,
                    categoryName: 'Food',
                    totalAmount: Decimal.fromInt(30),
                    percentage: Decimal.fromInt(30),
                    color: '#6C5CE7',
                  ),
                  CategorySummary(
                    categoryId: 2,
                    categoryName: 'Travel',
                    totalAmount: Decimal.fromInt(70),
                    percentage: Decimal.fromInt(70),
                    color: '#0984E3',
                  ),
                ],
                total: Decimal.fromInt(100),
                currency: 'USD',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(r'$100.00'), findsOneWidget);
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      expect(find.text('30.0% of spending'), findsOneWidget);
      expect(find.text(r'$30.00'), findsNWidgets(2));
      await tester.tap(find.text('Food').last);
      await tester.pumpAndSettle();
      expect(find.text(r'$100.00'), findsOneWidget);
    },
  );

  testWidgets(
    'profile editor opens inline and closes without losing the screen',
    (tester) async {
      installNativeApiMock(Fixtures());
      setGoldenSurface(tester);
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/profile'),
      );
      await settle(tester);
      expect(find.widgetWithText(TextField, 'First name'), findsNothing);
      await tester.tap(find.byTooltip('Edit profile'));
      await settle(tester);
      expect(find.widgetWithText(TextField, 'First name'), findsOneWidget);
      await tester.tap(find.byTooltip('Close profile editor'));
      await settle(tester);
      expect(find.widgetWithText(TextField, 'First name'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'category amounts update the transaction total with reduced motion',
    (tester) async {
      installNativeApiMock(Fixtures());
      setGoldenSurface(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        appUnderTest(themeMode: ThemeMode.light, path: '/add'),
      );
      await settle(tester);
      final amount = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '0.00',
      );
      await tester.enterText(amount.first, '42.75');
      await settle(tester, frames: 6);
      expect(find.text(r'$42.75'), findsOneWidget);
      await tester.enterText(amount.first, '43.75');
      await settle(tester, frames: 6);
      expect(find.text(r'$43.75'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('text and action palette meets AA in both themes', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance();
      final y = b.computeLuminance();
      return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
    }

    for (final p in [AppColors.light, AppColors.dark]) {
      for (final bg in [p.surface, p.card, p.tile]) {
        for (final fg in [
          p.ink,
          p.muted,
          p.primary,
          p.positiveText,
          p.negativeText,
        ]) {
          expect(
            contrast(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$fg on $bg',
          );
        }
      }
      expect(contrast(Colors.white, p.accentFill), greaterThanOrEqualTo(4.5));
      expect(contrast(p.primary, p.primarySoft), greaterThanOrEqualTo(4.5));
    }
  });
}
