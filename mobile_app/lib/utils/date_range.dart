import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import '../models/analysis.dart';

enum DateRangePreset {
  thisMonth,
  lastMonth,
  last30d,
  last90d,
  last12m,
  thisYear,
  allTime,
  custom,
}

const presetKeys = [
  DateRangePreset.thisMonth,
  DateRangePreset.lastMonth,
  DateRangePreset.last30d,
  DateRangePreset.last90d,
  DateRangePreset.thisYear,
  DateRangePreset.allTime,
];

String presetLabel(DateRangePreset preset) {
  return switch (preset) {
    DateRangePreset.thisMonth => 'This Month',
    DateRangePreset.lastMonth => 'Last Month',
    DateRangePreset.last30d => 'Last 30 Days',
    DateRangePreset.last90d => 'Last 3 Months',
    DateRangePreset.last12m => 'Last 12 Months',
    DateRangePreset.thisYear => 'This Year',
    DateRangePreset.allTime => 'All Time',
    DateRangePreset.custom => 'Custom',
  };
}

class DateRange {
  const DateRange({required this.from, required this.to, this.preset});

  final DateTime from;
  final DateTime to;
  final DateRangePreset? preset;

  int get days => to.difference(from).inDays;

  ({DateTime from, DateTime to}) previousPeriod() {
    final ms = to.difference(from);
    final prevEnd = from.subtract(const Duration(milliseconds: 1));
    final prevStart = prevEnd.subtract(ms);
    return (from: prevStart, to: prevEnd);
  }
}

DateRange dateRangeFromPreset(DateRangePreset preset, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  switch (preset) {
    case DateRangePreset.thisMonth:
      final start = DateTime(today.year, today.month, 1);
      return DateRange(from: start, to: today.endOfDay(), preset: preset);
    case DateRangePreset.lastMonth:
      final start = DateTime(today.year, today.month - 1, 1);
      final end = DateTime(today.year, today.month, 0);
      return DateRange(from: start, to: end.endOfDay(), preset: preset);
    case DateRangePreset.last30d:
      final start = DateTime(today.year, today.month, today.day - 30);
      return DateRange(from: start, to: today.endOfDay(), preset: preset);
    case DateRangePreset.last90d:
      final start = DateTime(today.year, today.month, today.day - 90);
      return DateRange(from: start, to: today.endOfDay(), preset: preset);
    case DateRangePreset.last12m:
      final start = DateTime(today.year - 1, today.month, today.day);
      return DateRange(from: start, to: today.endOfDay(), preset: preset);
    case DateRangePreset.thisYear:
      final start = DateTime(today.year, 1, 1);
      return DateRange(from: start, to: today.endOfDay(), preset: preset);
    case DateRangePreset.allTime:
      return DateRange(
        from: DateTime(1970, 1, 1),
        to: today.endOfDay(),
        preset: preset,
      );
    case DateRangePreset.custom:
      throw ArgumentError('custom preset requires explicit dates');
  }
}

DateRangePreset? detectPreset(DateRange range) {
  if (range.preset != null) return range.preset;
  for (final p in presetKeys) {
    final presetRange = dateRangeFromPreset(p, DateTime.now());
    if (range.from == presetRange.from && range.to == presetRange.to) return p;
  }
  return null;
}

enum Aggregation { daily, weekly, monthly }

Aggregation computeAggregation(DateRange range) {
  final days = range.days;
  if (days <= 31) return Aggregation.daily;
  if (days <= 180) return Aggregation.weekly;
  return Aggregation.monthly;
}

enum DateRangeBucket { short, long }

DateRangeBucket computeBucket(DateRange range) =>
    range.days <= 31 ? DateRangeBucket.short : DateRangeBucket.long;

List<AggregatedPeriod> aggregateAmountPerDay(
  List<AmountPerDay> days,
  Aggregation aggregation,
) {
  final groups = <String, _AggGroup>{};
  for (final d in days) {
    final key = _bucketKey(d.date, aggregation);
    final g = groups.putIfAbsent(
      key,
      () => _AggGroup(_bucketLabel(d.date, aggregation), d.date),
    );
    g.amount += d.amount;
    if (d.date.isBefore(g.firstDate)) g.firstDate = d.date;
    if (d.date.isAfter(g.lastDate)) g.lastDate = d.date;
  }
  return groups.values
      .map(
        (g) => AggregatedPeriod(
          label: g.label,
          amount: g.amount.toString(),
          detailLabel: switch (aggregation) {
            Aggregation.daily => DateFormat('MMM d, y').format(g.firstDate),
            Aggregation.weekly =>
              '${DateFormat('MMM d').format(g.firstDate)} – ${DateFormat('MMM d, y').format(g.lastDate)}',
            Aggregation.monthly => DateFormat('MMMM y').format(g.firstDate),
          },
        ),
      )
      .toList();
}

class AggregatedPeriod {
  const AggregatedPeriod({
    required this.label,
    required this.amount,
    this.detailLabel,
  });

  final String label;
  final String amount;
  final String? detailLabel;
}

class _AggGroup {
  _AggGroup(this.label, DateTime date) : firstDate = date, lastDate = date;

  final String label;
  DateTime firstDate;
  DateTime lastDate;
  Decimal amount = Decimal.zero;
}

String _bucketKey(DateTime d, Aggregation agg) {
  return switch (agg) {
    Aggregation.daily => '${d.year}-${d.month.two(d.day)}',
    Aggregation.weekly => '${d.year}-W${_isoWeek(d)}',
    Aggregation.monthly => '${d.year}-${d.month.two()}',
  };
}

String _bucketLabel(DateTime d, Aggregation agg) {
  return switch (agg) {
    Aggregation.daily => '${d.month.two()}/${d.day.two()}',
    Aggregation.weekly => 'W${_isoWeek(d)}',
    Aggregation.monthly => '${_monthName(d.month)} ${d.year}',
  };
}

String _monthName(int month) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return names[month - 1];
}

int _isoWeek(DateTime d) {
  final days = d.difference(DateTime.utc(d.year, 1, 1)).inDays;
  final jan1 = DateTime.utc(d.year, 1, 1);
  final jan1Weekday = jan1.weekday % 7;
  final week = ((days + jan1Weekday) / 7).ceil();
  return week < 1 ? 1 : week;
}

extension _DateHelpers on DateTime {
  DateTime endOfDay() => DateTime(year, month, day, 23, 59, 59, 999);
}

extension _Pad on int {
  String two([int? other]) {
    if (other != null) {
      return '${toString().padLeft(2, '0')}/${other.toString().padLeft(2, '0')}';
    }
    return toString().padLeft(2, '0');
  }
}
