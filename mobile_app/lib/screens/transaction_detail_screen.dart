import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/transaction.dart';
import '../state/providers.dart';
import '../state/transactions_controller.dart';
import '../theme.dart';
import '../widgets/common/design.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../utils/mdi.dart';
import '../widgets/common/skeletons.dart';

// ---------------------------------------------------------------------------
// Local helpers — replicated here; do NOT import from transaction_row.dart.
// ---------------------------------------------------------------------------

Color _hexToColor(String hex) {
  final s = hex.replaceFirst('#', '');
  if (s.length == 6) return Color(int.parse('FF$s', radix: 16));
  if (s.length == 8) return Color(int.parse(s, radix: 16));
  return Colors.transparent;
}

// ---------------------------------------------------------------------------
// Screen — ConsumerStatefulWidget to hold _isDeleting
// ---------------------------------------------------------------------------

class TransactionDetailScreen extends ConsumerStatefulWidget {
  const TransactionDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  bool _isDeleting = false;

  Future<void> _doEdit() async {
    final changed = await context.push<bool>('/transactions/${widget.id}/edit');
    if (changed == true && mounted) {
      ref.invalidate(transactionByIdProvider(widget.id));
    }
  }

  Future<void> _confirmDelete(BuildContext context, Transaction? t) async {
    final name = t?.name ?? 'this transaction';
    final amount = t != null
        ? formatMoney(
            t.type == 'income' ? t.totalAmount : -t.totalAmount,
            t.currencyCode,
            signed: true,
          )
        : '';

    final palette = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: palette.card,
        title: const Text('Delete transaction?'),
        content: Text(
          amount.isNotEmpty
              ? '"$name" · $amount\nThis cannot be undone.'
              : '"$name"\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: palette.negativeText),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(transactionsMutationProvider).delete(widget.id);
      if (!context.mounted) return;
      context.pop();
    } catch (e) {
      if (context.mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage(e)),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _confirmDelete(context, t),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final async = ref.watch(transactionByIdProvider(widget.id));
    final isLoading = async is AsyncLoading;
    final busy = isLoading || _isDeleting;
    final t = async.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          // Delete — shown as spinner while deleting, icon otherwise
          if (_isDeleting)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    palette.negativeText,
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Delete transaction',
              icon: Icon(Icons.delete_outline, color: palette.muted),
              onPressed: busy ? null : () => _confirmDelete(context, t),
            ),
        ],
      ),
      body: async.when(
        loading: () => const TransactionDetailSkeleton(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userMessage(e),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.negativeText),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(transactionByIdProvider(widget.id)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (t) => _Detail(transaction: t, onEdit: busy ? null : _doEdit),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail body — pure StatelessWidget, no mutation logic
// ---------------------------------------------------------------------------

class _Detail extends StatelessWidget {
  const _Detail({required this.transaction, required this.onEdit});
  final Transaction transaction;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final income = transaction.type == 'income';
    final total = transaction.totalAmount;
    final color = transaction.color.isNotEmpty
        ? _hexToColor(transaction.color)
        : p.primary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: AppRadii.large,
          ),
          child: Column(
            children: [
              QuietIcon(
                icon: transaction.icon.isNotEmpty
                    ? mdiIconData(transaction.icon)
                    : Icons.receipt_long_outlined,
                color: color,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                transaction.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              MoneyText(
                formatMoney(
                  income ? total : -total,
                  transaction.currencyCode,
                  signed: true,
                ),
                size: 36,
                color: income ? p.positiveText : p.ink,
                weight: FontWeight.w800,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: income ? p.incomeBg : p.tile,
                  borderRadius: AppRadii.pill,
                ),
                child: Text(
                  income ? 'Income' : 'Expense',
                  style: TextStyle(
                    color: income ? p.positiveText : p.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _metadata(
                context,
                Icons.calendar_today_outlined,
                'Date',
                formatDateLong(transaction.date),
              ),
              const SizedBox(height: 14),
              _metadata(
                context,
                Icons.schedule_outlined,
                'Time',
                formatClock(transaction.date),
              ),
              const SizedBox(height: 14),
              _metadata(
                context,
                Icons.payments_outlined,
                'Currency',
                transaction.currencyCode,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (transaction.merchantName.isNotEmpty) ...[
          _metadata(
            context,
            Icons.storefront_outlined,
            'Merchant',
            transaction.merchantName,
          ),
          const SizedBox(height: 16),
        ],
        if (transaction.notes.isNotEmpty) ...[
          Text('Notes', style: TextStyle(color: p.muted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            transaction.notes,
            style: TextStyle(color: p.ink, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
        ],
        if (transaction.categories.isNotEmpty) ...[
          Text(
            'Category breakdown',
            style: TextStyle(
              color: p.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: AppRadii.large,
            ),
            child: Column(
              children: [
                for (final c in transaction.categories)
                  _CategoryRow(
                    c: c,
                    currencyCode: transaction.currencyCode,
                    total: total,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit transaction'),
        ),
      ],
    );
  }

  Widget _metadata(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 17, color: context.palette.muted),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: context.palette.muted, fontSize: 12)),
      const SizedBox(width: 20),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            color: context.palette.ink,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.c,
    required this.currencyCode,
    required this.total,
  });
  final TransactionCategory c;
  final String currencyCode;
  final Decimal total;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hex = c.category?['color'] as String?;
    final color = hex == null || hex.isEmpty ? p.primary : _hexToColor(hex);
    final raw = (c.category?['name'] as String?) ?? '';
    final name = raw.isEmpty ? 'Deleted category' : raw;
    final share = total > Decimal.zero
        ? (c.amount / total).toDouble().clamp(0.0, 1.0)
        : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatMoney(c.amount, currencyCode),
                style: TextStyle(
                  color: p.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: share,
                  color: color,
                  backgroundColor: p.tile,
                  minHeight: 5,
                  borderRadius: AppRadii.pill,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(share * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: p.muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
