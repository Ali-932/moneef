import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/backups_screen.dart';
import 'package:mobile_app/state/bootstrap.dart';
import 'package:mobile_app/state/insights_providers.dart';
import 'package:mobile_app/state/providers.dart';
import 'package:mobile_app/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/harness.dart';
import '../support/backup_bridge.dart';
import '../support/mutable_native_api.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(
    WidgetTester tester, {
    String path = '/profile/backups',
  }) async {
    setGoldenSurface(tester);
    await tester.pumpWidget(
      appUnderTest(themeMode: ThemeMode.light, path: path),
    );
    await settle(tester);
  }

  testWidgets(
    'folder cancellation keeps setup unchanged; enabling and manual backup show status',
    (tester) async {
      MutableNativeApi().install();
      final bridge = BackupBridge()
        ..cancelPicker = true
        ..install();
      await open(tester);
      await tester.tap(find.text('Enable local backups'));
      await settle(tester);
      expect(bridge.configured, 0);
      bridge.cancelPicker = false;
      await tester.tap(find.text('Enable local backups'));
      await settle(tester);
      expect(bridge.configured, 1);
      expect(find.text('Last successful backup'), findsOneWidget);
      expect(
        find.text('Internal storage / Documents/Moneef Backups'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Back up now'));
      await tester.tap(find.text('Back up now'));
      await settle(tester);
      expect(bridge.manual, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed backup can be retried without changing transactions', (
    tester,
  ) async {
    final native = MutableNativeApi()..install();
    final bridge = BackupBridge()..install();
    bridge.status.addAll({
      'enabled': true,
      'folderName': 'Documents/Moneef Backups',
    });
    final count = native.fixtures.transactions.length;
    await open(tester);
    bridge.failBackup = true;
    await tester.tap(find.text('Back up now'));
    await settle(tester);
    expect(find.textContaining('Your data is still saved'), findsOneWidget);
    bridge.failBackup = false;
    await tester.tap(find.text('Back up now'));
    await settle(tester);
    expect(find.textContaining('Your data is still saved'), findsNothing);
    expect(native.fixtures.transactions.length, count);
    expect(bridge.manual, 2);
  });

  testWidgets(
    'restore reviews counts; corrupt copy keeps current data; success refreshes metrics',
    (tester) async {
      final native = MutableNativeApi()..install();
      final bridge = BackupBridge()..install();
      await open(tester, path: '/profile/backups/restore');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RestoreBackupScreen)),
      );
      final oldDashboard = await container.read(dashboardProvider.future);
      await container.read(analysisProvider.future);
      await tester.tap(find.text('Choose backup folder'));
      await settle(tester);
      expect(find.text('1,264 transactions'), findsOneWidget);
      expect(bridge.restored, 0);
      await tester.tap(find.text('1,264 transactions'));
      await settle(tester);
      expect(find.text('Replace current data?'), findsOneWidget);
      await tester.ensureVisible(find.text('Restore this backup'));
      await settle(tester);
      bridge.failRestore = true;
      await tester.tap(find.text('Restore this backup'));
      await settle(tester);
      expect(find.text('Backup is incomplete or damaged.'), findsOneWidget);
      expect(container.read(bootControllerProvider).profileId, 1);
      bridge.failRestore = false;
      bridge.onRestore = () => native.fixtures.transactions.clear();
      await tester.ensureVisible(find.text('Restore this backup'));
      await settle(tester);
      await tester.tap(find.text('Restore this backup'));
      await settle(tester);
      expect(container.read(bootControllerProvider).profileId, 42);
      expect(
        (await SharedPreferences.getInstance()).getInt('moneef.profile_id'),
        42,
      );
      final newDashboard = await container.read(dashboardProvider.future);
      expect(identical(newDashboard, oldDashboard), isFalse);
      expect(newDashboard.recentTransactions, isEmpty);
      expect(native.calls['dashboard'], greaterThanOrEqualTo(2));
      expect(find.text('Overview'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty folder explains where to look and does not restore', (
    tester,
  ) async {
    MutableNativeApi().install();
    final bridge = BackupBridge()
      ..empty = true
      ..install();
    await open(tester, path: '/profile/backups/restore');
    await tester.tap(find.text('Choose backup folder'));
    await settle(tester);
    expect(find.text('No backups found'), findsOneWidget);
    expect(find.text('Restore this backup'), findsNothing);
    expect(bridge.restored, 0);
  });

  testWidgets('home prompt can be dismissed', (tester) async {
    MutableNativeApi().install();
    BackupBridge().install();
    await open(tester, path: '/home');
    expect(find.text('Keep a local backup'), findsOneWidget);
    await tester.tap(find.text('Maybe later'));
    await settle(tester);
    expect(find.text('Keep a local backup'), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'welcome and backup pages fit large text (${dark ? 'dark' : 'light'})',
      (tester) async {
        MutableNativeApi().install();
        BackupBridge().install();
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        for (final screen in [
          const BackupWelcomeScreen(),
          const BackupsScreen(),
          const RestoreBackupScreen(firstLaunch: true),
        ]) {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: buildAppTheme(dark ? Brightness.dark : Brightness.light),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: screen,
              ),
            ),
          );
          await settle(tester);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets('welcome restore stays reversible before selecting a copy', (
    tester,
  ) async {
    BackupBridge().install();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const BackupWelcomeScreen(),
        ),
      ),
    );
    await tester.tap(find.text('Restore local backup'));
    await settle(tester);
    expect(find.text('Choose backup folder'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    expect(find.text('Start fresh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
