import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/recurrence_template.dart';
import '../state/recurrences_controller.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/common/skeletons.dart';
import '../widgets/common/staggered_animated_item.dart';

// ── frequency label map ──────────────────────────────────────────────

const _frequencyLabels = <String, String>{
  'daily': 'Daily',
  'weekly': 'Weekly',
  'bi-weekly': 'Bi-weekly',
  'biweekly': 'Bi-weekly',
  'monthly': 'Monthly',
  'quarterly': 'Quarterly',
  'yearly': 'Yearly',
  'annually': 'Annually',
};

String _frequencyLabel(String raw) =>
    _frequencyLabels[raw.toLowerCase()] ??
    raw.substring(0, 1).toUpperCase() + raw.substring(1);

class RecurrencesScreen extends ConsumerWidget {
  const RecurrencesScreen({super.key});

  Future<void> _addTransaction(BuildContext context, WidgetRef ref) async {
    final saved = await context.push<bool>('/add?recurring=true');
    if (saved == true && context.mounted) {
      ref.invalidate(recurrencesProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final async = ref.watch(recurrencesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recurring payments',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Add recurring payment',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _addTransaction(context, ref),
          ),
        ],
      ),
      body: async.when(
        loading: () => const RecurrencesSkeleton(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              userMessage(e),
              style: TextStyle(color: palette.negativeText),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (items) => _buildBody(context, ref, items),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<RecurrenceTemplate> items,
  ) {
    final palette = context.palette;
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => ref.invalidate(recurrencesProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat_rounded, size: 52, color: palette.muted),
                    const SizedBox(height: 16),
                    Text(
                      'No recurring payments yet',
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add a recurring transaction to track subscriptions and regular bills.',
                      style: TextStyle(color: palette.muted, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => _addTransaction(context, ref),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.accentFill,
                        foregroundColor: palette.card,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadii.medium,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('Add Transaction'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Read the default currency for fallback amount display — settingsProvider
    // is async; use .value so we never block the list on a settings fetch.
    final settingsAsync = ref.watch(settingsProvider);
    final defaultCurrency = settingsAsync.value?.currencyCode;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _headerSummary(items),
              style: TextStyle(
                color: palette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(recurrencesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final r = items[i];
                final typeColor = r.isIncome
                    ? palette.positiveText
                    : palette.negativeText;
                return StaggeredAnimatedItem(
                  key: ValueKey(r.id),
                  index: i,
                  shouldStagger: true,
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: r.isActive
                                          ? palette.ink
                                          : palette.muted,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: r.isIncome
                                              ? 'Income'
                                              : 'Expense',
                                          style: TextStyle(color: typeColor),
                                        ),
                                        TextSpan(
                                          text:
                                              ' · ${_frequencyLabel(r.frequency)}',
                                        ),
                                        if (!r.isActive)
                                          const TextSpan(text: ' · Paused'),
                                      ],
                                    ),
                                    style: TextStyle(
                                      color: palette.muted,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              tooltip: 'Payment actions',
                              icon: Icon(
                                Icons.more_horiz_rounded,
                                color: palette.muted,
                              ),
                              onSelected: (action) {
                                if (action == 'edit') {
                                  context.push(
                                    '/profile/recurrences/${r.id}/edit',
                                  );
                                } else {
                                  _confirmDelete(context, ref, r);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Edit recurring payment'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.delete_outline_rounded,
                                      color: palette.negativeText,
                                    ),
                                    title: Text(
                                      'Delete recurring payment',
                                      style: TextStyle(
                                        color: palette.negativeText,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formatAmount(r, defaultCurrency),
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            color: !r.isActive
                                ? palette.muted
                                : r.isIncome
                                ? palette.positiveText
                                : palette.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            height: 1.25,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          r.nextDate == null
                              ? 'No next payment scheduled'
                              : 'Next ${formatDateLong(r.nextDate!)}',
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _headerSummary(List<RecurrenceTemplate> items) {
    final income = items.where((r) => r.isIncome).length;
    final expenses = items.length - income;
    return [
      '${items.length} recurring',
      if (expenses > 0) '$expenses ${expenses == 1 ? 'expense' : 'expenses'}',
      if (income > 0) '$income income',
    ].join(' · ');
  }

  String _formatAmount(RecurrenceTemplate r, String? defaultCurrency) {
    final Decimal amount;
    try {
      amount = Decimal.parse(r.nextPaymentAmount);
    } catch (_) {
      return r.nextPaymentAmount;
    }
    final code = r.currency.isNotEmpty ? r.currency : (defaultCurrency ?? '');
    final sign = r.isIncome ? '+' : '-';
    if (code.isEmpty) {
      // No currency available — show bare number with 2 decimal places.
      return '$sign${amount.abs().toStringAsFixed(2)}';
    }
    return '$sign${formatMoney(amount.abs(), code)}';
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    RecurrenceTemplate r,
  ) async {
    final negativeText = context.palette.negativeText;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete recurring transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: negativeText)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    HapticFeedback.mediumImpact();
    try {
      await ref.read(recurrencesControllerProvider).delete(r.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMessage(e))));
      }
    }
  }
}
