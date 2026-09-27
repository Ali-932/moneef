import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/dashboard.dart';
import '../models/transaction.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/common/skeletons.dart';
import '../widgets/common/design.dart';
import '../widgets/common/staggered_animated_item.dart';
import '../widgets/transaction_row.dart';
import 'backups_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);
    final period = ref.watch(dashboardPeriodProvider);
    final reducedMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      appBar: PageHeading(
        title: 'Overview',
        subtitle: 'Your money, at a glance',
        action: IconButton(
          tooltip: 'Your profile',
          onPressed: () => context.go('/profile'),
          icon: Icon(
            Icons.account_circle_outlined,
            color: context.palette.primary,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: _PeriodSelector(
              value: period,
              onChanged: (v) =>
                  ref.read(dashboardPeriodProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(dashboardProvider);
                await ref.read(dashboardProvider.future);
              },
              child: async.when(
                skipLoadingOnReload: true,
                loading: () => const DashboardSkeleton(),
                error: (e, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 100),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userMessage(e),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.palette.muted),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () =>
                                  ref.invalidate(dashboardProvider),
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                data: (s) => AnimatedSwitcher(
                  duration: reducedMotion
                      ? AppMotion.reducedFallback
                      : AppMotion.sectionSwitch,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: reducedMotion
                      ? (child, animation) =>
                            FadeTransition(opacity: animation, child: child)
                      : (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.02),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                  child: _DashboardBody(key: ValueKey(period), summary: s),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({super.key, required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        const BackupPrompt(),
        _CashFlow(summary: summary),
        const SizedBox(height: 20),
        _SectionHeader(
          title: 'Top spending',
          actionLabel: 'See all',
          onAction: () => context.go('/insights'),
        ),
        const SizedBox(height: 8),
        _TopCategoriesCard(summary: summary),
        const SizedBox(height: 20),
        _SectionHeader(
          title: 'Recent activity',
          actionLabel: 'See all',
          onAction: () => context.go('/transactions'),
        ),
        const SizedBox(height: 8),
        _RecentList(transactions: summary.recentTransactions.take(5).toList()),
        if (summary.quickStats != null) ...[
          const SizedBox(height: 20),
          _SectionHeader(title: 'In numbers'),
          const SizedBox(height: 8),
          _QuickStatsCard(
            stats: summary.quickStats!,
            currency: summary.currencyCode,
          ),
        ],
        const SizedBox(height: 20),
        _SectionHeader(title: 'Coming up'),
        const SizedBox(height: 8),
        _UpcomingRecurringCard(items: summary.upcomingRecurring),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});
  final DashboardPeriodKind value;
  final ValueChanged<DashboardPeriodKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.tile,
        borderRadius: AppRadii.medium,
      ),
      child: Row(
        children: [
          _seg(
            context,
            'This month',
            value == DashboardPeriodKind.thisMonth,
            () => onChanged(DashboardPeriodKind.thisMonth),
          ),
          _seg(
            context,
            'Last month',
            value == DashboardPeriodKind.lastMonth,
            () => onChanged(DashboardPeriodKind.lastMonth),
          ),
          _seg(
            context,
            'This year',
            value == DashboardPeriodKind.thisYear,
            () => onChanged(DashboardPeriodKind.thisYear),
          ),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, String label, bool on, VoidCallback onTap) {
    final palette = context.palette;
    final duration = MediaQuery.of(context).disableAnimations
        ? AppMotion.reducedFallback
        : AppMotion.chip;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!on) {
            HapticFeedback.selectionClick();
            onTap();
          }
        },
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.emphasized,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: on ? palette.card : Colors.transparent,
            borderRadius: AppRadii.medium,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedDefaultTextStyle(
              duration: duration,
              style: DefaultTextStyle.of(context).style.copyWith(
                color: on ? palette.primary : palette.muted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              child: Text(label, maxLines: 1, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}

class _CashFlow extends StatelessWidget {
  const _CashFlow({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final net = summary.totalIncome - summary.totalExpense;
    final income = summary.totalIncome.toDouble();
    final expense = summary.totalExpense.toDouble();
    final max = income > expense ? income : expense;
    final spent = income > 0 ? expense / income * 100 : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Net cash flow',
                style: TextStyle(color: p.muted, fontSize: 13),
              ),
            ),
            Text(
              formatPeriodLabel(
                summary.period.startDate,
                summary.period.endDate,
              ),
              style: TextStyle(color: p.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        MoneyText(
          formatMoney(net, summary.currencyCode),
          size: 38,
          weight: FontWeight.w800,
        ),
        const SizedBox(height: 8),
        Text(
          net >= Decimal.zero
              ? 'Income left after expenses'
              : 'Expenses above income',
          style: TextStyle(color: p.muted, fontSize: 12),
        ),
        const SizedBox(height: 24),
        _FlowBar(
          label: 'Income',
          amount: formatMoney(summary.totalIncome, summary.currencyCode),
          ratio: max > 0 ? income / max : 0,
          color: p.positiveText,
          icon: Icons.south_west_rounded,
        ),
        const SizedBox(height: 16),
        _FlowBar(
          label: 'Expenses',
          amount: formatMoney(summary.totalExpense, summary.currencyCode),
          ratio: max > 0 ? expense / max : 0,
          color: p.primary,
          icon: Icons.north_east_rounded,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            if (spent != null)
              Text(
                '${spent.toStringAsFixed(0)}% of income spent',
                style: TextStyle(color: p.muted, fontSize: 11),
              ),
            if (summary.quickStats != null)
              Text(
                '${formatMoney(summary.quickStats!.avgDailySpend, summary.currencyCode)} / day',
                style: TextStyle(color: p.muted, fontSize: 11),
              ),
          ],
        ),
      ],
    );
  }
}

class _FlowBar extends StatelessWidget {
  const _FlowBar({
    required this.label,
    required this.amount,
    required this.ratio,
    required this.color,
    required this.icon,
  });
  final String label;
  final String amount;
  final double ratio;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: context.palette.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              amount,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.palette.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 9),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: ratio, end: ratio),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppMotion.sectionSwitch,
        builder: (_, value, __) => LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: 8,
          borderRadius: AppRadii.pill,
          backgroundColor: context.palette.divider,
          color: color,
          semanticsLabel: '$label: $amount',
        ),
      ),
    ],
  );
}

