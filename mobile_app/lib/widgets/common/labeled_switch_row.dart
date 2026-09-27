import 'package:flutter/material.dart';

/// A "label + trailing [Switch]" row — used for on/off settings such as
/// "Recurring payment", "Has end date?" and "Dark mode".
///
/// Wrapped in [IntrinsicHeight] so the row's height always comes from an
/// explicit intrinsic-height pass over its own children instead of being
/// inherited from ambient layout. Without it, this exact shape (a bare
/// `Row(Expanded(Text) + Switch)`) has been observed to measure as near-zero
/// tall at large OS text scales once real device fonts are loaded — label
/// and switch both render, just squeezed into a sliver a couple of pixels
/// tall. [IntrinsicHeight] forces a real height every time, at the cost of
/// one extra (cheap, two-child) layout pass.
class LabeledSwitchRow extends StatelessWidget {
  const LabeledSwitchRow({
    super.key,
    required this.label,
    required this.labelStyle,
    required this.value,
    required this.onChanged,
    required this.activeThumbColor,
    this.adaptive = false,
  });

  final String label;
  final TextStyle labelStyle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeThumbColor;

  /// Uses [Switch.adaptive] (Cupertino style on iOS) instead of the plain
  /// Material [Switch].
  final bool adaptive;

  @override
  Widget build(BuildContext context) {
    final switchWidget = adaptive
        ? Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: activeThumbColor,
          )
        : Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: activeThumbColor,
          );
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          switchWidget,
        ],
      ),
    );
  }
}
