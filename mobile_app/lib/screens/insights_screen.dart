import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/analysis.dart';
import '../models/pattern.dart';
import '../models/recurrence_occurrence.dart';
import '../state/insights_providers.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../utils/date_range.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/common/picker_field.dart';
import '../widgets/common/date_picker_style.dart';
import '../widgets/common/skeletons.dart';
import '../widgets/insights/insights_widgets.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 86,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Insights',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Understand your spending',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: palette.muted,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: palette.primary,
          unselectedLabelColor: palette.muted,
          indicatorColor: palette.primary,
          dividerColor: palette.divider,
          labelStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Analysis'),
            Tab(text: 'Patterns'),
          ],
        ),
      ),
      body: Column(
        children: [
          AnimatedBuilder(
            animation: _tabController,
            builder: (_, __) => _tabController.index == 2
                ? const SizedBox.shrink()
                : const _DateRangeBar(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [_OverviewTab(), _AnalysisTab(), _PatternsTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRangeBar extends ConsumerWidget {
  const _DateRangeBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(insightsRangeProvider);
    final activePreset = range.preset;
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [Colors.transparent, Colors.black],
        stops: [0.0, 0.08],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            for (final p in presetKeys) ...[
              _RangeChip(
                label: presetLabel(p),
                selected: activePreset == p,
                onTap: () {
                  if (activePreset != p) {
                    HapticFeedback.selectionClick();
                    ref.read(insightsRangeProvider.notifier).setPreset(p);
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
            _RangeChip(
              label: activePreset == DateRangePreset.custom
                  ? formatPeriodLabel(range.from, range.to)
                  : 'Custom',
              selected: activePreset == DateRangePreset.custom,
              onTap: () => _pickCustom(context, ref, range),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustom(
    BuildContext context,
    WidgetRef ref,
    DateRange current,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      builder: buildAppDatePicker,
      helpText: 'Insight dates',
      saveText: 'Use range',
      confirmText: 'Use range',
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: current.from, end: current.to),
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      await ref
          .read(insightsRangeProvider.notifier)
          .setCustom(picked.start, picked.end);
    }
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final duration = MediaQuery.of(context).disableAnimations
        ? AppMotion.reducedFallback
        : AppMotion.chip;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: duration,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? palette.primarySoft : palette.card,
          borderRadius: AppRadii.pill,
        ),
        child: AnimatedDefaultTextStyle(
          duration: duration,
          style: DefaultTextStyle.of(context).style.copyWith(
            color: selected ? palette.primary : palette.muted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          child: Text(label, maxLines: 1),
        ),
      ),
    );
  }
}

Widget _switcher(BuildContext context, Widget child) {
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  final duration = reduceMotion
      ? AppMotion.reducedFallback
      : AppMotion.sectionSwitch;
  return AnimatedSwitcher(
    duration: duration,
    switchInCurve: Curves.easeOut,
    switchOutCurve: Curves.easeIn,
    transitionBuilder: (c, anim) {
      if (reduceMotion) {
        return FadeTransition(opacity: anim, child: c);
      }
      return FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(anim),
          child: c,
        ),
      );
    },
    child: child,
  );
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(insightsRangeProvider);
    final analysis = ref.watch(analysisProvider);
    final patterns = ref.watch(patternsProvider);
    final timeline = ref.watch(recurrenceTimelineProvider);
    final settings = ref.watch(settingsProvider);
    return analysis.when(
      skipLoadingOnReload: true,
      loading: () => const InsightsSkeleton(),
      error: (e, _) =>
          ErrorBox(e, onRetry: () => ref.invalidate(analysisProvider)),
      data: (data) {
        final currency = settings.value?.currencyCode ?? '';
        return _switcher(
          context,
          _OverviewBody(
            key: ValueKey(range),
            range: range,
            analysis: data,
            currency: currency,
            patterns: patterns.valueOrNull ?? const [],
            timeline: timeline.valueOrNull ?? const [],
          ),
        );
      },
    );
  }
}

class _OverviewBody extends ConsumerWidget {
  const _OverviewBody({
    super.key,
    required this.range,
    required this.analysis,
    required this.currency,
    required this.patterns,
    required this.timeline,
  });

  final DateRange range;
  final AnalysisCharts analysis;
  final String currency;
  final List<Pattern> patterns;
  final List<RecurrenceOccurrence> timeline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final aggregation = computeAggregation(range);
    final trend = aggregateAmountPerDay(analysis.spentPerDay, aggregation);
    final trendTitle = switch (aggregation) {
      Aggregation.daily => 'Daily Spending',
      Aggregation.weekly => 'Weekly Spending',
      Aggregation.monthly => 'Monthly Spending',
    };
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(analysisProvider);
        ref.invalidate(insightsIncomeProvider);
        ref.invalidate(patternsProvider);
        ref.invalidate(recurrenceTimelineProvider);
        await ref.read(analysisProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Income',
                  amount:
                      ref.watch(insightsIncomeProvider).valueOrNull ??
                      Decimal.zero,
                  currency: currency,
                  background: palette.incomeBg,
                  accent: palette.positiveText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Expenses',
                  amount: analysis.total,
                  currency: currency,
                  background: palette.expenseBg,
                  accent: palette.negativeText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          CategoryDonut(
            categories: analysis.categories,
            total: analysis.total,
            currency: currency,
          ),
          const SizedBox(height: 20),
          SparklineChart(data: trend, title: trendTitle, currency: currency),
          const SizedBox(height: 20),
          const SectionHeader('Worth a closer look'),
          const SizedBox(height: 8),
          PatternPreviewList(patterns: patterns.take(3).toList()),
          const SizedBox(height: 20),
          const SectionHeader('Coming up'),
          const SizedBox(height: 8),
          RecurringSection(
            next: analysis.nextRecurringTransactions,
            timeline: timeline,
            currency: currency,
          ),
        ],
      ),
    );
  }
}

