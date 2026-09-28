// Screenshot harness: renders real screens (real theme, real router, real
// widgets) against a mocked `moneef/api` bridge so design review has actual
// pixels to look at without the Go .aar, which crashes on this machine's
// x86_64 emulator. See `docs` note in the PR / task for the run command.
//
// Regenerate: cd mobile_app && flutter test test/screenshots --update-goldens --tags screenshots
@Tags(['screenshots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';
import 'harness.dart';
import 'mock_native_api.dart';

const _apiChannel = MethodChannel('moneef/api');

void main() {
  late final Fixtures fixtures;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // settingsProvider fire-and-forgets a SharedPreferences write on every
    // load; without a mock store that throws MissingPluginException and
    // fails the test via an unhandled async error.
    SharedPreferences.setMockInitialValues({});
    await loadRealFonts();
    fixtures = Fixtures();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    required String path,
    required ThemeMode themeMode,
    double textScale = 1.0,
    bool emptyData = false,
  }) async {
    installNativeApiMock(
      path.startsWith('/profile/recurrences') ? Fixtures.recurringPaymentsReview() : fixtures,
      emptyData: emptyData,
    );
    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(themeMode: themeMode, path: path, textScale: textScale),
    );
    await settle(tester);
  }

  Future<void> golden(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  group(
    'screenshots',
    () {
      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_apiChannel, null);
      });

      for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
        final suffix = themeMode == ThemeMode.light ? 'light' : 'dark';

        testWidgets('home ($suffix)', (tester) async {
          await pumpApp(tester, path: '/home', themeMode: themeMode);
          await golden(tester, 'home_$suffix');
        });

        testWidgets('transactions ($suffix)', (tester) async {
          await pumpApp(tester, path: '/transactions', themeMode: themeMode);
          await golden(tester, 'transactions_$suffix');
        });

        testWidgets('transactions filter sheet ($suffix)', (tester) async {
          await pumpApp(tester, path: '/transactions', themeMode: themeMode);
          await tester.tap(find.byIcon(Icons.tune));
          await settle(tester, frames: 20);
          await golden(tester, 'transactions_filter_$suffix');
        });

        testWidgets('transaction detail, multi-category ($suffix)', (
          tester,
        ) async {
          await pumpApp(
            tester,
            path: '/transactions/${fixtures.multiCategoryTransactionId}',
            themeMode: themeMode,
          );
          await golden(tester, 'transaction_detail_$suffix');
        });

        testWidgets('add transaction, top ($suffix)', (tester) async {
          await pumpApp(tester, path: '/add', themeMode: themeMode);
          await golden(tester, 'add_transaction_$suffix');
        });

        testWidgets('discard confirmation ($suffix)', (tester) async {
          await pumpApp(tester, path: '/add', themeMode: themeMode);
          await tester.enterText(
            find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == 'e.g. Morning latte',
            ),
            'Weekly groceries',
          );
          await settle(tester);
          await tester.pageBack();
          await settle(tester);
          await golden(tester, 'discard_changes_$suffix');
          await tester.tap(find.text('Keep editing'));
          await settle(tester);
          expect(find.text('Weekly groceries'), findsOneWidget);
          await tester.pageBack();
          await settle(tester);
          await tester.tap(find.text('Discard changes'));
          await settle(tester);
          expect(find.text('Overview'), findsOneWidget);
          expect(find.text('Weekly groceries'), findsNothing);
        });

        testWidgets('transaction date picker ($suffix)', (tester) async {
          await pumpApp(tester, path: '/add', themeMode: themeMode);
          await tester.tap(find.byIcon(Icons.calendar_today_outlined));
          await settle(tester);
          await golden(tester, 'date_picker_$suffix');
          await tester.tap(find.byIcon(Icons.edit_calendar_outlined));
          await settle(tester);
          await golden(tester, 'date_picker_input_$suffix');
          await tester.tap(find.text('Cancel'));
          await settle(tester);
          expect(find.byType(DatePickerDialog), findsNothing);
        });

        testWidgets('activity date range picker ($suffix)', (tester) async {
          await pumpApp(tester, path: '/transactions', themeMode: themeMode);
          await tester.tap(find.byIcon(Icons.calendar_today_outlined));
          await settle(tester);
          await golden(tester, 'date_range_picker_$suffix');
        });

        testWidgets(
          'transaction category picker and inline creation ($suffix)',
          (tester) async {
            await pumpApp(tester, path: '/add', themeMode: themeMode);
            await tester.enterText(
              find
                  .byWidgetPredicate(
                    (w) => w is TextField && w.decoration?.hintText == '0.00',
                  )
                  .first,
              '640000',
            );
            await tester.tap(find.text('Select category'));
            await settle(tester);
            await golden(tester, 'transaction_category_picker_$suffix');
            await tester.tap(find.text('Add new category'));
            await settle(tester);
            await golden(tester, 'transaction_category_editor_$suffix');
          },
        );

        testWidgets(
          'add transaction, scrolled + 2nd category + recurrence ($suffix)',
          (tester) async {
            await pumpApp(tester, path: '/add', themeMode: themeMode);

            await tester.tap(find.text('Add category split'));
            await settle(tester, frames: 5);

            // First switch: "Recurring payment". Reveals a 2nd switch.
            await tester.scrollUntilVisible(
              find.byType(Switch),
              250,
              scrollable: find.byType(Scrollable).first,
            );
            await settle(tester, frames: 5);
            await tester.tap(find.byType(Switch).first, warnIfMissed: false);
            await settle(tester, frames: 5);
            // 2nd switch: "Has end date?" — expands the plan-amount fields.
            // It's below the fold once revealed, so scroll it into view
            // first or the synthetic tap lands past the viewport and misses.
            await tester.ensureVisible(find.byType(Switch).last);
            await settle(tester, frames: 5);
            await tester.tap(find.byType(Switch).last);
            await settle(tester, frames: 10);

            for (var i = 0; i < 6; i++) {
              await tester.drag(
                find.byType(ListView).first,
                const Offset(0, -700),
              );
              await tester.pump();
            }
            await settle(tester, frames: 10);
            await golden(tester, 'add_transaction_scrolled_$suffix');
          },
        );

        testWidgets('insights overview ($suffix)', (tester) async {
          await pumpApp(tester, path: '/insights', themeMode: themeMode);
          await golden(tester, 'insights_overview_$suffix');
        });

        testWidgets('insights analysis ($suffix)', (tester) async {
          await pumpApp(tester, path: '/insights', themeMode: themeMode);
          await tester.tap(find.text('Analysis'));
          await settle(tester, frames: 20);
          await golden(tester, 'insights_analysis_$suffix');
        });

        testWidgets('insights patterns ($suffix)', (tester) async {
          await pumpApp(tester, path: '/insights', themeMode: themeMode);
          await tester.tap(find.text('Patterns'));
          await settle(tester, frames: 20);
          await golden(tester, 'insights_patterns_$suffix');
        });

        testWidgets('profile, top ($suffix)', (tester) async {
          await pumpApp(tester, path: '/profile', themeMode: themeMode);
          await golden(tester, 'profile_$suffix');
        });

        testWidgets('profile, scrolled ($suffix)', (tester) async {
          await pumpApp(tester, path: '/profile', themeMode: themeMode);
          await tester.drag(find.byType(ListView).first, const Offset(0, -700));
          await settle(tester, frames: 10);
          await golden(tester, 'profile_scrolled_$suffix');
        });

        testWidgets('categories ($suffix)', (tester) async {
          await pumpApp(
            tester,
            path: '/profile/categories',
            themeMode: themeMode,
          );
          await golden(tester, 'categories_$suffix');
        });

        testWidgets('recurrences ($suffix)', (tester) async {
          await pumpApp(
            tester,
            path: '/profile/recurrences',
            themeMode: themeMode,
          );
          await golden(tester, 'recurrences_$suffix');
        });

        testWidgets('recurrence edit ($suffix)', (tester) async {
          await pumpApp(tester, path: '/profile/recurrences/2/edit', themeMode: themeMode);
          await golden(tester, 'recurrence_edit_$suffix');
          await tester.drag(find.byType(ListView).first, const Offset(0, -560));
          await settle(tester);
          await golden(tester, 'recurrence_edit_details_$suffix');
        });

        testWidgets('recurrences narrow, large text ($suffix)', (tester) async {
          await pumpApp(
            tester,
            path: '/profile/recurrences',
            themeMode: themeMode,
            textScale: 1.3,
          );
          tester.view.physicalSize = const Size(360, 800) * goldenDevicePixelRatio;
          await settle(tester);
          expect(tester.takeException(), isNull);
          await golden(tester, 'recurrences_narrow_$suffix');
        });
      }

      // ── textScaler 1.3 (light only) ─────────────────────────────────
      testWidgets('discard confirmation and calendar at 200% text', (
        tester,
      ) async {
        await pumpApp(
          tester,
          path: '/add',
          themeMode: ThemeMode.light,
          textScale: 2,
        );
        await tester.enterText(
          find.byWidgetPredicate(
            (w) =>
                w is TextField &&
                w.decoration?.hintText == 'e.g. Morning latte',
          ),
          'Weekly groceries',
        );
        await settle(tester);
        await tester.pageBack();
        await settle(tester);
        await golden(tester, 'discard_changes_textscale_light');
        await tester.tap(find.text('Keep editing'));
        await settle(tester);
        await tester.ensureVisible(find.byIcon(Icons.calendar_today_outlined));
        await tester.tap(find.byIcon(Icons.calendar_today_outlined));
        await settle(tester);
        await golden(tester, 'date_picker_textscale_light');
      });

      testWidgets('home, textScale 1.3', (tester) async {
        await pumpApp(
          tester,
          path: '/home',
          themeMode: ThemeMode.light,
          textScale: 1.3,
        );
        await golden(tester, 'home_textscale_light');
      });

      testWidgets('add transaction, textScale 1.3', (tester) async {
        await pumpApp(
          tester,
          path: '/add',
          themeMode: ThemeMode.light,
          textScale: 1.3,
        );
        await golden(tester, 'add_transaction_textscale_light');
      });

      testWidgets('profile, textScale 1.3', (tester) async {
        await pumpApp(
          tester,
          path: '/profile',
          themeMode: ThemeMode.light,
          textScale: 1.3,
        );
        await golden(tester, 'profile_textscale_light');
      });

      // ── empty states (light only) ────────────────────────────────────
      testWidgets('home, empty', (tester) async {
        await pumpApp(
          tester,
          path: '/home',
          themeMode: ThemeMode.light,
          emptyData: true,
        );
        await golden(tester, 'home_empty_light');
      });

      testWidgets('transactions, empty', (tester) async {
        await pumpApp(
          tester,
          path: '/transactions',
          themeMode: ThemeMode.light,
          emptyData: true,
        );
        await golden(tester, 'transactions_empty_light');
      });
    },
    skip: autoUpdateGoldenFiles
        ? false
        : 'Screenshot goldens are gitignored and not regenerated by default. '
              'Run: flutter test test/screenshots --update-goldens --tags screenshots',
  );
}
