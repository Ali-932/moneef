import 'package:flutter/material.dart';
import '../../theme.dart';

/// Shared page heading. A subtitle explains the job of each primary screen.
class PageHeading extends StatelessWidget implements PreferredSizeWidget {
  const PageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Size get preferredSize => const Size.fromHeight(86);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 86,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            color: context.palette.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: context.palette.muted,
          ),
        ),
      ],
    ),
    actions: action == null ? null : [action!, const SizedBox(width: 16)],
  );
}

/// Category color remains recognizable without turning the entire tile into
/// a saturated swatch. The icon foreground is derived from the active theme.
class QuietIcon extends StatelessWidget {
  const QuietIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: dark ? 0.18 : 0.09),
          context.palette.card,
        ),
        borderRadius: AppRadii.medium,
      ),
      child: Icon(
        icon,
        size: size * .47,
        color: Color.lerp(
          color,
          dark ? Colors.white : context.palette.ink,
          dark ? .4 : .25,
        ),
      ),
    );
  }
}

/// A numeric label may wrap on unusually narrow screens or large text sizes.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.value, {
    super.key,
    this.size = 24,
    this.color,
    this.weight = FontWeight.w700,
  });
  final String value;
  final double size;
  final Color? color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) => Text(
    value,
    style: TextStyle(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -0.5,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: color ?? context.palette.ink,
    ),
  );
}
