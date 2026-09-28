@Tags(['screenshots'])
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/widgets/insights/insights_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';
import 'harness.dart';
import 'mock_native_api.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final suffix = mode == ThemeMode.light ? 'light' : 'dark';
    for (final heatmap in [false, true]) {
      testWidgets('analysis ${heatmap ? 'heatmap' : 'trend'} inspection $suffix', (
        tester,
      ) async {
        final fixtures = Fixtures();
        installNativeApiMock(fixtures);
        setGoldenSurface(tester);
        await tester.pumpWidget(
          appUnderTest(themeMode: mode, path: '/insights'),
        );
        await settle(tester);
        await tester.tap(find.text('Analysis'));
        await settle(tester);
        await tester.scrollUntilVisible(
          find.text('Spending Over Time'),
          250,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .first,
        );
        await settle(tester);
        if (heatmap) {
          await tester.tap(find.text('Heatmap'));
          await settle(tester);
        }
        await Scrollable.ensureVisible(
          tester.element(find.text('Spending Over Time')),
          alignment: 0.05,
        );
        await settle(tester);
        final target = heatmap
            ? find.byKey(
                ValueKey(
                  'spending-day-${DateTime.utc(fixtures.now.year, fixtures.now.month, fixtures.now.day.clamp(1, 12)).toIso8601String().substring(0, 10)}',
                ),
              )
            : find.byKey(const ValueKey('spending-trend-plot'));
        final gesture = await tester.startGesture(tester.getCenter(target));
        await tester.pump(
          kLongPressTimeout + const Duration(milliseconds: 100),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/insights_${heatmap ? 'heatmap' : 'trend'}_selected_$suffix.png',
          ),
        );
        await gesture.up();
      });
    }

    testWidgets('analysis fits narrow phone with large text $suffix', (
      tester,
    ) async {
      installNativeApiMock(Fixtures());
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        appUnderTest(themeMode: mode, path: '/insights', textScale: 1.3),
      );
      await settle(tester);
      await tester.tap(find.text('Analysis'));
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text('Heatmap'),
        250,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Heatmap'));
      await settle(tester);
      await tester.scrollUntilVisible(
        find.byType(SpendingHeatmap),
        150,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
