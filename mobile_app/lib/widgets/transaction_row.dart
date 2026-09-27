import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/mdi.dart';
import 'common/design.dart';

class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.transaction,
    this.onTap,
    this.showDate = false,
  });
  final Transaction transaction;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isIncome = transaction.type == 'income';
    final amount = formatMoney(
      isIncome ? transaction.totalAmount : -transaction.totalAmount,
      transaction.currencyCode,
      signed: true,
    );
    final category = transaction.categories.isEmpty
        ? (isIncome ? 'Income' : 'Expense')
        : (transaction.categories.first.category?['name'] ?? 'Category')
              .toString();
    final extra = transaction.categories.length > 1
        ? ' +${transaction.categories.length - 1}'
        : '';
    final color = _hexToColor(transaction.color) ?? palette.primary;
    final large =
        MediaQuery.textScalerOf(context).scale(1) >= 1.3 ||
        MediaQuery.sizeOf(context).width < 360;
    final value = Text(
      amount,
      style: TextStyle(
        color: isIncome ? palette.positiveText : palette.ink,
        fontWeight: FontWeight.w700,
        fontSize: 14,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.medium,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              QuietIcon(
                icon: transaction.icon.isEmpty
                    ? Icons.receipt_long_outlined
                    : mdiIconData(transaction.icon),
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.name,
                      maxLines: large ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$category$extra · ${showDate ? formatDateShort(transaction.date) : formatClock(transaction.date)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.muted, fontSize: 11),
                    ),
                    if (large) ...[const SizedBox(height: 6), value],
                  ],
                ),
              ),
              if (!large) ...[const SizedBox(width: 12), value],
            ],
          ),
        ),
      ),
    );
  }
}

Color? _hexToColor(String hex) {
  final h = hex.replaceAll('#', '');
  if (h.length != 6) return null;
  final value = int.tryParse('FF$h', radix: 16);
  return value == null ? null : Color(value);
}

class TransactionGroupHeader extends StatelessWidget {
  const TransactionGroupHeader({
    super.key,
    required this.label,
    required this.dailyTotal,
    required this.currencyCode,
  });
  final String label;
  final Decimal dailyTotal;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: palette.muted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                formatMoney(dailyTotal, currencyCode, signed: true),
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: dailyTotal >= Decimal.zero
                      ? palette.positiveText
                      : palette.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