class _QuickStatsCard extends StatelessWidget {
  const _QuickStatsCard({required this.stats, required this.currency});

  final DashboardQuickStats stats;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final top = stats.topCategory;
    final biggest = stats.biggestTransaction;
    final merchant = stats.topMerchant;
    final rows = <(String, String)>[
      ('Transactions', stats.transactionCount.toString()),
      if (top != null)
        (
          'Top category',
          '${top.categoryName} · ${formatMoney(top.totalAmount, currency)}',
        ),
      (
        'Savings rate',
        '${double.parse(stats.savingsRate.toString()).toStringAsFixed(1)}%',
      ),
      if (biggest.name.isNotEmpty)
        (
          'Biggest transaction',
          '${biggest.name} · ${formatMoney(biggest.amount, currency)}',
        ),
      if (merchant.name.isNotEmpty)
        (
          'Top merchant',
          '${merchant.name} · ${formatMoney(merchant.amount, currency)}',
        ),
      ('Avg transaction', formatMoney(stats.avgTransaction, currency)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: AppRadii.large,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rows[i].$1,
                    style: TextStyle(
                      color: palette.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i < rows.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            color: context.palette.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      if (actionLabel != null)
        TextButton(
          onPressed: onAction,
          child: Text(
            actionLabel!,
            style: TextStyle(fontSize: 12, color: context.palette.primary),
          ),
        ),
    ],
  );
}

class _TopCategoriesCard extends StatelessWidget {
  const _TopCategoriesCard({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // This is the period's aggregate, never an estimate from recent rows.
    final top = summary.quickStats?.topCategory;
    if (top == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'Your spending breakdown will appear here.',
          style: TextStyle(color: p.muted),
        ),
      );
    }
    final share = summary.totalExpense > Decimal.zero
        ? (top.totalAmount / summary.totalExpense).toDouble()
        : 0.0;
    return Material(
      color: p.card,
      borderRadius: AppRadii.large,
      child: InkWell(
        borderRadius: AppRadii.large,
        onTap: () => context.go('/insights'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: share.clamp(0, 1),
                        strokeWidth: 5,
                        backgroundColor: p.primarySoft,
                        color: p.primary,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '${(share * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: p.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      top.categoryName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    MoneyText(
                      formatMoney(top.totalAmount, summary.currencyCode),
                      size: 20,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'of total spending',
                      style: TextStyle(color: p.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.transactions});
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: AppRadii.large,
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: palette.primary,
                size: 28,
              ),
              const SizedBox(height: 12),
              Text(
                'Start with your first transaction',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => context.push('/add'),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add transaction'),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: AppRadii.large,
      ),
      child: Column(
        children: [
          for (var i = 0; i < transactions.length; i++) ...[
            StaggeredAnimatedItem(
              key: ValueKey(transactions[i].id),
              index: i,
              shouldStagger: true,
              child: TransactionRow(
                transaction: transactions[i],
                showDate: true,
                onTap: () => GoRouter.of(
                  context,
                ).push('/transactions/${transactions[i].id}'),
              ),
            ),
            if (i < transactions.length - 1)
              const Divider(height: 1, indent: 68),
          ],
        ],
      ),
    );
  }
}

class _UpcomingRecurringCard extends StatelessWidget {
  const _UpcomingRecurringCard({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: AppRadii.large,
        ),
        child: Center(
          child: Text(
            'No upcoming payments.',
            style: TextStyle(color: palette.muted),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: AppRadii.large,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _UpcomingRecurringRow(item: items[i]),
            if (i < items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingRecurringRow extends StatelessWidget {
  const _UpcomingRecurringRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final name = item['name'] as String? ?? '';
    final amountStr = item['amount'] as String? ?? '0';
    final amount = Decimal.tryParse(amountStr) ?? Decimal.zero;
    final dateStr = item['date'] as String?;
    final date = dateStr != null ? DateTime.parse(dateStr) : null;
    final currency = item['currency'] as String? ?? '';

    return Row(
      children: [
        Expanded(
          child: Text(
            name,
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
              formatMoney(-amount, currency),
              style: TextStyle(
                color: palette.negativeText,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            if (date != null)
              Text(
                formatDateTimeShort(date),
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
          ],
        ),
      ],
    );
  }
}
