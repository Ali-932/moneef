import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/analysis.dart';
import '../../models/pattern.dart';
import '../../models/recurrence_occurrence.dart';
import '../../theme.dart';
import '../common/design.dart';
import '../../utils/date_range.dart';
import '../../utils/errors.dart';
import '../../utils/mdi.dart';
import '../../utils/format.dart';
import '../common/staggered_animated_item.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Text(
      title,
      style: TextStyle(
        color: palette.ink,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    );
  }
}

class EmptyBox extends StatelessWidget {
  const EmptyBox(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: AppRadii.large,
      ),
      child: Center(
        child: Text(message, style: TextStyle(color: palette.muted)),
      ),
    );
  }
}

/// Displays a user-facing error message and a Retry CTA.
/// Pass the raw caught error — it is cleaned through [userMessage].
class ErrorBox extends StatelessWidget {
  const ErrorBox(this.error, {super.key, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              userMessage(error),
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.ink, fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: TextStyle(
                    color: palette.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.amount,
    required this.currency,
    required this.background,
    required this.accent,
  });
  final String label;
  final Decimal amount;
  final String currency;
  final Color background;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.palette.card,
      borderRadius: AppRadii.large,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              label == 'Income'
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              size: 16,
              color: accent,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: context.palette.muted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        MoneyText(formatMoney(amount, currency), size: 21),
      ],
    ),
  );
}

class SparklineChart extends StatelessWidget {
  const SparklineChart({
    super.key,
    required this.data,
    required this.title,
    required this.currency,
  });

  final List<AggregatedPeriod> data;
  final String title;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (data.isEmpty) return const EmptyBox('No trend data.');
    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(
        FlSpot(
          i.toDouble(),
          (Decimal.tryParse(data[i].amount) ?? Decimal.zero).toDouble(),
        ),
      );
    }
    var maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2;
    if (maxY <= 0) maxY = 1.0;
    final step = (data.length / 4).ceil().clamp(1, data.length);

    // Build a one-line key finding for screen readers.
    final topSpot = spots.reduce((a, b) => a.y >= b.y ? a : b);
    final topLabel = data[topSpot.x.toInt()].label;
    final semanticLabel =
        '$title — peak: $topLabel ${formatMoney(Decimal.parse(data[topSpot.x.toInt()].amount), currency)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: AppRadii.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: palette.ink,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Peak: $topLabel · ${formatMoney(Decimal.parse(data[topSpot.x.toInt()].amount), currency)}',
            style: TextStyle(color: palette.muted, fontSize: 11),
          ),
          const SizedBox(height: 20),
          Semantics(
            label: semanticLabel,
            child: SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 3,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: palette.divider,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: step.toDouble(),
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 ||
                              idx >= data.length ||
                              idx % step != 0) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              data[idx].label,
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: palette.primary,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: palette.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                        final amount = Decimal.parse(data[s.spotIndex].amount);
                        return LineTooltipItem(
                          '${data[s.spotIndex].detailLabel ?? data[s.spotIndex].label}\n${formatMoney(amount, currency)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : AppMotion.sectionSwitch,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single stat cell used inside [QuickStatsCard] and [PatternStatCards].
/// Replaces both the old `_StatCell` (tile background, grid layout) and
/// `_SimpleStatCard` (card background, row layout) — callers choose the
/// background and value size via [background] and [valueFontSize].
class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    this.background,
    this.valueFontSize = 14,
    this.borderRadius = AppRadii.medium,
  });

  final String label;
  final String value;
  // null means "resolve from palette.tile at build time"
  final Color? background;
  final double valueFontSize;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background ?? palette.tile,
        borderRadius: borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: palette.muted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.ink,
              fontWeight: FontWeight.w800,
              fontSize: valueFontSize,
            ),
          ),
        ],
      ),
    );
  }
}

