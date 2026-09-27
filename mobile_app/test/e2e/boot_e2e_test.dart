// T1 Boot & onboarding — drives the REAL BootController / MoneefApp
// (lib/main.dart, lib/state/bootstrap.dart), not the ReadyBootController
// screenshot harness, against the real Go core over FFI (RealBridge).
//
// Leaves are intentionally sequential and share process state on purpose:
// the loaded libmoneef_e2e.so is one Go runtime for the whole file, and the
// mocked SharedPreferences store is one in-memory map for the whole file.
// "Relaunch" is modelled as a fresh ProviderContainer (~= a fresh Activity)
// read against that same live state; "cold start" adds bridge.invoke on
// 'shutdown' first.
//
// IMPORTANT constraint found while writing this (see mobile/init.go:45-54
// and internal/config/config.go): `config.GetConfig()` is a *process-wide*
// sync.Once. The dbPath from the very first successful Init in this process
// is fixed forever — a later Init with a different dbPath fails even after
// Shutdown(). So every leaf below must reuse the same fake
// getApplicationSupportDirectory() path, and 1.4 deliberately breaks that
// rule to get a real (non-"already inited") Go init error.
//
// setUp/setUpAll here never call bridge.reset()/resetWithProfile() — unlike
// harness_smoke_e2e_test.dart — because those call into Go before the UI
// does, which would lock config.GetConfig()'s dbPath to bridge.dbPath
// instead of the boot-computed path this file is testing.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/services/native_api.dart';
import 'package:mobile_app/state/bootstrap.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/harness.dart' show settle;
import 'real_bridge.dart';

/// Mirrors the private `_kProfileIdKey` in lib/state/bootstrap.dart. Kept
/// here only to read back what boot persisted — never to drive behavior.
const _profileIdPrefKey = 'moneef.profile_id';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);
  String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

Future<void> _pumpApp(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MoneefApp()),
  );
  await settle(tester);
}

