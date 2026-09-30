import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// Maps ISO-4217 currency codes to display symbols. Falls back to the code
/// itself when unknown — the Go side guarantees a 3-letter code.
const _currencySymbols = <String, String>{
  'USD': r'$',
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥',
  'IQD': 'IQD ',
  'SAR': 'SAR ',
  'AED': 'AED ',
};

String currencySymbol(String code) =>
    _currencySymbols[code.toUpperCase()] ?? '$code ';

/// The human "1 base = N foreign" rate, given the stored foreign→base rate.
/// Backend stores rates foreign→base (e.g. 1 IQD = 0.0007608 USD); the settings
/// row shows the inverse so it reads naturally ("1 USD = 1314 IQD"). Returns a
/// plain, trimmed number string suitable for an editable field.
String inverseRateString(Decimal stored, {int scale = 6}) {
  if (stored <= Decimal.zero) return '';
  final inv = (Decimal.one / stored).toDecimal(scaleOnInfinitePrecision: scale);
  final s = inv.toString();
  // Trim trailing zeros so the field shows "1314.4" not "1314.400000".
  return s.contains('.')
      ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
      : s;
}

/// Formats [amount] with [code]'s symbol. When [signed] is true, prefixes
/// "+" for positive values; negative always shows "-".
String formatMoney(Decimal amount, String code, {bool signed = false}) {
  final symbol = currencySymbol(code);
  final abs = amount.abs();
  final whole = abs.truncate().toBigInt().toString();
  final fracRaw = (abs - abs.truncate()).toString();
  String frac;
  if (fracRaw.contains('.')) {
    frac = fracRaw.split('.').last;
    if (frac.length > 2) frac = frac.substring(0, 2);
    if (frac.length < 2) frac = frac.padRight(2, '0');
  } else {
    frac = '00';
  }
  final grouped = _groupThousands(whole);
  final sign = amount < Decimal.zero
      ? '-'
      : signed
      ? '+'
      : '';
  return '$sign$symbol$grouped.$frac';
}

String _groupThousands(String digits) {
  final buf = StringBuffer();
  final n = digits.length;
  for (var i = 0; i < n; i++) {
    buf.write(digits[i]);
    final remaining = n - 1 - i;
    if (remaining > 0 && remaining % 3 == 0) buf.write(',');
  }
  return buf.toString();
}

/// "10:42 AM"
String formatClock(DateTime d) => DateFormat('h:mm a').format(d.toLocal());

String formatDateShort(DateTime d) => DateFormat('MMM d').format(d.toLocal());

/// "Aug 13, 2025"
String formatDateLong(DateTime d) => DateFormat('MMM d, y').format(d.toLocal());

/// Used for transaction-row time when shown on the dashboard.
String formatDateTimeShort(DateTime d) =>
    DateFormat('MMM d • h:mm a').format(d.toLocal());

/// Date group label: "Today" / "Yesterday" / "Aug 13, 2025".
String formatGroupLabel(DateTime d, {DateTime? now}) {
  final today = (now ?? DateTime.now()).toLocal();
  final local = d.toLocal();
  final dToday = DateTime(today.year, today.month, today.day);
  final dRow = DateTime(local.year, local.month, local.day);
  final diff = dToday.difference(dRow).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('MMM d, y').format(local);
}

String formatPeriodLabel(DateTime from, DateTime to) {
  from = from.toLocal();
  to = to.toLocal();
  if (from.year == to.year && from.month == to.month) {
    return DateFormat('MMM y').format(from);
  }
  if (from.year == to.year) {
    return '${DateFormat('MMM').format(from)} – ${DateFormat('MMM y').format(to)}';
  }
  return '${DateFormat('MMM y').format(from)} – ${DateFormat('MMM y').format(to)}';
}
