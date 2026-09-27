// e2e coverage for T9 (Backups). The `moneef/api` channel is wired to the
// real Go core via [RealBridge]; the Android SAF layer (`moneef/backups`)
// cannot run on this machine, so [BackupBridge] (a fixed-shape fake matching
// the Kotlin contract, see test/support/backup_bridge.dart) is installed on
// top of RealBridge to stand in for it, exactly as the harness intends.
//
// Every leaf drives the real screens, then verifies twice: once by reading
// the rendered UI, once by calling straight into the real Go core via
// `bridge.json(...)`, independent of whatever the widget tree displays.
//
// mobilebridge/_e2e/main.go's dispatch table does not expose CreateBackup /
// RestoreBackup (see mobilebridge/_e2e/main.go — only CRUD/profile/settings
// methods are wired), so those two Go entry points cannot be driven from
// here. That round trip is instead exercised directly with
// `go test -tags smoke ./mobilebridge/` (see the written report).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/backups_screen.dart';
import 'package:mobile_app/state/bootstrap.dart';
import 'package:mobile_app/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/harness.dart';
import '../support/backup_bridge.dart';
import 'real_bridge.dart';

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

  /// Real category lookup by name (seeded by mobile.Init — see
  /// mobilebridge/seed_defaults.go), so we send a valid `category_id`.
  int categoryId(String name) {
    final cats = (bridge.json('listCategories', body: const {}) as List)
        .cast<Map<String, dynamic>>();
    return (cats.firstWhere((c) => c['name'] == name)['id'] as num).toInt();
  }

  /// Creates a transaction directly through the real Go core, independent of
  /// any UI action, so leaves that aren't about transaction entry can seed
  /// and later verify state without exercising (and thus coupling to) the
  /// add-transaction flow.
  void seedTransaction(
    String name, {
    String type = 'expense',
    String categoryName = 'Food',
    String amount = '4.50',
  }) {
    bridge.json(
      'createTransaction',
      body: {
        'transaction_name': name,
        'currency_code': 'USD',
        'transaction_type': type,
        'date': DateTime.now().toUtc().toIso8601String(),
        'transaction_categories': [
          {'category_id': categoryId(categoryName), 'amount': amount},
        ],
      },
    );
  }

  int transactionCount() =>
      (bridge.json('listTransactions', body: const {}) as Map)['count']
          as int;

  testWidgets(
    '9.1 enabling from a disabled state shows the folder and status, and touches no app data',
    (tester) async {
      final backups = BackupBridge()..install();
      seedTransaction('Groceries run');
      final before = bridge.json('listTransactions', body: const {});

      await open(tester);
      expect(find.text('Enable local backups'), findsOneWidget);
      expect(find.text('Last successful backup'), findsNothing);

      await tester.tap(find.text('Enable local backups'));
      await settle(tester);

      expect(backups.configured, 1);
      expect(find.text('Last successful backup'), findsOneWidget);
      expect(
        find.text('Internal storage / Documents/Moneef Backups'),
        findsOneWidget,
      );
      expect(find.text('No completed backup yet'), findsNothing);
      expect(find.textContaining('Could not'), findsNothing);

      // Independent verification: enabling backups is a `moneef/backups`
      // side effect only. The real Go core's data must be byte-identical.
      final after = bridge.json('listTransactions', body: const {});
      expect(after, equals(before));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '9.2 cancelling the folder picker leaves status and data untouched',
    (tester) async {
      final backups = BackupBridge()
        ..cancelPicker = true
        ..install();
      seedTransaction('Rent payment', categoryName: 'Housing');
      final before = bridge.json('listTransactions', body: const {});

      await open(tester);
      await tester.tap(find.text('Enable local backups'));
      await settle(tester);

      expect(backups.configured, 0);
      expect(find.text('Enable local backups'), findsOneWidget);
      expect(find.text('Last successful backup'), findsNothing);
      expect(find.textContaining('Could not'), findsNothing);

      // Cancelling twice in a row must stay a no-op, not throw or half-apply.
      await tester.tap(find.text('Enable local backups'));
      await settle(tester);
      expect(backups.configured, 0);

      final after = bridge.json('listTransactions', body: const {});
      expect(after, equals(before));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '9.3 manual backup surfaces failure messaging then clears on a successful retry',
    (tester) async {
      final backups = BackupBridge()..install();
      backups.status.addAll({
        'enabled': true,
        'folderName': 'Documents/Moneef Backups',
      });
      seedTransaction('Coffee');
      final count = transactionCount();

      await open(tester);
      backups.failBackup = true;
      await tester.ensureVisible(find.text('Back up now'));
      await tester.tap(find.text('Back up now'));
      await settle(tester);
      expect(find.textContaining('Your data is still saved'), findsOneWidget);
      // A failed backup must never touch the live data it was backing up.
      expect(transactionCount(), count);

      backups.failBackup = false;
      await tester.tap(find.text('Back up now'));
      await settle(tester);
      expect(find.textContaining('Your data is still saved'), findsNothing);
      expect(backups.manual, 2);
      expect(transactionCount(), count);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '9.4 restore reviews a copy, rejects a failed attempt, then swaps data on success',
    (tester) async {
      final backups = BackupBridge()..install();
      seedTransaction('Pre-restore latte');
      expect(transactionCount(), 1);

      await open(tester, path: '/profile/backups/restore');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RestoreBackupScreen)),
      );
      final oldDashboard = await container.read(dashboardProvider.future);
      expect(
        oldDashboard.recentTransactions.map((t) => t.name),
        contains('Pre-restore latte'),
      );

      await tester.tap(find.text('Choose backup folder'));
      await settle(tester);
      expect(find.text('1,264 transactions'), findsOneWidget);
      expect(backups.restored, 0);

      await tester.tap(find.text('1,264 transactions'));
      await settle(tester);
      expect(find.text('Replace current data?'), findsOneWidget);

      backups.failRestore = true;
      await tester.ensureVisible(find.text('Restore this backup'));
      await tester.tap(find.text('Restore this backup'));
      await settle(tester);
      expect(find.text('Backup is incomplete or damaged.'), findsOneWidget);
      // resetWithProfile() always mints profile id 1 — a failed restore must
      // not move the app off it.
      expect(container.read(bootControllerProvider).profileId, 1);
      expect(transactionCount(), 1);

      backups.failRestore = false;
      // mobilebridge/_e2e/main.go's dispatch table doesn't wire RestoreBackup (see
      // the file header), so we can't invoke the real Go restore through
      // this harness. We reproduce its externally-visible effect — the
      // entire dataset swapped for the archive's — against the same real
      // core here, so the assertions below prove the Dart layer reacts
      // correctly to a real dataset swap, not to a canned response.
      backups.onRestore = () {
        final live =
            (bridge.json('listTransactions', body: const {})
                    as Map)['results']
                as List;
        for (final t in live) {
          bridge.json('deleteTransaction', id: (t['id'] as num).toInt());
        }
        seedTransaction(
          'Post-restore salary',
          type: 'income',
          categoryName: 'Salary',
          amount: '1200.00',
        );
      };
      await tester.ensureVisible(find.text('Restore this backup'));
      await tester.tap(find.text('Restore this backup'));
      await settle(tester);

      expect(backups.restored, 2);
      // BackupBridge.restore() always answers profileId 42 (see
      // test/support/backup_bridge.dart) — that's the id completeRestore
      // must adopt.
      expect(container.read(bootControllerProvider).profileId, 42);
      expect(
        (await SharedPreferences.getInstance()).getInt('moneef.profile_id'),
        42,
      );

      final newDashboard = await container.read(dashboardProvider.future);
      expect(identical(newDashboard, oldDashboard), isFalse);
      expect(
        newDashboard.recentTransactions.map((t) => t.name),
        contains('Post-restore salary'),
      );
      expect(
        newDashboard.recentTransactions.map((t) => t.name),
        isNot(contains('Pre-restore latte')),
      );

      // Independent verification straight off the real Go core, bypassing
      // the provider the assertions above already read from.
      final afterTx =
          bridge.json('listTransactions', body: const {}) as Map;
      expect((afterTx['results'] as List).single['name'], 'Post-restore salary');
      expect(find.text('Overview'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