void main() {
  final bridge = RealBridge.instance;
  late Directory supportDir;
  late String expectedDbPath;
  late _FakePathProvider fakePaths;

  // Set by 1.1, consumed by 1.2/1.3/1.4 — this file's leaves are a single
  // continuous boot lifecycle, not independent scenarios.
  int? firstProfileId;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Emptied once for the whole file: 1.2/1.3 rely on it *not* being reset
    // between tests, the same way a real device keeps prefs across app
    // relaunches within one install.
    SharedPreferences.setMockInitialValues({});
    supportDir = Directory.systemTemp.createTempSync('moneef-boot-e2e-');
    expectedDbPath = '${supportDir.path}/moneef/db.sqlite';
    fakePaths = _FakePathProvider(supportDir.path);
    PathProviderPlatform.instance = fakePaths;
  });

  setUp(() {
    // Re-wire the mock method channel before every test (mirrors
    // harness_smoke_e2e_test.dart) — but deliberately do NOT touch the Go
    // core here, see file header.
    bridge.install();
  });

  testWidgets(
    '1.1 first launch (no stored profile) -> welcome -> start fresh -> ready; '
    'persisted to SharedPreferences + Go',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await _pumpApp(tester, container);
      expect(tester.takeException(), isNull);

      // Welcome screen: nothing stored, Go core never inited before now.
      expect(container.read(bootControllerProvider).stage, BootStage.welcome);
      expect(find.text('Your money.\nYour own space.'), findsOneWidget);
      expect(find.text('Start fresh'), findsOneWidget);

      // Independent verification that boot really called Go, with the real
      // path_provider-derived dbPath (not a stub / no-op).
      final initCall = bridge.calls.firstWhere((c) => c.method == 'init');
      expect((initCall.arguments as Map)['dbPath'], expectedDbPath);
      expect((initCall.arguments as Map)['profileId'], 0);
      expect(
        File(expectedDbPath).existsSync(),
        isTrue,
        reason: 'Init should have created+migrated the sqlite file on disk',
      );

      final prefsBefore = await SharedPreferences.getInstance();
      expect(prefsBefore.getInt(_profileIdPrefKey), isNull);

      await tester.tap(find.text('Start fresh'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      final state = container.read(bootControllerProvider);
      expect(state.stage, BootStage.ready);
      firstProfileId = state.profileId;
      expect(firstProfileId, isNotNull);
      expect(firstProfileId, greaterThan(0));
      expect(find.text('Start fresh'), findsNothing);

      // Persisted to SharedPreferences.
      final prefsAfter = await SharedPreferences.getInstance();
      expect(prefsAfter.getInt(_profileIdPrefKey), firstProfileId);

      // Persisted to Go — verified independently of the UI, via the bridge.
      final profile = bridge.json('getProfile') as Map<String, dynamic>;
      expect(profile['first_name'], 'Moneef');
      expect(profile['last_name'], 'User');

      // Home actually rendered against the real core (same signal
      // harness_smoke_e2e_test.dart uses).
      expect(bridge.callCount('dashboard'), greaterThan(0));

      // Tag a marker category so 1.2 can prove "data intact" across a
      // simulated relaunch, independent of the profile row itself.
      bridge.json(
        'createCategory',
        body: {
          'name': 'Boot E2E Marker',
          'type': 'expense',
          'icon': 'mdi:tag',
          'color': '#123456',
        },
      );
    },
  );

  testWidgets(
    '1.2 relaunch with stored profile id -> straight to ready, same profile, data intact',
    (tester) async {
      expect(
        firstProfileId,
        isNotNull,
        reason: '1.1 must run first and reach ready',
      );

      // Simulate a real cold start: process died, Go core is no longer
      // alive, but disk (db.sqlite) + SharedPreferences (mocked, but
      // deliberately not reset) both persisted.
      bridge.invoke('shutdown');

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await _pumpApp(tester, container);
      expect(tester.takeException(), isNull);

      // Straight to ready — no welcome screen this time.
      expect(find.text('Your money.\nYour own space.'), findsNothing);
      final state = container.read(bootControllerProvider);
      expect(state.stage, BootStage.ready);
      expect(state.profileId, firstProfileId);

      // Go was re-inited with the *stored* profile id, not 0.
      final relaunchInit = bridge.calls.lastWhere((c) => c.method == 'init');
      expect((relaunchInit.arguments as Map)['profileId'], firstProfileId);
      expect((relaunchInit.arguments as Map)['dbPath'], expectedDbPath);

      // Same profile, not a freshly-created one.
      expect(bridge.callCount('setup'), 1);

      // Data intact, verified independently via the bridge: the profile row
      // and the marker category from 1.1 both survived shutdown+reconnect.
      final profile = bridge.json('getProfile') as Map<String, dynamic>;
      expect((profile['id'] as num).toInt(), firstProfileId);
      final cats = bridge.json('listCategories', body: {}) as List;
      expect(cats.any((c) => c['name'] == 'Boot E2E Marker'), isTrue);
    },
  );

  testWidgets(
    '1.3 re-init while Go core alive ("already inited" error) -> treated as success',
    (tester) async {
      expect(firstProfileId, isNotNull);
      // Deliberately NO shutdown() here: the Go core is still alive from
      // 1.2, exactly like an Android Activity recreated without the OS
      // process dying (see bootstrap.dart:58-68's comment).

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await _pumpApp(tester, container);
      expect(tester.takeException(), isNull);

      final state = container.read(bootControllerProvider);
      expect(state.stage, BootStage.ready);
      expect(state.profileId, firstProfileId);
      expect(state.error, isNull);
      expect(find.textContaining('Boot failed'), findsNothing);

      // Confirm the "already inited" branch was really exercised and not
      // just skipped: the mock channel doesn't expose the swallowed
      // exception directly, so replay the exact same init call raw and
      // confirm it fails with precisely the sentinel bootstrap.dart checks
      // for (MoneefErrors.alreadyInited) — proving the state above could
      // only have been reached through that catch, not a lucky no-op.
      expect(
        () => bridge.invoke('init', {
          'dbPath': expectedDbPath,
          'profileId': 0,
        }),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.message,
            'message',
            contains(MoneefErrors.alreadyInited),
          ),
        ),
      );
    },
  );

  testWidgets(
    '1.4 boot failure (Go init error) -> error screen shown, no crash',
    (tester) async {
      expect(firstProfileId, isNotNull);
      bridge.invoke('shutdown');

      // Point path_provider at a *different* directory. config.GetConfig()
      // is already locked to expectedDbPath (see file header), so this
      // produces a real, non-"already inited" Go error
      // (mobile/init.go:52-54) instead of a contrived one.
      final wrongDir = Directory.systemTemp.createTempSync(
        'moneef-boot-e2e-wrong-',
      );
      addTearDown(() => wrongDir.deleteSync(recursive: true));
      fakePaths.path = wrongDir.path;

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await _pumpApp(tester, container);

      // "No crash": the harness itself must not see an uncaught exception —
      // boot()'s outer try/catch (bootstrap.dart:76-78) must have handled it.
      expect(tester.takeException(), isNull);

      final state = container.read(bootControllerProvider);
      expect(state.stage, BootStage.error);
      expect(state.error, isA<PlatformException>());
      final message = (state.error as PlatformException).message ?? '';
      expect(message, isNot(contains(MoneefErrors.alreadyInited)));
      expect(message, contains('different db path'));

      expect(find.textContaining('Boot failed'), findsOneWidget);
    },
  );
}
