import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'transaction.dart';

part 'dashboard.freezed.dart';
part 'dashboard.g.dart';

class _DecimalConverter implements JsonConverter<Decimal, String> {
  const _DecimalConverter();

  @override
  Decimal fromJson(String json) => Decimal.parse(json);

  @override
  String toJson(Decimal object) => object.toString();
}

@freezed
class DashboardPeriod with _$DashboardPeriod {
  const factory DashboardPeriod({
    @JsonKey(name: 'start_date') required DateTime startDate,
    @JsonKey(name: 'end_date') required DateTime endDate,
  }) = _DashboardPeriod;

  factory DashboardPeriod.fromJson(Map<String, dynamic> json) =>
      _$DashboardPeriodFromJson(json);
}

@freezed
class DashboardSummary with _$DashboardSummary {
  const factory DashboardSummary({
    required DashboardPeriod period,
    @JsonKey(name: 'currency_code') required String currencyCode,
    @_DecimalConverter() required Decimal balance,
    @_DecimalConverter()
    @JsonKey(name: 'total_income')
    required Decimal totalIncome,
    @_DecimalConverter()
    @JsonKey(name: 'total_expense')
    required Decimal totalExpense,
    @JsonKey(name: 'recent_transactions')
    @Default(<Transaction>[])
    List<Transaction> recentTransactions,
    @JsonKey(name: 'quick_stats') DashboardQuickStats? quickStats,
    @JsonKey(name: 'upcoming_recurring')
    @Default(<Map<String, dynamic>>[])
    List<Map<String, dynamic>> upcomingRecurring,
  }) = _DashboardSummary;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      _$DashboardSummaryFromJson(json);
}

@freezed
class DashboardQuickStats with _$DashboardQuickStats {
  const factory DashboardQuickStats({
    @JsonKey(name: 'top_category') DashboardCategoryStat? topCategory,
    @_DecimalConverter()
    @JsonKey(name: 'avg_daily_spend')
    required Decimal avgDailySpend,
    @JsonKey(name: 'transaction_count') required int transactionCount,
    @_DecimalConverter()
    @JsonKey(name: 'savings_rate')
    required Decimal savingsRate,
    @JsonKey(name: 'biggest_transaction')
    required DashboardBiggestTransaction biggestTransaction,
    @JsonKey(name: 'top_merchant') required DashboardTopMerchant topMerchant,
    @_DecimalConverter()
    @JsonKey(name: 'avg_transaction')
    required Decimal avgTransaction,
  }) = _DashboardQuickStats;

  factory DashboardQuickStats.fromJson(Map<String, dynamic> json) =>
      _$DashboardQuickStatsFromJson(json);
}

@freezed
class DashboardCategoryStat with _$DashboardCategoryStat {
  const factory DashboardCategoryStat({
    @JsonKey(name: 'category_id') required int categoryId,
    @JsonKey(name: 'category_name') required String categoryName,
    @_DecimalConverter()
    @JsonKey(name: 'total_amount')
    required Decimal totalAmount,
  }) = _DashboardCategoryStat;

  factory DashboardCategoryStat.fromJson(Map<String, dynamic> json) =>
      _$DashboardCategoryStatFromJson(json);
}

@freezed
class DashboardBiggestTransaction with _$DashboardBiggestTransaction {
  const factory DashboardBiggestTransaction({
    @Default('') String name,
    @_DecimalConverter() required Decimal amount,
    @Default('') String icon,
    @Default('') String color,
  }) = _DashboardBiggestTransaction;

  factory DashboardBiggestTransaction.fromJson(Map<String, dynamic> json) =>
      _$DashboardBiggestTransactionFromJson(json);
}

@freezed
class DashboardTopMerchant with _$DashboardTopMerchant {
  const factory DashboardTopMerchant({
    @Default('') String name,
    @_DecimalConverter() required Decimal amount,
  }) = _DashboardTopMerchant;

  factory DashboardTopMerchant.fromJson(Map<String, dynamic> json) =>
      _$DashboardTopMerchantFromJson(json);
}
