import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/analysis.dart';
import '../models/dashboard.dart';
import '../models/pattern.dart';
import '../models/recurrence_occurrence.dart';
import '../utils/date_range.dart';
import 'bootstrap.dart';
import 'providers.dart';

const _rangePrefsKey = 'moneef:insights-range';

enum PatternPeriod { all, days30, days90, months12 }

String patternPeriodLabel(PatternPeriod p) => switch (p) {
  PatternPeriod.all => 'All time',
  PatternPeriod.days30 => '30d',
  PatternPeriod.days90 => '90d',
  PatternPeriod.months12 => '12m',
};

final insightsRangeProvider =
    StateNotifierProvider<InsightsRangeNotifier, DateRange>((ref) {
      return InsightsRangeNotifier();
    });

class InsightsRangeNotifier extends StateNotifier<DateRange> {
  InsightsRangeNotifier()
    : super(dateRangeFromPreset(DateRangePreset.thisMonth, DateTime.now())) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_rangePrefsKey);
    if (saved == null) return;
    final preset = DateRangePreset.values.cast<DateRangePreset?>().firstWhere(
      (p) => p != null && presetLabel(p) == saved,
      orElse: () => null,
    );
    if (preset != null && preset != DateRangePreset.custom) {
      state = dateRangeFromPreset(preset, DateTime.now());
    }
  }

  Future<void> setPreset(DateRangePreset preset) async {
    if (preset == DateRangePreset.custom) return;
    state = dateRangeFromPreset(preset, DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rangePrefsKey, presetLabel(preset));
  }

  Future<void> setCustom(DateTime from, DateTime to) async {
    state = DateRange(
      from: DateTime.utc(from.year, from.month, from.day),
      to: DateTime.utc(to.year, to.month, to.day, 23, 59, 59, 999),
      preset: DateRangePreset.custom,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rangePrefsKey, presetLabel(DateRangePreset.custom));
  }
}

final patternPeriodProvider = StateProvider<PatternPeriod>(
  (_) => PatternPeriod.all,
);

final analysisProvider = FutureProvider<AnalysisCharts>((ref) async {
  final boot = ref.watch(bootControllerProvider);
  if (boot.stage != BootStage.ready) throw StateError('boot not ready');

  final range = ref.watch(insightsRangeProvider);
  final settings = await ref.watch(settingsProvider.future);
  final api = ref.watch(nativeApiProvider);

  final raw = await api.analysis(
    startDate: range.from,
    endDate: range.to,
    currency: settings.currencyCode,
  );
  return AnalysisCharts.fromJson(raw);
});

final insightsIncomeProvider = FutureProvider<Decimal>((ref) async {
  final boot = ref.watch(bootControllerProvider);
  if (boot.stage != BootStage.ready) return Decimal.zero;

  final range = ref.watch(insightsRangeProvider);
  final api = ref.watch(nativeApiProvider);

  final raw = await api.dashboard(from: range.from, to: range.to);
  return DashboardSummary.fromJson(raw).totalIncome;
});

final patternsProvider = FutureProvider<List<Pattern>>((ref) async {
  final boot = ref.watch(bootControllerProvider);
  if (boot.stage != BootStage.ready) return <Pattern>[];

  final period = ref.watch(patternPeriodProvider);
  final api = ref.watch(nativeApiProvider);

  // Recompute from transactions, including for All time. Listing stored
  // patterns would keep old results after a transaction changes.
  final raw = await api.refreshPatterns(
    startDate: period == PatternPeriod.all ? null : _periodStart(period),
    endDate: period == PatternPeriod.all ? null : DateTime.now().toUtc(),
  );

  return raw
      .cast<Map<String, dynamic>>()
      .map(Pattern.fromJson)
      .toList(growable: false);
});

DateTime _periodStart(PatternPeriod period) {
  final now = DateTime.now().toUtc();
  return switch (period) {
    PatternPeriod.days30 => now.subtract(const Duration(days: 30)),
    PatternPeriod.days90 => now.subtract(const Duration(days: 90)),
    PatternPeriod.months12 => DateTime.utc(now.year - 1, now.month, now.day),
    PatternPeriod.all => now,
  };
}

final recurrenceTimelineProvider = FutureProvider<List<RecurrenceOccurrence>>((
  ref,
) async {
  final boot = ref.watch(bootControllerProvider);
  if (boot.stage != BootStage.ready) return <RecurrenceOccurrence>[];

  final api = ref.watch(nativeApiProvider);
  final raw = await api.recurrenceTimeline();
  return raw
      .cast<Map<String, dynamic>>()
      .map(RecurrenceOccurrence.fromJson)
      .toList(growable: false);
});
