import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/state/bootstrap.dart';
import 'package:mobile_app/theme.dart';
import 'package:mobile_app/widgets/branding/moneef_logo.dart';
import 'package:mobile_app/widgets/branding/startup_splash.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/fixtures.dart';
import '../screenshots/harness.dart';
import '../screenshots/mock_native_api.dart';
import '../support/backup_bridge.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  setUpAll(loadRealFonts);

  for (final profileId in [0, 7]) {
    testWidgets(
      'splash waits for initialization then opens profile $profileId',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final dir = Directory.systemTemp.createTempSync('moneef-splash-');
        final oldPaths = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _Paths(dir.path);
        addTearDown(() {
          PathProviderPlatform.instance = oldPaths;
          dir.deleteSync(recursive: true);
        });
        final initialized = Completer<void>();
        var initCalls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('moneef/api'), (
              call,
            ) async {
              if (call.method == 'init') {
                initCalls++;
                await initialized.future;
                return null;
              }
              if (call.method == 'activeProfileId') {
                installNativeApiMock(Fixtures());
                return profileId;
              }
              throw MissingPluginException(call.method);
            });
        BackupBridge().install();
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MoneefApp(),
          ),
        );
        await settle(tester);
        expect(initCalls, 1);
        expect(
          container.read(bootControllerProvider).stage,
          BootStage.initializing,
        );
        expect(find.byType(StartupSplash), findsOneWidget);
        expect(
          tester.getSize(find.byType(StartupSplash)),
          tester.view.physicalSize / tester.view.devicePixelRatio,
        );
        expect(tester.getTopLeft(find.byType(StartupSplash)), Offset.zero);
        expect(find.byType(MoneefLogo), findsOneWidget);
        expect(find.text('Loading…'), findsOneWidget);
        expect(find.text('Home').hitTestable(), findsNothing);

        initialized.complete();
        await settle(tester);
        expect(find.byType(StartupSplash), findsNothing);
        if (profileId == 0) {
          expect(
            container.read(bootControllerProvider).stage,
            BootStage.welcome,
          );
          expect(find.text('Start fresh').hitTestable(), findsOneWidget);
        } else {
          expect(container.read(bootControllerProvider).stage, BootStage.ready);
          expect(find.text('Home').hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('loader moves normally and holds still with reduced motion', (
    tester,
  ) async {
    Future<void> open(bool reduced) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: const StartupSplash(),
          ),
        ),
      );
    }

    double offset() => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(StartupSplash),
                matching: find.byType(Transform),
              )
              .last,
        )
        .transform
        .storage[12];

    await open(false);
    final initial = offset();
    await tester.pump(const Duration(milliseconds: 700));
    expect(offset(), isNot(initial));
    await open(true);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    final still = offset();
    await tester.pump(const Duration(seconds: 2));
    expect(offset(), still);
    expect(tester.binding.hasScheduledFrame, isFalse);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Loading Moneef'), findsOneWidget);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('splash ${dark ? 'dark' : 'light'} adapts to large text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in [const Size(320, 640), const Size(640, 320)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(dark ? Brightness.dark : Brightness.light),
            home: const MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: StartupSplash(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Moneef'), findsOneWidget);
      }
    });
  }
}
