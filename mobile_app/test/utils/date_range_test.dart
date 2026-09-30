import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/utils/date_range.dart';
import 'package:mobile_app/utils/format.dart';

void main() {
  DateTime endOf(int y, int m, int d) =>
      DateTime(y, m, d + 1).subtract(const Duration(microseconds: 1));
  ({DateTime from, DateTime to}) previous(DateTime from, DateTime to) =>
      DateRange(
        from: from,
        to: to,
        preset: DateRangePreset.custom,
      ).previousPeriod();

  test('a month so far compares with the same days of last month', () {
    final p = previous(DateTime(2026, 9, 1), endOf(2026, 9, 5));
    expect(p.from, DateTime(2026, 8, 1));
    expect(p.to, endOf(2026, 8, 5));
  });

  test('the end is capped to a shorter previous month', () {
    final p = previous(DateTime(2026, 3, 1), endOf(2026, 3, 31));
    expect(p.from, DateTime(2026, 2, 1));
    expect(p.to, endOf(2026, 2, 28));
  });

  test('other ranges compare with the same length right before', () {
    final from = DateTime(2026, 9, 10);
    final to = endOf(2026, 9, 19);
    final p = previous(from, to);
    expect(p.to.isBefore(from), isTrue);
    expect(from.difference(p.to), lessThan(const Duration(seconds: 1)));
    expect(p.to.difference(p.from), to.difference(from));
  });

  test('the period label uses local dates, even when given UTC', () {
    // Local Sep 1 00:00 is Aug 31 in UTC anywhere east of UTC.
    final from = DateTime(2026, 9, 1).toUtc();
    final to = DateTime(2026, 9, 30, 23, 59, 59).toUtc();
    expect(formatPeriodLabel(from, to), 'Sep 2026');
  });
}
