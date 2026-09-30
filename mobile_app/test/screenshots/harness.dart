// Shared plumbing for the screenshot tests: real fonts, a phone-sized
// surface, the real app theme + router with boot bypassed (mocked native
// bridge stands in for it), and a "settle without hanging on the infinite
// shimmer ticker" pump helper.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/router.dart';
import 'package:mobile_app/state/bootstrap.dart';
import 'package:mobile_app/theme.dart';

/// The phone surface every screenshot renders at.
const goldenLogicalSize = Size(412, 915);
const goldenDevicePixelRatio = 2.625;

/// Starts already `BootStage.ready` so screens render immediately against
/// the mocked native bridge instead of the real boot sequence (which needs
/// path_provider + shared_preferences plumbing this harness has no reason to
/// stand up).
class ReadyBootController extends BootController {
  ReadyBootController(super.api) {
    state = const BootState(stage: BootStage.ready, profileId: 1);
  }
}

/// Sets the test binding's view to the phone surface used for every golden.
void setGoldenSurface(WidgetTester tester) {
  tester.view.physicalSize = goldenLogicalSize * goldenDevicePixelRatio;
  tester.view.devicePixelRatio = goldenDevicePixelRatio;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// The real app shell: real `buildAppTheme`, the real route tree, boot
/// bypassed. Each call builds a fresh `GoRouter` on [appRoutes] — reusing the
/// app's single `appRouter` instance across many unrelated test navigations
/// can leave stale pages mounted underneath the current one.
/// [textScale] models the accessibility text-scale screenshots.
Widget appUnderTest({
  required ThemeMode themeMode,
  required String path,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      bootControllerProvider.overrideWith(
        (ref) => ReadyBootController(ref.watch(nativeApiProvider)),
      ),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: _themeWithPlatformFonts(Brightness.light),
      darkTheme: _themeWithPlatformFonts(Brightness.dark),
      themeMode: themeMode,
      routerConfig: _routerAt(path),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
}

// Widget tests don't have Android's system font fallback. Supply the local
// Noto Arabic font so Arabic names render as text instead of missing glyphs.
ThemeData _themeWithPlatformFonts(Brightness brightness) {
  final theme = buildAppTheme(brightness);
  return theme.copyWith(
    textTheme: theme.textTheme.apply(
      fontFamilyFallback: const ['Noto Naskh Arabic'],
    ),
  );
}

const _tabs = {'/home', '/insights', '/transactions', '/profile'};

/// Pushed screens (/add, /transactions/:id, /profile/categories, ...) are
/// opened the way the app opens them — push on top of their tab — so their
/// AppBar shows the back arrow a user actually sees. Deep-linking straight
/// to them leaves an empty back stack and no back button.
GoRouter _routerAt(String path) {
  if (_tabs.contains(path)) {
    return GoRouter(initialLocation: path, routes: appRoutes);
  }
  final tab = _tabs.firstWhere(
    (t) => path.startsWith('$t/'),
    orElse: () => '/home',
  );
  final router = GoRouter(initialLocation: tab, routes: appRoutes);
  WidgetsBinding.instance.addPostFrameCallback((_) => router.push(path));
  return router;
}

/// Pumps fixed frames instead of `pumpAndSettle` — a loading skeleton's
/// `Shimmer` runs an infinite ticker, which `pumpAndSettle` would hang on.
Future<void> settle(
  WidgetTester tester, {
  int frames = 40,
  Duration frame = const Duration(milliseconds: 50),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(frame);
  }
}

/// Loads the bundled Manrope font, Roboto fallback, and both icon fonts so
/// goldens show real text/icons instead of Ahem/tofu boxes. Call once from
/// `setUpAll`.
Future<void> loadRealFonts() async {
  // `flutter test` always exports FLUTTER_ROOT (see flutter/bin/internal/
  // shared.sh) before spawning the test process, so this is only unset if
  // the test binary is invoked some other way.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    throw StateError(
      'FLUTTER_ROOT is not set. Run screenshot tests via `flutter test`, '
      'which exports it automatically.',
    );
  }
  final materialFonts = '$flutterRoot/bin/cache/artifacts/material_fonts';

  await _loadFont('MaterialIcons', [
    '$materialFonts/MaterialIcons-Regular.otf',
  ]);
  final roboto = [
    '$materialFonts/Roboto-Regular.ttf',
    '$materialFonts/Roboto-Medium.ttf',
    '$materialFonts/Roboto-Bold.ttf',
    '$materialFonts/Roboto-Black.ttf',
  ];
  await _loadFont('Roboto', roboto);
  await _loadFont('Manrope', ['assets/fonts/Manrope.ttf']);
  await _loadFont('Noto Naskh Arabic', [
    Platform.environment['MONEEF_TEST_ARABIC_FONT'] ??
        '/usr/share/fonts/noto/NotoNaskhArabic-Regular.ttf',
  ]);
  // Family-less styles (AnimatedDefaultTextStyle, AppBar titles) resolve to
  // the test engine's default 'FlutterTest' block font. On a device they fall
  // back to Roboto, so map that default to Roboto too.
  await _loadFont('FlutterTest', roboto);

  // Iconify `mdi:` glyphs (category/transaction/pattern icons) render from
  // the vendored, patched package (pubspec.yaml `dependency_overrides`). Its
  // IconData constants set `fontPackage:`, so the family Flutter actually
  // looks up is prefixed `packages/<pkg>/<family>` — not the bare family name.
  await _loadFont(
    'packages/material_design_icons_flutter/Material Design Icons',
    [
      'third_party/material_design_icons_flutter/lib/fonts/materialdesignicons-webfont.ttf',
    ],
  );
}

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = await file.readAsBytes();
    loader.addFont(
      Future.value(ByteData.view(bytes.buffer, 0, bytes.lengthInBytes)),
    );
  }
  await loader.load();
}
