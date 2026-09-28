import 'package:flutter/material.dart';

/// Delays a list item's fade+slide entrance based on its index so a list
/// reveals in a staggered cascade. Set [shouldStagger] to false on refresh /
/// filter changes / paginated pages so already-seen rows don't re-animate.
class StaggeredAnimatedItem extends StatefulWidget {
  const StaggeredAnimatedItem({
    super.key,
    required this.index,
    required this.shouldStagger,
    required this.child,
  });

  final int index;
  final bool shouldStagger;
  final Widget child;

  /// Max stagger delay of 60ms plus a 180ms transition.
  /// Screens use this to know when it is safe to stop staggering newly added
  /// items (e.g. via pagination).
  static const Duration kMaxTotalDuration = Duration(milliseconds: 240);

  @override
  State<StaggeredAnimatedItem> createState() => _StaggeredAnimatedItemState();
}

class _StaggeredAnimatedItemState extends State<StaggeredAnimatedItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    final delayMs = (widget.index * 20).clamp(0, 60);
    final totalMs = delayMs + 180;

    _controller = AnimationController(
      duration: Duration(milliseconds: totalMs),
      vsync: this,
    );

    final delayFraction = delayMs / totalMs;

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(delayFraction, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(delayFraction, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    if (widget.shouldStagger && !_reducedMotion) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  bool get _reducedMotion {
    final view = WidgetsBinding.instance.platformDispatcher;
    return view.accessibilityFeatures.disableAnimations;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.shouldStagger || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}
