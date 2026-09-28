import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../theme.dart';

/// Single app-wide shimmer clock. All [Shimmer] overlays share one
/// [AnimationController] driven by one [Ticker]; the controller only runs
/// while at least one shimmer is mounted (ref-counted), so it costs nothing
/// once skeletons unmount.
class _ShimmerClock implements TickerProvider {
  _ShimmerClock._();
  static final _ShimmerClock instance = _ShimmerClock._();

  AnimationController? _controller;
  int _refs = 0;

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);

  Listenable acquire() {
    _refs++;
    _controller ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    return _controller!;
  }

  void release() {
    _refs--;
    if (_refs <= 0) {
      _refs = 0;
      _controller?.dispose();
      _controller = null;
    }
  }

  double get value => _controller?.value ?? 0.0;
}

/// Marks a subtree as already shimmering so nested [Shimmer]s skip adding a
/// second [ShaderMask]/controller and become passthrough.
class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required super.child});

  @override
  bool updateShouldNotify(_ShimmerScope oldWidget) => false;
}

/// Applies one animated diagonal shimmer over its whole child subtree.
/// Wrap a skeleton's root once; descendant [ShimmerBox]es are static fills.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> {
  bool _active = false;
  Listenable? _listenable;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nested =
        context.getInheritedWidgetOfExactType<_ShimmerScope>() != null;
    final shouldAnimate = !nested && !MediaQuery.of(context).disableAnimations;
    if (shouldAnimate && !_active) {
      _listenable = _ShimmerClock.instance.acquire();
      _active = true;
    } else if (!shouldAnimate && _active) {
      _ShimmerClock.instance.release();
      _listenable = null;
      _active = false;
    }
  }

  @override
  void dispose() {
    if (_active) _ShimmerClock.instance.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active || _listenable == null) return widget.child;
    final palette = context.palette;
    final baseColor = widget.baseColor ?? palette.shimmerBase;
    final highlightColor = widget.highlightColor ?? palette.shimmerHighlight;
    return _ShimmerScope(
      child: AnimatedBuilder(
        animation: _listenable!,
        child: widget.child,
        builder: (context, child) {
          final v = _ShimmerClock.instance.value;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [baseColor, highlightColor, baseColor],
                stops: [0.0, v, 1.0],
              ).createShader(bounds);
            },
            child: child,
          );
        },
      ),
    );
  }
}

/// A static rectangular placeholder block. The sweep comes from an ancestor
/// [Shimmer]; the box itself does not animate.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.width, this.height, this.borderRadius});

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: palette.shimmerBase,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }
}
