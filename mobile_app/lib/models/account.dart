import 'package:decimal/decimal.dart';

class AccountBalance {
  const AccountBalance({required this.currency, required this.amount});

  final String currency;
  final Decimal amount;
}

/// A named place money lives (Cash, Bank, Savings). Any currency can be in it.
class Account {
  const Account({
    required this.id,
    required this.name,
    this.balances = const [],
    this.approxTotal,
  });

  final int id;
  final String name;
  final List<AccountBalance> balances;

  /// Balances summed in the default currency at today's rates; null when a
  /// currency has no rate.
  final Decimal? approxTotal;

  factory Account.fromJson(Map<String, dynamic> json) {
    final approx = json['approx_total'] as String?;
    return Account(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      balances: [
        for (final b in (json['balances'] as List? ?? const []))
          AccountBalance(
            currency: b['currency'] as String? ?? '',
            amount: Decimal.tryParse('${b['amount']}') ?? Decimal.zero,
          ),
      ],
      approxTotal: approx == null ? null : Decimal.tryParse(approx),
    );
  }
}

/// Money moved between accounts or currencies. Without a "from" account it is
/// a balance correction, whose amount can be negative.
class Transfer {
  const Transfer({
    required this.id,
    required this.date,
    required this.toAccountId,
    required this.toCurrency,
    required this.toAmount,
    this.fromAccountId,
    this.fromCurrency = '',
    this.fromAmount,
  });

  final int id;
  final DateTime date;
  final int? fromAccountId;
  final String fromCurrency;
  final Decimal? fromAmount;
  final int toAccountId;
  final String toCurrency;
  final Decimal toAmount;

  bool get isCorrection => fromAccountId == null;

  factory Transfer.fromJson(Map<String, dynamic> json) {
    final from = json['from_amount'];
    return Transfer(
      id: (json['id'] as num?)?.toInt() ?? 0,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime(0),
      fromAccountId: (json['from_account_id'] as num?)?.toInt(),
      fromCurrency: json['from_currency'] as String? ?? '',
      fromAmount: from == null ? null : Decimal.tryParse('$from'),
      toAccountId: (json['to_account_id'] as num?)?.toInt() ?? 0,
      toCurrency: json['to_currency'] as String? ?? '',
      toAmount: Decimal.tryParse('${json['to_amount']}') ?? Decimal.zero,
    );
  }
}
