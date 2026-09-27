@Tags(['screenshots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/backups_screen.dart';
import 'package:mobile_app/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/backup_bridge.dart';
import '../support/mutable_native_api.dart';
import 'harness.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final name = mode == ThemeMode.light ? 'light' : 'dark';
    for (final scenario in [
      'welcome',
      'setup',
      'enabled',
      'failure',
      'restore',
    ]) {
      testWidgets('backups $scenario $name', (tester) async {
        MutableNativeApi().install();
        final bridge = BackupBridge()..install();
        if (scenario == 'enabled' || scenario == 'failure') {
          bridge.status.addAll({
            'enabled': true,
            'folderName': 'Internal storage / Documents/Moneef Backups',
            'lastBackup': '2026-09-26T09:30:00Z',
          });
          if (scenario == 'failure') {
            bridge.status['error'] =
                'Your data is saved in Moneef, but the backup could not be updated. Check the folder and try again.';
          }
        }
        setGoldenSurface(tester);
        if (scenario == 'welcome') {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: buildAppTheme(
                  mode == ThemeMode.light ? Brightness.light : Brightness.dark,
                ),
                home: const BackupWelcomeScreen(),
              ),
            ),
          );
        } else {
          await tester.pumpWidget(
            appUnderTest(
              themeMode: mode,
              path: scenario == 'restore'
                  ? '/profile/backups/restore'
                  : '/profile/backups',
            ),
          );
        }
        await settle(tester);
        if (scenario == 'restore') {
          await tester.tap(find.text('Choose backup folder'));
          await settle(tester);
          await tester.tap(find.text('1,264 transactions'));
          await settle(tester);
          await tester.drag(find.byType(ListView).last, const Offset(0, -260));
          await settle(tester);
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/backups_${scenario}_$name.png'),
        );
      });
    }
  }
}
