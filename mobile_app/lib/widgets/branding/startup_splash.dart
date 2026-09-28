import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';
import 'moneef_logo.dart';

/// Remains visible while the boot controller opens the local database.
/// No minimum duration: a fast launch goes straight to the app.
class StartupSplash extends StatelessWidget {
  const StartupSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: palette.surface,
          ),
      child: Material(
        color: palette.surface,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const ExcludeSemantics(child: MoneefLogo()),
                      const SizedBox(height: 24),
                      Text(
                        'Moneef',
                        style: TextStyle(
                          fontSize: 32,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 36),
                      const _LoadingTrack(),
                      const SizedBox(height: 14),
                      Text(
                        'Loading…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingTrack extends StatefulWidget {
  const _LoadingTrack();

  @override
  State<_LoadingTrack> createState() => _LoadingTrackState();
}

class _LoadingTrackState extends State<_LoadingTrack>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Semantics(
      label: 'Loading Moneef',
      liveRegion: true,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            width: 104,
            height: 4,
            child: ColoredBox(
              color: palette.primarySoft,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final progress = Curves.easeInOutCubic.transform(
                    _controller.value,
                  );
                  return Transform.translate(
                    offset: Offset(-36 + 140 * progress, 0),
                    child: Align(alignment: Alignment.centerLeft, child: child),
                  );
                },
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.accentFill,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
