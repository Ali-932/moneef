import 'package:decimal/decimal.dart';

class ExchangeRate {
  const ExchangeRate({
    required this.id,
    required this.from,
    required this.to,
    required this.rate,
    this.lastUpdated,
  });

  final int id;
  final String from;
  final String to;
  final Decimal rate;
  final DateTime? lastUpdated;

  factory ExchangeRate.fromJson(Map<String, dynamic> json) {
    final updated = json['last_updated'] as String?;
    return ExchangeRate(
      id: (json['id'] as num?)?.toInt() ?? 0,
      from: json['currency_code_1'] as String? ?? '',
      to: json['currency_code_2'] as String? ?? '',
      rate: Decimal.tryParse('${json['rate'] ?? '0'}') ?? Decimal.zero,
      lastUpdated: updated != null ? DateTime.tryParse(updated) : null,
    );
  }
}
