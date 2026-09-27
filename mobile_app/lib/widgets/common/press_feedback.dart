import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';

/// Wraps a tappable child with subtle haptic + scale feedback on press.
/// Use for cards, rows, or any tappable that should feel tactile without a
/// Material ink square. Respects [MediaQuery.disableAnimations].
class PressFeedback extends StatefulWidget {
  const PressFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.pressedScale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double pressedScale;

  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;
    final active = widget.enabled && widget.onTap != null;
    final scale = (shouldAnimate && _isPressed) ? widget.pressedScale : 1.0;

    return Listener(
      onPointerDown: (_) {
        if (active) {
          HapticFeedback.selectionClick();
          _setPressed(true);
        }
      },
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: active ? widget.onTap : null,
        child: AnimatedScale(
          scale: scale,
          duration: AppMotion.press,
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