class _AnalysisTab extends ConsumerWidget {
  const _AnalysisTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(insightsRangeProvider);
    final analysis = ref.watch(analysisProvider);
    final timeline = ref.watch(recurrenceTimelineProvider);
    final settings = ref.watch(settingsProvider);
    return analysis.when(
      skipLoadingOnReload: true,
      loading: () => const InsightsSkeleton(),
      error: (e, _) =>
          ErrorBox(e, onRetry: () => ref.invalidate(analysisProvider)),
      data: (data) {
        final currency = settings.value?.currencyCode ?? '';
        return _switcher(
          context,
          _AnalysisBody(
            key: ValueKey(range),
            range: range,
            analysis: data,
            currency: currency,
            timeline: timeline.valueOrNull ?? const [],
          ),
        );
      },
    );
  }
}

class _AnalysisBody extends ConsumerStatefulWidget {
  const _AnalysisBody({
    super.key,
    required this.range,
    required this.analysis,
    required this.currency,
    required this.timeline,
  });

  final DateRange range;
  final AnalysisCharts analysis;
  final String currency;
  final List<RecurrenceOccurrence> timeline;

  @override
  ConsumerState<_AnalysisBody> createState() => _AnalysisBodyState();
}

class _AnalysisBodyState extends ConsumerState<_AnalysisBody> {
  bool _showHeatmap = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.analysis;
    final currency = widget.currency;
    final range = widget.range;
    final previous = range.previousPeriod();
    final currentLabel = formatPeriodLabel(range.from, range.to);
    final previousLabel = formatPeriodLabel(previous.from, previous.to);
    final isShort = computeBucket(range) == DateRangeBucket.short;
    final aggregation = computeAggregation(range);
    final trend = aggregateAmountPerDay(data.spentPerDay, aggregation);
    final prevAverage = _average(data.spentPerDayLastPeriod);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(analysisProvider);
        ref.invalidate(recurrenceTimelineProvider);
        await ref.read(analysisProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SectionHeader('At a glance'),
          const SizedBox(height: 8),
          QuickStatsCard(stats: data.quickStats, currency: currency),
          const SizedBox(height: 20),
          CategoryDonut(
            categories: data.categories,
            total: data.total,
            currency: currency,
          ),
          const SizedBox(height: 20),
          CategoryComparisonBar(
            current: data.categories,
            previous: data.categoriesLastPeriod,
            currency: currency,
            currentLabel: currentLabel,
            previousLabel: previousLabel,
          ),
          const SizedBox(height: 20),
          if (isShort) ...[
            Row(
              children: [
                const Expanded(child: SectionHeader('Spending Over Time')),
                _ViewToggle(
                  showHeatmap: _showHeatmap,
                  onChanged: (v) => setState(() => _showHeatmap = v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _switcher(
              context,
              _showHeatmap
                  ? SpendingHeatmap(
                      key: const ValueKey('heatmap'),
                      days: data.spentPerDay,
                      currency: currency,
                    )
                  : TrendChart(
                      key: const ValueKey('trend'),
                      data: trend,
                      previousAverage: prevAverage,
                      currency: currency,
                      previousLabel: previousLabel,
                    ),
            ),
          ] else ...[
            const SectionHeader('Spending Over Time'),
            const SizedBox(height: 8),
            TrendChart(
              data: trend,
              previousAverage: prevAverage,
              currency: currency,
              previousLabel: previousLabel,
            ),
          ],
          const SizedBox(height: 20),
          const SectionHeader('Coming up'),
          const SizedBox(height: 8),
          RecurringSection(
            next: data.nextRecurringTransactions,
            timeline: widget.timeline,
            currency: currency,
          ),
        ],
      ),
    );
  }

  Decimal _average(List<AmountPerDay> days) {
    if (days.isEmpty) return Decimal.zero;
    final sum = days.fold(Decimal.zero, (a, d) => a + d.amount);
    return (sum / Decimal.fromInt(days.length)).toDecimal(
      scaleOnInfinitePrecision: 2,
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.showHeatmap, required this.onChanged});

  final bool showHeatmap;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.tile,
        borderRadius: AppRadii.pill,
      ),
      child: Row(
        children: [
          _seg(context, palette, 'Chart', !showHeatmap, () {
            if (showHeatmap) {
              HapticFeedback.selectionClick();
              onChanged(false);
            }
          }),
          _seg(context, palette, 'Heatmap', showHeatmap, () {
            if (!showHeatmap) {
              HapticFeedback.selectionClick();
              onChanged(true);
            }
          }),
        ],
      ),
    );
  }

  Widget _seg(
    BuildContext context,
    AppColors palette,
    String label,
    bool on,
    VoidCallback onTap,
  ) {
    final duration = MediaQuery.of(context).disableAnimations
        ? AppMotion.reducedFallback
        : AppMotion.chip;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: duration,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? palette.accentFill : Colors.transparent,
          borderRadius: AppRadii.pill,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: on ? Colors.white : palette.muted,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _PatternsTab extends ConsumerWidget {
  const _PatternsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(patternPeriodProvider);
    final patterns = ref.watch(patternsProvider);
    return patterns.when(
      skipLoadingOnReload: true,
      loading: () => const InsightsSkeleton(),
      error: (e, _) =>
          ErrorBox(e, onRetry: () => ref.invalidate(patternsProvider)),
      data: (data) => _switcher(
        context,
        _PatternsBody(key: ValueKey(period), patterns: data, period: period),
      ),
    );
  }
}

