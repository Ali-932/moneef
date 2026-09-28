import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'analysis.freezed.dart';
part 'analysis.g.dart';

class _DecimalConverter implements JsonConverter<Decimal, String> {
  const _DecimalConverter();

  @override
  Decimal fromJson(String json) => Decimal.parse(json);

  @override
  String toJson(Decimal object) => object.toString();
}

@freezed
class CategorySummary with _$CategorySummary {
  const factory CategorySummary({
    @JsonKey(name: 'category_id') required int categoryId,
    @JsonKey(name: 'category_name') required String categoryName,
    @_DecimalConverter()
    @JsonKey(name: 'total_amount')
    required Decimal totalAmount,
    @_DecimalConverter() required Decimal percentage,
    @Default('') String icon,
    @Default('') String color,
  }) = _CategorySummary;

  factory CategorySummary.fromJson(Map<String, dynamic> json) =>
      _$CategorySummaryFromJson(json);
}

@freezed
class AmountPerDay with _$AmountPerDay {
  const factory AmountPerDay({
    required DateTime date,
    @_DecimalConverter() required Decimal amount,
  }) = _AmountPerDay;

  factory AmountPerDay.fromJson(Map<String, dynamic> json) =>
      _$AmountPerDayFromJson(json);
}

@freezed
class NextRecurringTransaction with _$NextRecurringTransaction {
  const factory NextRecurringTransaction({
    @_DecimalConverter() required Decimal amount,
    required DateTime date,
    required String name,
  }) = _NextRecurringTransaction;

  factory NextRecurringTransaction.fromJson(Map<String, dynamic> json) =>
      _$NextRecurringTransactionFromJson(json);
}

@freezed
class BiggestTransaction with _$BiggestTransaction {
  const factory BiggestTransaction({
    required String name,
    @_DecimalConverter() required Decimal amount,
    @Default('') String icon,
    @Default('') String color,
  }) = _BiggestTransaction;

  factory BiggestTransaction.fromJson(Map<String, dynamic> json) =>
      _$BiggestTransactionFromJson(json);
}

@freezed
class TopMerchant with _$TopMerchant {
  const factory TopMerchant({
    required String name,
    @_DecimalConverter() required Decimal amount,
  }) = _TopMerchant;

  factory TopMerchant.fromJson(Map<String, dynamic> json) =>
      _$TopMerchantFromJson(json);
}

@freezed
class QuickStats with _$QuickStats {
  const factory QuickStats({
    @_DecimalConverter()
    @JsonKey(name: 'savings_rate')
    required Decimal savingsRate,
    @JsonKey(name: 'biggest_transaction')
    required BiggestTransaction biggestTransaction,
    @JsonKey(name: 'transaction_count') required int transactionCount,
    @JsonKey(name: 'top_merchant') required TopMerchant topMerchant,
    @_DecimalConverter()
    @JsonKey(name: 'avg_transaction')
    required Decimal avgTransaction,
  }) = _QuickStats;

  factory QuickStats.fromJson(Map<String, dynamic> json) =>
      _$QuickStatsFromJson(json);
}

@freezed
class AnalysisCharts with _$AnalysisCharts {
  const factory AnalysisCharts({
    @Default(<CategorySummary>[]) List<CategorySummary> categories,
    @JsonKey(name: 'categories_last_period')
    @Default(<CategorySummary>[])
    List<CategorySummary> categoriesLastPeriod,
    @JsonKey(name: 'spent_per_day')
    @Default(<AmountPerDay>[])
    List<AmountPerDay> spentPerDay,
    @JsonKey(name: 'spent_per_day_last_period')
    @Default(<AmountPerDay>[])
    List<AmountPerDay> spentPerDayLastPeriod,
    @JsonKey(name: 'next_recurring_transactions')
    @Default(<NextRecurringTransaction>[])
    List<NextRecurringTransaction> nextRecurringTransactions,
    @_DecimalConverter() required Decimal total,
    @JsonKey(name: 'quick_stats') required QuickStats quickStats,
  }) = _AnalysisCharts;

  factory AnalysisCharts.fromJson(Map<String, dynamic> json) =>
      _$AnalysisChartsFromJson(json);
}
