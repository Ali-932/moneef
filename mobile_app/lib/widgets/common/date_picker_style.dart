import 'package:flutter/material.dart';

/// The seven-column calendar needs a smaller type scale on narrow screens.
/// Header, input fields and actions retain the user's larger text setting.
Widget buildAppDatePicker(BuildContext context, Widget? child) {
  final theme = Theme.of(context);
  final picker = theme.datePickerTheme;
  final scaler = MediaQuery.textScalerOf(context);
  final narrow = MediaQuery.sizeOf(context).width < 380;

  TextStyle? fit(TextStyle? style, double maxSize) {
    if (style?.fontSize == null) return style;
    final size = style!.fontSize!;
    final scaled = scaler.scale(size);
    return scaled > maxSize
        ? style.copyWith(fontSize: size * maxSize / scaled)
        : style;
  }

  return Theme(
    data: theme.copyWith(
      datePickerTheme: picker.copyWith(
        dayStyle: fit(picker.dayStyle, narrow ? 18 : 20),
        weekdayStyle: fit(picker.weekdayStyle, 16),
        toggleButtonTextStyle: fit(picker.toggleButtonTextStyle, 18),
      ),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}