class QuickStatsCard extends StatelessWidget {
  const QuickStatsCard({
    super.key,
    required this.stats,
    required this.currency,
  });
  final QuickStats stats;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget stat(String label, String value) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: p.muted, fontSize: 12)),
            const SizedBox(height: 6),
            MoneyText(value, size: 21),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(color: p.card, borderRadius: AppRadii.large),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stat(
                'Savings rate',
                '${stats.savingsRate.toDouble().toStringAsFixed(1)}%',
              ),
              const SizedBox(width: 16),
              stat('Transactions', '${stats.transactionCount}'),
            ],
          ),
          const Divider(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stat(
                'Largest transaction',
                formatMoney(stats.biggestTransaction.amount, currency),
              ),
              const SizedBox(width: 16),
              stat(
                'Average transaction',
                formatMoney(stats.avgTransaction, currency),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CategoryDonut extends StatefulWidget {
  const CategoryDonut({
    super.key,
    required this.categories,
    required this.total,
    required this.currency,
  });
  final List<CategorySummary> categories;
  final Decimal total;
  final String currency;
  @override
  State<CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends State<CategoryDonut> {
  int? _selectedId;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final categories =
        widget.categories.where((c) => c.totalAmount > Decimal.zero).toList()
          ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    if (categories.isEmpty || widget.total <= Decimal.zero) {
      return const EmptyBox('Your spending breakdown will appear here.');
    }
    final display = categories.length <= 6
        ? categories
        : [
            ...categories.take(5),
            CategorySummary(
              categoryId: -1,
              categoryName: 'Other',
              totalAmount: categories
                  .skip(5)
                  .fold(Decimal.zero, (a, c) => a + c.totalAmount),
              percentage: Decimal.zero,
              color: '#9AA1AE',
            ),
          ];
    CategorySummary? selected;
    for (final c in display) {
      if (c.categoryId == _selectedId) selected = c;
    }
    final selectedShare = selected == null
        ? null
        : (selected.totalAmount / widget.total).toDouble() * 100;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.sectionSwitch;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: p.card, borderRadius: AppRadii.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Where your money went'),
          const SizedBox(height: 20),
          Row(
            children: [
              Semantics(
                label:
                    'Spending distribution. Select a category below for its share.',
                child: SizedBox(
                  width: 112,
                  height: 112,
                  child: PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      centerSpaceRadius: 40,
                      sectionsSpace: 4,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (event is! FlTapUpEvent) return;
                          final index =
                              response?.touchedSection?.touchedSectionIndex ??
                              -1;
                          if (index >= 0 && index < display.length) {
                            setState(
                              () => _selectedId =
                                  display[index].categoryId == _selectedId
                                  ? null
                                  : display[index].categoryId,
                            );
                          }
                        },
                      ),
                      sections: [
                        for (final c in display)
                          PieChartSectionData(
                            value: c.totalAmount.toDouble(),
                            color: _hexToColor(c.color) ?? p.primary,
                            radius: c.categoryId == _selectedId ? 18 : 13,
                            showTitle: false,
                          ),
                      ],
                    ),
                    duration: duration,
                  ),
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: AnimatedSwitcher(
                  duration: duration,
                  child: Column(
                    key: ValueKey(selected?.categoryId),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected?.categoryName ?? 'Total spent',
                        style: TextStyle(color: p.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 5),
                      MoneyText(
                        formatMoney(
                          selected?.totalAmount ?? widget.total,
                          widget.currency,
                        ),
                        size: 24,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        selectedShare == null
                            ? '${categories.length} categories'
                            : '${selectedShare.toStringAsFixed(1)}% of spending',
                        style: TextStyle(color: p.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (final c in display)
            Semantics(
              selected: c.categoryId == _selectedId,
              button: true,
              child: InkWell(
                borderRadius: AppRadii.small,
                onTap: () => setState(
                  () => _selectedId = _selectedId == c.categoryId
                      ? null
                      : c.categoryId,
                ),
                child: AnimatedContainer(
                  duration: duration,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.categoryId == _selectedId
                        ? p.tile
                        : Colors.transparent,
                    borderRadius: AppRadii.small,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _hexToColor(c.color) ?? p.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.categoryName,
                          style: TextStyle(
                            fontSize: 12,
                            color: p.ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatMoney(c.totalAmount, widget.currency),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${((c.totalAmount / widget.total).toDouble() * 100).toStringAsFixed(0)}%',
                          textAlign: TextAlign.end,
                          style: TextStyle(fontSize: 11, color: p.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CategoryComparisonBar extends StatelessWidget {
  const CategoryComparisonBar({
    super.key,
    required this.current,
    required this.previous,
    required this.currency,
    required this.currentLabel,
    required this.previousLabel,
  });

  final List<CategorySummary> current;
  final List<CategorySummary> previous;
  final String currency;
  final String currentLabel;
  final String previousLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final names = <String>{
      for (final c in current) c.categoryName,
      for (final c in previous) c.categoryName,
    }.toList();
    if (names.isEmpty) return const EmptyBox('No comparison data.');
    final currentMap = {for (final c in current) c.categoryName: c.totalAmount};
    final previousMap = {
      for (final c in previous) c.categoryName: c.totalAmount,
    };
    final groups = <BarChartGroupData>[];
    var maxY = 0.0;
    for (var i = 0; i < names.length; i++) {
      final cur = (currentMap[names[i]] ?? Decimal.zero).toDouble();
      final prev = (previousMap[names[i]] ?? Decimal.zero).toDouble();
      if (cur > maxY) maxY = cur;
      if (prev > maxY) maxY = prev;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: cur,
              color: palette.primary,
              width: 10,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              toY: prev,
              color: palette.muted,
              width: 10,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }
    final displayMaxY = maxY <= 0 ? 1.0 : maxY * 1.1;

    // Build semantic label: top category with largest change.
    final semanticLabel =
        'Category comparison: $currentLabel vs $previousLabel. '
        '${names.isNotEmpty ? "Categories: ${names.join(', ')}" : ""}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: AppRadii.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending — $currentLabel vs $previousLabel',
            style: TextStyle(
              color: palette.ink,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: semanticLabel,
            child: SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= names.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: SizedBox(
                              width: 48,
                              child: Text(
                                names[idx],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.min || value == meta.max) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              _compactAmount(value, currency),
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  maxY: displayMaxY,
                  barGroups: groups,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final name = names[group.x];
                        final label = rodIndex == 0
                            ? currentLabel
                            : previousLabel;
                        final amount = Decimal.parse(rod.toY.toString());
                        return BarTooltipItem(
                          '$name\n$label\n${formatMoney(amount, currency)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : AppMotion.sectionSwitch,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: palette.primary, label: currentLabel),
              const SizedBox(width: 16),
              _LegendDot(color: palette.muted, label: previousLabel),
            ],
          ),
        ],
      ),
    );
  }

  /// Formats a raw double as a compact currency label for the Y-axis.
  String _compactAmount(double value, String currency) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: AppRadii.small),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: palette.muted, fontSize: 11)),
      ],
    );
  }
}

class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.data,
    required this.previousAverage,
    required this.currency,
    required this.previousLabel,
  });

  final List<AggregatedPeriod> data;
  final Decimal previousAverage;
  final String currency;
  final String previousLabel;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant TrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _selectedIndex = null;
  }

  void _select(int? index) {
    if (_selectedIndex != index) setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final previousAverage = widget.previousAverage;
    final currency = widget.currency;
    final previousLabel = widget.previousLabel;
    final palette = context.palette;
    if (data.isEmpty) return const EmptyBox('No trend data.');
    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(
        FlSpot(
          i.toDouble(),
          (Decimal.tryParse(data[i].amount) ?? Decimal.zero).toDouble(),
        ),
      );
    }
    var maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final avgY = previousAverage.toDouble();
    if (maxY < avgY) maxY = avgY;
    final displayMaxY = maxY <= 0 ? 1.0 : maxY * 1.1;
    final step = (data.length / 4).ceil().clamp(1, data.length);

    // Semantic: peak period vs previous average.
    final peakSpot = spots.reduce((a, b) => a.y >= b.y ? a : b);
    final peakLabel = data[peakSpot.x.toInt()].label;
    final selected = data[_selectedIndex ?? peakSpot.x.toInt()];
    final semanticLabel =
        'Spending trend, peak: $peakLabel ${formatMoney(Decimal.parse(data[peakSpot.x.toInt()].amount), currency)}, '
        'previous period average ${formatMoney(previousAverage, currency)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: AppRadii.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SpendingDetail(
            label:
                '${_selectedIndex == null ? 'Peak · ' : ''}${selected.detailLabel ?? selected.label}',
            amount: Decimal.parse(selected.amount),
            currency: currency,
          ),
          const SizedBox(height: 20),
          Semantics(
            label: semanticLabel,
            onIncrease: () =>
                _select(((_selectedIndex ?? 0) + 1).clamp(0, data.length - 1)),
            onDecrease: () =>
                _select(((_selectedIndex ?? 0) - 1).clamp(0, data.length - 1)),
            child: SizedBox(
              key: const ValueKey('spending-trend-plot'),
              height: 200,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slotWidth = constraints.maxWidth / data.length;
                  final barWidth = (slotWidth * 0.55).clamp(2.0, 18.0);
                  return BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: displayMaxY / 3,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: palette.divider,
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 ||
                                  idx >= data.length ||
                                  idx % step != 0) {
                                return const SizedBox.shrink();
                              }
                              return SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  data[idx].label,
                                  style: TextStyle(
                                    color: palette.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      maxY: displayMaxY,
                      barGroups: [
                        for (var i = 0; i < data.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: spots[i].y,
                                color:
                                    _selectedIndex == null ||
                                        _selectedIndex == i
                                    ? palette.primary
                                    : palette.primary.withValues(alpha: 0.3),
                                width: barWidth,
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: displayMaxY,
                                  color: Colors.transparent,
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ],
                          ),
                      ],
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: avgY,
                            color: palette.negativeText,
                            strokeWidth: 1.5,
                            dashArray: const [5, 5],
                          ),
                        ],
                      ),
                      barTouchData: BarTouchData(
                        handleBuiltInTouches: false,
                        allowTouchBarBackDraw: true,
                        touchExtraThreshold: EdgeInsets.symmetric(
                          horizontal: (slotWidth - barWidth) / 2,
                        ),
                        touchCallback: (event, response) {
                          if (event is FlPointerExitEvent) {
                            _select(null);
                          } else if (event.isInterestedForInteractions &&
                              response?.spot != null) {
                            _select(response!.spot!.touchedBarGroupIndex);
                          }
                        },
                      ),
                    ),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : AppMotion.sectionSwitch,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _ChartExploreHint(),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 16,
                height: 2,
                margin: const EdgeInsets.only(top: 8, right: 8),
                color: palette.negativeText,
              ),
              Expanded(
                child: Text(
                  'Previous daily average · ${formatMoney(previousAverage, currency)}\n$previousLabel',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SpendingHeatmap extends StatefulWidget {
  const SpendingHeatmap({
    super.key,
    required this.days,
    required this.currency,
  });

  final List<AmountPerDay> days;
  final String currency;

  @override
  State<SpendingHeatmap> createState() => _SpendingHeatmapState();
}

class _SpendingHeatmapState extends State<SpendingHeatmap> {
  DateTime? _selectedDate;

  @override
  void didUpdateWidget(covariant SpendingHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days != widget.days) _selectedDate = null;
  }

  void _select(AmountPerDay day) {
    if (_selectedDate != day.date) setState(() => _selectedDate = day.date);
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    final currency = widget.currency;
    final palette = context.palette;
    if (days.isEmpty) return const EmptyBox('No daily data.');
    final max = days.map((d) => d.amount).reduce((a, b) => a > b ? a : b);
    final topDay = days.reduce((a, b) => a.amount >= b.amount ? a : b);
    final selected = days.firstWhere(
      (d) => d.date == _selectedDate,
      orElse: () => topDay,
    );
    final months = <DateTime, List<AmountPerDay>>{};
    for (final day in days) {
      final month = DateTime(day.date.year, day.date.month);
      months.putIfAbsent(month, () => []).add(day);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: AppRadii.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SpendingDetail(
            label:
                '${_selectedDate == null ? 'Peak · ' : ''}${DateFormat('MMM d, y').format(selected.date)}',
            amount: selected.amount,
            currency: currency,
          ),
          for (final month in months.entries) ...[
            const SizedBox(height: 20),
            _HeatmapMonth(
              month: month.key,
              days: month.value,
              maxAmount: max,
              selectedDate: _selectedDate,
              currency: currency,
              onSelect: _select,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Less',
                style: TextStyle(color: palette.muted, fontSize: 11),
              ),
              const SizedBox(width: 8),
              for (var i = 0; i < 5; i++)
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      palette.tile,
                      palette.primary,
                      i / 4 * 0.55,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              const SizedBox(width: 4),
              Text(
                'More',
                style: TextStyle(color: palette.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _ChartExploreHint(),
        ],
      ),
    );
  }
}

class _SpendingDetail extends StatelessWidget {
  const _SpendingDetail({
    required this.label,
    required this.amount,
    required this.currency,
  });

  final String label;
  final Decimal amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        key: const ValueKey('spending-selection'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: context.palette.muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(amount, currency),
            style: TextStyle(
              color: context.palette.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartExploreHint extends StatelessWidget {
  const _ChartExploreHint();

  @override
  Widget build(BuildContext context) => Text(
    'Hover or hold and slide to explore',
    style: TextStyle(color: context.palette.muted, fontSize: 11),
  );
}

class _HeatmapMonth extends StatelessWidget {
  const _HeatmapMonth({
    required this.month,
    required this.days,
    required this.maxAmount,
    required this.selectedDate,
    required this.currency,
    required this.onSelect,
  });

  final DateTime month;
  final List<AmountPerDay> days;
  final Decimal maxAmount;
  final DateTime? selectedDate;
  final String currency;
  final ValueChanged<AmountPerDay> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final byDay = {for (final d in days) d.date.day: d};
    final first = byDay.keys.reduce((a, b) => a < b ? a : b);
    final last = byDay.keys.reduce((a, b) => a > b ? a : b);
    final leading = DateTime(month.year, month.month, first).weekday - 1;
    final count = leading + last - first + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('MMMM y').format(month),
          style: TextStyle(
            color: palette.ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final label in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(color: palette.muted, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 4.0;
            final width = (constraints.maxWidth - gap * 6) / 7;
            final height = (MediaQuery.textScalerOf(context).scale(12) + 24)
                .clamp(44.0, double.infinity);
            void selectAt(Offset position) {
              if (position.dx < 0 ||
                  position.dx >= constraints.maxWidth ||
                  position.dy < 0) {
                return;
              }
              final column = (position.dx / (width + gap)).floor().clamp(0, 6);
              final row = (position.dy / (height + gap)).floor();
              final day = byDay[first + row * 7 + column - leading];
              if (day != null) onSelect(day);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart: (details) => selectAt(details.localPosition),
              onLongPressMoveUpdate: (details) =>
                  selectAt(details.localPosition),
              child: GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: height,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                ),
                itemCount: count,
                itemBuilder: (context, index) {
                  final day = byDay[first + index - leading];
                  if (index < leading || day == null) {
                    return const SizedBox.shrink();
                  }
                  final ratio = maxAmount == Decimal.zero
                      ? 0.0
                      : (day.amount / maxAmount).toDouble().clamp(0.0, 1.0);
                  final selected = day.date == selectedDate;
                  final dateLabel = DateFormat('MMM d, y').format(day.date);
                  return Semantics(
                    label:
                        '$dateLabel, ${formatMoney(day.amount, currency)} spent',
                    onTap: () => onSelect(day),
                    selected: selected,
                    button: true,
                    excludeSemantics: true,
                    child: MouseRegion(
                      onEnter: (_) => onSelect(day),
                      child: Material(
                        key: ValueKey(
                          'spending-day-${DateFormat('yyyy-MM-dd').format(day.date)}',
                        ),
                        color: Color.lerp(
                          palette.tile,
                          palette.primary,
                          ratio * 0.55,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadii.small,
                          side: selected
                              ? BorderSide(color: palette.primary, width: 2)
                              : BorderSide.none,
                        ),
                        child: InkWell(
                          borderRadius: AppRadii.small,
                          onTap: () => onSelect(day),
                          onFocusChange: (focused) {
                            if (focused) onSelect(day);
                          },
                          child: Center(
                            child: Text(
                              day.date.day.toString(),
                              style: TextStyle(
                                color: palette.ink,
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class PatternPreviewList extends StatelessWidget {
  const PatternPreviewList({super.key, required this.patterns});

  final List<Pattern> patterns;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (patterns.isEmpty) return const EmptyBox('No patterns found.');
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: AppRadii.large,
      ),
      child: Column(
        children: [
          for (var i = 0; i < patterns.length; i++) ...[
            _PatternTile(pattern: patterns[i]),
            if (i < patterns.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class PatternList extends StatelessWidget {
  const PatternList({super.key, required this.patterns});

  final List<Pattern> patterns;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (patterns.isEmpty) return const EmptyBox('No patterns found.');
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: AppRadii.large,
      ),
      child: Column(
        children: [
          for (var i = 0; i < patterns.length; i++) ...[
            StaggeredAnimatedItem(
              index: i,
              shouldStagger: true,
              child: _PatternTile(pattern: patterns[i]),
            ),
            if (i < patterns.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _PatternTile extends StatelessWidget {
  const _PatternTile({required this.pattern});

  final Pattern pattern;

  void _showDetail(
    BuildContext context,
    AppColors palette,
    Color bg,
    Color fg,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: AppRadii.medium,
                    ),
                    alignment: Alignment.center,
                    child: Icon(mdiIconData(pattern.icon), size: 20, color: fg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pattern.name,
                      style: TextStyle(
                        color: palette.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${pattern.finalScore.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: palette.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                pattern.description,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = _hexToColor(pattern.color) ?? p.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDetail(context, p, p.primarySoft, p.primary),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  QuietIcon(
                    icon: mdiIconData(pattern.icon),
                    color: color,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pattern.name,
                      style: TextStyle(
                        color: p.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, size: 18, color: p.muted),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                pattern.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.muted, fontSize: 12, height: 1.55),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Pattern score',
                    style: TextStyle(color: p.muted, fontSize: 10),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 64,
                    child: LinearProgressIndicator(
                      value: (pattern.finalScore / 100).clamp(0, 1),
                      minHeight: 4,
                      color: p.primary,
                      backgroundColor: p.primarySoft,
                      borderRadius: AppRadii.pill,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${pattern.finalScore.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: p.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PatternStatCards extends StatelessWidget {
  const PatternStatCards({super.key, required this.patterns});

  final List<Pattern> patterns;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final topScore = patterns.isEmpty ? 0.0 : patterns.first.finalScore;
    return Row(
      children: [
        Expanded(
          child: _StatCell(
            label: 'Patterns found',
            value: patterns.length.toString(),
            background: palette.card,
            valueFontSize: 22,
            borderRadius: AppRadii.large,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCell(
            label: 'Top score',
            value: '${topScore.toStringAsFixed(0)}%',
            background: palette.card,
            valueFontSize: 22,
            borderRadius: AppRadii.large,
          ),
        ),
      ],
    );
  }
}

class RecurringSection extends StatelessWidget {
  const RecurringSection({
    super.key,
    required this.next,
    required this.timeline,
    required this.currency,
  });

  final List<NextRecurringTransaction> next;
  final List<RecurrenceOccurrence> timeline;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (next.isEmpty && timeline.isEmpty) {
      return const EmptyBox('No upcoming recurring payments.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (timeline.isNotEmpty) ...[
          SizedBox(
            height: 104 * MediaQuery.textScalerOf(context).scale(13) / 13,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: timeline.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _TimelineCard(occurrence: timeline[i]),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (next.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: AppRadii.large,
            ),
            child: Column(
              children: [
                for (var i = 0; i < next.length; i++) ...[
                  _NextRow(item: next[i], currency: currency),
                  if (i < next.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.occurrence});

  final RecurrenceOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isExpense = occurrence.type == 'expense';
    return Container(
      width: 200 * MediaQuery.textScalerOf(context).scale(13) / 13,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: AppRadii.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            occurrence.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.ink,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(
              isExpense ? -occurrence.amount : occurrence.amount,
              occurrence.currencyCode,
              signed: true,
            ),
            style: TextStyle(
              color: isExpense ? palette.negativeText : palette.positiveText,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          Text(
            formatDateLong(occurrence.date),
            style: TextStyle(color: palette.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _NextRow extends StatelessWidget {
  const _NextRow({required this.item, required this.currency});

  final NextRecurringTransaction item;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.ink,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(-item.amount, currency),
                style: TextStyle(
                  color: palette.negativeText,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                formatDateLong(item.date),
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color? _hexToColor(String hex) {
  if (hex.isEmpty) return null;
  final h = hex.replaceAll('#', '');
  if (h.length != 6) return null;
  return Color(int.parse('FF$h', radix: 16));
}
