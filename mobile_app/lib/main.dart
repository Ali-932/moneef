import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'router.dart';
import 'screens/backups_screen.dart';
import 'services/backup_service.dart';
import 'state/bootstrap.dart';
import 'state/providers.dart';
import 'theme.dart';
import 'widgets/branding/startup_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Seed the cached dark-mode flag before the first frame so dark-mode users
  // never see a light flash on cold start.
  final prefs = await SharedPreferences.getInstance();
  final cachedDark = prefs.getBool(darkModeCacheKey) ?? false;
  runApp(
    ProviderScope(
      overrides: [cachedDarkModeProvider.overrideWith((_) => cachedDark)],
      child: const MoneefApp(),
    ),
  );
}

class MoneefApp extends ConsumerWidget {
  const MoneefApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Moneef',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: themeMode,
      themeAnimationDuration: AppMotion.theme,
      themeAnimationCurve: AppMotion.emphasized,
      routerConfig: appRouter,
      builder: (context, child) =>
          _BootGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Mounts the router immediately, paints a splash overlay until boot
/// finishes. Keeps the router widget tree alive across boot state changes
/// so route restoration is instant and there are no full-tree rebuilds.
class _BootGate extends ConsumerStatefulWidget {
  const _BootGate({required this.child});
  final Widget child;

  @override
  ConsumerState<_BootGate> createState() => _BootGateState();
}

class _BootGateState extends ConsumerState<_BootGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final boot = ref.read(bootControllerProvider);
      if (boot.stage == BootStage.idle) {
        ref.read(bootControllerProvider.notifier).boot();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stage = ref.watch(bootControllerProvider.select((s) => s.stage));
    ref.watch(backupStatusProvider);
    final error = ref.watch(bootControllerProvider.select((s) => s.error));

    // Eagerly preload reference data as soon as the core is ready so
    // form pickers (currency, categories) are available immediately.
    if (stage == BootStage.ready) {
      ref.watch(categoriesProvider);
      ref.watch(currenciesProvider);
    }

    return Stack(
      children: [
        ExcludeSemantics(
          excluding: stage != BootStage.ready,
          child: IgnorePointer(
            ignoring: stage != BootStage.ready,
            child: widget.child,
          ),
        ),
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppMotion.chip,
            switchInCurve: AppMotion.entrance,
            switchOutCurve: AppMotion.exit,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              fit: StackFit.expand,
              children: [...previousChildren, ?currentChild],
            ),
            child: stage == BootStage.ready
                ? const SizedBox.shrink()
                : ColoredBox(
                    key: ValueKey(
                      stage == BootStage.idle ? BootStage.initializing : stage,
                    ),
                    color: AppColors.of(context).surface,
                    child: stage == BootStage.welcome
                        ? const BackupWelcomeScreen()
                        : stage == BootStage.error
                        ? _BootErrorBody(error: error)
                        : const StartupSplash(),
                  ),
          ),
        ),
      ],
    );
  }
}

class _BootErrorBody extends StatelessWidget {
  const _BootErrorBody({required this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          'Boot failed:\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}
