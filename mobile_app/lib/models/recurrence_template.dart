class RecurrenceTemplate {
  RecurrenceTemplate.fromJson(Map<String, dynamic> json)
    : id = (json['id'] as num).toInt(),
      name = json['name'] as String? ?? '',
      type = json['type'] as String? ?? 'expense',
      frequency = json['frequency'] as String? ?? 'monthly',
      nextDate = _date(json['next_date']),
      endDate = _date(json['end_date']),
      nextPaymentAmount = json['next_payment_amount'] as String? ?? '0',
      currency = json['currency_code'] as String? ?? '',
      isActive = json['is_active'] as bool? ?? true,
      hasEndDate = json['has_end_date'] as bool? ?? false,
      merchantName = json['merchant_name'] as String? ?? '',
      notes = json['notes'] as String? ?? '';

  final int id;
  final String name, type, frequency, nextPaymentAmount, currency;
  final DateTime? nextDate, endDate;
  final bool isActive, hasEndDate;
  final String merchantName, notes;

  bool get isIncome => type == 'income';

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value).toLocal() : null;
}

const recurrenceFrequencies = {
  'daily': 'Daily',
  'weekly': 'Weekly',
  'bi-weekly': 'Bi-weekly',
  'monthly': 'Monthly',
  'yearly': 'Yearly',
};
