import 'dart:ui' show lerpDouble;

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

bool _reducedMotion(BuildContext context) =>
    MediaQuery.of(context).disableAnimations;

/// go_router page that pushes [child] with a horizontal shared-axis motion.
/// Use for hierarchical navigation: list -> detail, screen -> sub-screen.
CustomTransitionPage<T> sharedAxisPage<T>({
  required Widget child,
  LocalKey? key,
  SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: AppMotion.page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (_reducedMotion(context)) {
        return FadeTransition(opacity: animation, child: child);
      }
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: type,
        fillColor: context.palette.surface,
        child: child,
      );
    },
  );
}

/// go_router page that fades [child] through. Use for loosely related,
/// top-level destinations that don't share a spatial relationship.
CustomTransitionPage<T> fadeThroughPage<T>({
  required Widget child,
  LocalKey? key,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: AppMotion.page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (_reducedMotion(context)) {
        return FadeTransition(opacity: animation, child: child);
      }
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        fillColor: context.palette.surface,
        child: child,
      );
    },
  );
}

/// Shows a dialog that visually grows out of [sourceRect] (the tapped card).
/// Falls back to a quick fade when the user prefers reduced motion.
Future<T?> showExpandingDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Rect? sourceRect,
  bool barrierDismissible = true,
  Color barrierColor = Colors.black54,
}) {
  final reduced = _reducedMotion(context);
  final screenSize = MediaQuery.sizeOf(context);
  final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);

  var origin = Alignment.center;
  if (sourceRect != null) {
    final cardCenter = sourceRect.center;
    origin = Alignment(
      ((cardCenter.dx - screenCenter.dx) / (screenSize.width / 2)).clamp(
        -1.0,
        1.0,
      ),
      ((cardCenter.dy - screenCenter.dy) / (screenSize.height / 2)).clamp(
        -1.0,
        1.0,
      ),
    );
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).dialogLabel,
    barrierColor: barrierColor,
    transitionDuration: reduced ? AppMotion.reducedFallback : AppMotion.page,
    pageBuilder: (ctx, _, __) => builder(ctx),
    transitionBuilder: (ctx, animation, _, child) {
      if (reduced) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      }
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final scale = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (_, cachedChild) {
          final s = lerpDouble(0.9, 1.0, scale.value)!;
          return Opacity(
            opacity: fade.value.clamp(0.0, 1.0),
            child: Transform(
              alignment: origin,
              transform: Matrix4.identity()..scaleByDouble(s, s, 1, 1),
              child: cachedChild,
            ),
          );
        },
      );
    },
  );
}

/// Screen-space rect of the widget at [context], or null if not yet laid out.
Rect? getWidgetRect(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
