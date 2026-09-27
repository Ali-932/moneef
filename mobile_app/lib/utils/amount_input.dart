import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';

/// Display grouping never changes the decimal value sent to the backend.
Decimal? parseAmountInput(String text) =>
    Decimal.tryParse(text.replaceAll(',', '').trim());

/// Groups the integer part without rounding decimals or converting to double.
String formatAmountInput(String text) {
  final raw = text.replaceAll(',', '');
  final point = raw.indexOf('.');
  final whole = point < 0 ? raw : raw.substring(0, point);
  final fraction = point < 0 ? '' : raw.substring(point);
  final grouped = whole.replaceAllMapped(
    RegExp(r'\d(?=(\d{3})+$)'),
    (match) => '${match[0]},',
  );
  return '$grouped$fraction';
}

/// Adds thousands separators while preserving selection, decimal zeros and
/// intermediate edits. Backspace/delete across a separator removes a digit.
class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    var raw = newValue.text.replaceAll(',', '');
    if (!RegExp(r'^\d*(\.\d*)?$').hasMatch(raw)) return oldValue;

    int rawOffset(int offset) => newValue.text
        .substring(0, offset.clamp(0, newValue.text.length))
        .replaceAll(',', '')
        .length;

    var base = rawOffset(newValue.selection.baseOffset);
    var extent = rawOffset(newValue.selection.extentOffset);
    if (oldValue.selection.isCollapsed &&
        newValue.selection.isCollapsed &&
        oldValue.text.length == newValue.text.length + 1 &&
        oldValue.text.replaceAll(',', '') == raw) {
      final backspace =
          oldValue.selection.baseOffset > newValue.selection.baseOffset;
      final digit = backspace ? base - 1 : base;
      if (digit >= 0 && digit < raw.length && raw[digit] != '.') {
        raw = raw.replaceRange(digit, digit + 1, '');
        base = extent = digit;
      }
    }

    final formatted = formatAmountInput(raw);
    int formattedOffset(int offset) {
      var remaining = offset;
      for (var i = 0; i < formatted.length; i++) {
        if (remaining == 0) return i;
        if (formatted[i] != ',') remaining--;
      }
      return formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: newValue.selection.isValid
          ? newValue.selection.copyWith(
              baseOffset: formattedOffset(base),
              extentOffset: formattedOffset(extent),
            )
          : newValue.selection,
    );
  }
}
