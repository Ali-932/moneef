import 'package:flutter/material.dart';

import '../../theme.dart';
import 'shimmer.dart';

/// Placeholder mirroring [TransactionRow]: a 44px icon tile, two text lines,
/// and a trailing amount. Used while a transaction list is loading.
class TransactionRowSkeleton extends StatelessWidget {
  const TransactionRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            const ShimmerBox(
              width: 44,
              height: 44,
              borderRadius: AppRadii.medium,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(
                    width: 140,
                    height: 14,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 8),
                  ShimmerBox(
                    width: 80,
                    height: 11,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ShimmerBox(
              width: 56,
              height: 14,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card-wrapped list of [TransactionRowSkeleton]s, matching the rounded
/// card used by the Home "Recent Transactions" block.
class TransactionListSkeleton extends StatelessWidget {
  const TransactionListSkeleton({
    super.key,
    this.itemCount = 5,
    this.carded = true,
  });

  final int itemCount;
  final bool carded;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final column = Column(
      children: [
        for (var i = 0; i < itemCount; i++) ...[
          const TransactionRowSkeleton(),
          if (i < itemCount - 1) const Divider(height: 1, indent: 68),
        ],
      ],
    );
    if (!carded) return Shimmer(child: column);
    return Shimmer(
      child: Container(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: AppRadii.large,
        ),
        child: column,
      ),
    );
  }
}

/// Two side-by-side money cards (Income / Expenses) skeleton.
class MoneyCardsSkeleton extends StatelessWidget {
  const MoneyCardsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Row(
        children: const [
          Expanded(child: _MoneyCardSkeleton()),
          SizedBox(width: 12),
          Expanded(child: _MoneyCardSkeleton()),
        ],
      ),
    );
  }
}

class _MoneyCardSkeleton extends StatelessWidget {
  const _MoneyCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.skeleton,
        borderRadius: AppRadii.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(
            width: 64,
            height: 14,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 8),
          ShimmerBox(
            width: 44,
            height: 10,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 14),
          ShimmerBox(
            width: 96,
            height: 22,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }
}

/// Card of horizontal category bars, matching Home "Top Categories".
class CategoryBarsSkeleton extends StatelessWidget {
  const CategoryBarsSkeleton({super.key, this.rows = 4});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Shimmer(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: AppRadii.large,
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ShimmerBox(
                            width: 100,
                            height: 12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ShimmerBox(
                          width: 48,
                          height: 12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ShimmerBox(
                      height: 6,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Transaction detail screen skeleton: a hero amount card followed by a
/// handful of metadata rows.
class TransactionDetailSkeleton extends StatelessWidget {
  const TransactionDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Shimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.skeleton,
              borderRadius: AppRadii.large,
            ),
            child: Column(
              children: [
                ShimmerBox(
                  width: 140,
                  height: 18,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 12),
                ShimmerBox(
                  width: 180,
                  height: 30,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 10),
                ShimmerBox(
                  width: 110,
                  height: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  ShimmerBox(
                    width: 80,
                    height: 13,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: ShimmerBox(
                      height: 13,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Loading layout mirrors the net cash flow, comparison bars, and activity.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Shimmer(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        Align(
          alignment: Alignment.centerLeft,
          child: ShimmerBox(width: 100, height: 14),
        ),
        SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: ShimmerBox(width: 230, height: 44),
        ),
        SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: ShimmerBox(width: 180, height: 12),
        ),
        SizedBox(height: 28),
        ShimmerBox(height: 18),
        SizedBox(height: 10),
        ShimmerBox(height: 8),
        SizedBox(height: 18),
        ShimmerBox(height: 18),
        SizedBox(height: 10),
        ShimmerBox(height: 8),
        SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: ShimmerBox(width: 200, height: 12),
        ),
        SizedBox(height: 32),
        ShimmerBox(height: 96, borderRadius: AppRadii.large),
        SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: ShimmerBox(width: 120, height: 16),
        ),
        SizedBox(height: 16),
        TransactionListSkeleton(itemCount: 4),
      ],
    ),
  );
}

/// A recurrence's heading, amount, and next date keep fixed vertical positions.
class RecurrenceCardSkeleton extends StatelessWidget {
  const RecurrenceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Shimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: AppRadii.large,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 140, height: 16),
                        const SizedBox(height: 8),
                        ShimmerBox(width: 100, height: 12),
                      ],
                    ),
                  ),
                  const SizedBox(
                    width: 44,
                    child: Center(child: ShimmerBox(width: 20, height: 20)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ShimmerBox(width: 180, height: 24),
            const SizedBox(height: 6),
            ShimmerBox(width: 120, height: 16),
          ],
        ),
      ),
    );
  }
}

/// A list of [RecurrenceCardSkeleton]s matching the recurrences screen list.
class RecurrencesSkeleton extends StatelessWidget {
  const RecurrencesSkeleton({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < itemCount; i++)
          RecurrenceCardSkeleton(key: ValueKey(i)),
      ],
    );
  }
}

/// Two short shimmer rows for a compact settings-card loading state.
/// Used inside profile cards while async data is resolving.
class ProfileCardRowsSkeleton extends StatelessWidget {
  const ProfileCardRowsSkeleton({super.key, this.rows = 2});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows; i++) ...[
            Row(
              children: [
                ShimmerBox(
                  width: 120,
                  height: 13,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ShimmerBox(
                    height: 13,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
            if (i < rows - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Insights screen skeleton: stat cards, category bars, and a chart placeholder.
class InsightsSkeleton extends StatelessWidget {
  const InsightsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Shimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ShimmerBox(height: 44, borderRadius: BorderRadius.circular(999)),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: _MoneyCardSkeleton()),
              SizedBox(width: 12),
              Expanded(child: _MoneyCardSkeleton()),
            ],
          ),
          const SizedBox(height: 24),
          ShimmerBox(
            width: 140,
            height: 15,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 12),
          const CategoryBarsSkeleton(),
          const SizedBox(height: 24),
          ShimmerBox(
            width: 120,
            height: 15,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 12),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: palette.skeleton,
              borderRadius: AppRadii.large,
            ),
          ),
        ],
      ),
    );
  }
}