class _PatternsBody extends ConsumerWidget {
  const _PatternsBody({
    super.key,
    required this.patterns,
    required this.period,
  });

  final List<Pattern> patterns;
  final PatternPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(patternsProvider);
        await ref.read(patternsProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          PatternStatCards(patterns: patterns),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: SectionHeader('Spending patterns')),
              const _AnalyzeButton(),
            ],
          ),
          const SizedBox(height: 12),
          _PeriodChips(active: period),
          const SizedBox(height: 12),
          PatternList(patterns: patterns),
        ],
      ),
    );
  }
}

/// Refreshes the provider, which runs detection for the selected period.
class _AnalyzeButton extends ConsumerStatefulWidget {
  const _AnalyzeButton();

  @override
  ConsumerState<_AnalyzeButton> createState() => _AnalyzeButtonState();
}

class _AnalyzeButtonState extends ConsumerState<_AnalyzeButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      ref.invalidate(patternsProvider);
      await ref.read(patternsProvider.future);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Patterns updated')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return FilledButton.icon(
      onPressed: _busy ? null : _run,
      style: FilledButton.styleFrom(
        backgroundColor: palette.accentFill,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.pill),
      ),
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.refresh_rounded, size: 16),
      label: Text(_busy ? 'Analyzing…' : 'Analyze'),
    );
  }
}

/// A single compact trigger, not a second pill row — the screen-level
/// [_DateRangeBar] already renders a period selector, so stacking a duplicate
/// row of the same options directly under it just repeated the choice.
class _PeriodChips extends ConsumerWidget {
  const _PeriodChips({required this.active});

  final PatternPeriod active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return GestureDetector(
      onTap: () async {
        final picked = await showPickerBottomSheet<PatternPeriod>(
          context: context,
          title: 'Range',
          items: PatternPeriod.values,
          labelBuilder: _label,
          selectedItem: active,
        );
        if (picked != null && picked != active) {
          HapticFeedback.selectionClick();
          ref.read(patternPeriodProvider.notifier).state = picked;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: palette.tile,
          borderRadius: AppRadii.medium,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Range: ${_label(active)}',
              style: TextStyle(
                color: palette.ink,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: palette.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _label(PatternPeriod p) => switch (p) {
    PatternPeriod.all => 'All time',
    PatternPeriod.days30 => 'Last 30 days',
    PatternPeriod.days90 => 'Last 90 days',
    PatternPeriod.months12 => 'Last 12 months',
  };
}
