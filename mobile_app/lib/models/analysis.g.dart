// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analysis.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CategorySummaryImpl _$$CategorySummaryImplFromJson(
  Map<String, dynamic> json,
) => _$CategorySummaryImpl(
  categoryId: (json['category_id'] as num).toInt(),
  categoryName: json['category_name'] as String,
  totalAmount: const _DecimalConverter().fromJson(
    json['total_amount'] as String,
  ),
  percentage: const _DecimalConverter().fromJson(json['percentage'] as String),
  icon: json['icon'] as String? ?? '',
  color: json['color'] as String? ?? '',
);

Map<String, dynamic> _$$CategorySummaryImplToJson(
  _$CategorySummaryImpl instance,
) => <String, dynamic>{
  'category_id': instance.categoryId,
  'category_name': instance.categoryName,
  'total_amount': const _DecimalConverter().toJson(instance.totalAmount),
  'percentage': const _DecimalConverter().toJson(instance.percentage),
  'icon': instance.icon,
  'color': instance.color,
};

_$AmountPerDayImpl _$$AmountPerDayImplFromJson(Map<String, dynamic> json) =>
    _$AmountPerDayImpl(
      date: DateTime.parse(json['date'] as String),
      amount: const _DecimalConverter().fromJson(json['amount'] as String),
    );

Map<String, dynamic> _$$AmountPerDayImplToJson(_$AmountPerDayImpl instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'amount': const _DecimalConverter().toJson(instance.amount),
    };

_$NextRecurringTransactionImpl _$$NextRecurringTransactionImplFromJson(
  Map<String, dynamic> json,
) => _$NextRecurringTransactionImpl(
  amount: const _DecimalConverter().fromJson(json['amount'] as String),
  date: DateTime.parse(json['date'] as String),
  name: json['name'] as String,
);

Map<String, dynamic> _$$NextRecurringTransactionImplToJson(
  _$NextRecurringTransactionImpl instance,
) => <String, dynamic>{
  'amount': const _DecimalConverter().toJson(instance.amount),
  'date': instance.date.toIso8601String(),
  'name': instance.name,
};

_$BiggestTransactionImpl _$$BiggestTransactionImplFromJson(
  Map<String, dynamic> json,
) => _$BiggestTransactionImpl(
  name: json['name'] as String,
  amount: const _DecimalConverter().fromJson(json['amount'] as String),
  icon: json['icon'] as String? ?? '',
  color: json['color'] as String? ?? '',
);

Map<String, dynamic> _$$BiggestTransactionImplToJson(
  _$BiggestTransactionImpl instance,
) => <String, dynamic>{
  'name': instance.name,
  'amount': const _DecimalConverter().toJson(instance.amount),
  'icon': instance.icon,
  'color': instance.color,
};

_$TopMerchantImpl _$$TopMerchantImplFromJson(Map<String, dynamic> json) =>
    _$TopMerchantImpl(
      name: json['name'] as String,
      amount: const _DecimalConverter().fromJson(json['amount'] as String),
    );

Map<String, dynamic> _$$TopMerchantImplToJson(_$TopMerchantImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'amount': const _DecimalConverter().toJson(instance.amount),
    };

_$QuickStatsImpl _$$QuickStatsImplFromJson(Map<String, dynamic> json) =>
    _$QuickStatsImpl(
      savingsRate: const _DecimalConverter().fromJson(
        json['savings_rate'] as String,
      ),
      biggestTransaction: BiggestTransaction.fromJson(
        json['biggest_transaction'] as Map<String, dynamic>,
      ),
      transactionCount: (json['transaction_count'] as num).toInt(),
      topMerchant: TopMerchant.fromJson(
        json['top_merchant'] as Map<String, dynamic>,
      ),
      avgTransaction: const _DecimalConverter().fromJson(
        json['avg_transaction'] as String,
      ),
    );

Map<String, dynamic> _$$QuickStatsImplToJson(
  _$QuickStatsImpl instance,
) => <String, dynamic>{
  'savings_rate': const _DecimalConverter().toJson(instance.savingsRate),
  'biggest_transaction': instance.biggestTransaction,
  'transaction_count': instance.transactionCount,
  'top_merchant': instance.topMerchant,
  'avg_transaction': const _DecimalConverter().toJson(instance.avgTransaction),
};

_$AnalysisChartsImpl _$$AnalysisChartsImplFromJson(
  Map<String, dynamic> json,
) => _$AnalysisChartsImpl(
  categories:
      (json['categories'] as List<dynamic>?)
          ?.map((e) => CategorySummary.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <CategorySummary>[],
  categoriesLastPeriod:
      (json['categories_last_period'] as List<dynamic>?)
          ?.map((e) => CategorySummary.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <CategorySummary>[],
  spentPerDay:
      (json['spent_per_day'] as List<dynamic>?)
          ?.map((e) => AmountPerDay.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <AmountPerDay>[],
  spentPerDayLastPeriod:
      (json['spent_per_day_last_period'] as List<dynamic>?)
          ?.map((e) => AmountPerDay.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <AmountPerDay>[],
  nextRecurringTransactions:
      (json['next_recurring_transactions'] as List<dynamic>?)
          ?.map(
            (e) => NextRecurringTransaction.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const <NextRecurringTransaction>[],
  total: const _DecimalConverter().fromJson(json['total'] as String),
  quickStats: QuickStats.fromJson(json['quick_stats'] as Map<String, dynamic>),
);

Map<String, dynamic> _$$AnalysisChartsImplToJson(
  _$AnalysisChartsImpl instance,
) => <String, dynamic>{
  'categories': instance.categories,
  'categories_last_period': instance.categoriesLastPeriod,
  'spent_per_day': instance.spentPerDay,
  'spent_per_day_last_period': instance.spentPerDayLastPeriod,
  'next_recurring_transactions': instance.nextRecurringTransactions,
  'total': const _DecimalConverter().toJson(instance.total),
  'quick_stats': instance.quickStats,
};
