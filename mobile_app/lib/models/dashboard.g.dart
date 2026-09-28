// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DashboardPeriodImpl _$$DashboardPeriodImplFromJson(
  Map<String, dynamic> json,
) => _$DashboardPeriodImpl(
  startDate: DateTime.parse(json['start_date'] as String),
  endDate: DateTime.parse(json['end_date'] as String),
);

Map<String, dynamic> _$$DashboardPeriodImplToJson(
  _$DashboardPeriodImpl instance,
) => <String, dynamic>{
  'start_date': instance.startDate.toIso8601String(),
  'end_date': instance.endDate.toIso8601String(),
};

_$DashboardSummaryImpl _$$DashboardSummaryImplFromJson(
  Map<String, dynamic> json,
) => _$DashboardSummaryImpl(
  period: DashboardPeriod.fromJson(json['period'] as Map<String, dynamic>),
  currencyCode: json['currency_code'] as String,
  balance: const _DecimalConverter().fromJson(json['balance'] as String),
  totalIncome: const _DecimalConverter().fromJson(
    json['total_income'] as String,
  ),
  totalExpense: const _DecimalConverter().fromJson(
    json['total_expense'] as String,
  ),
  recentTransactions:
      (json['recent_transactions'] as List<dynamic>?)
          ?.map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Transaction>[],
  quickStats: json['quick_stats'] == null
      ? null
      : DashboardQuickStats.fromJson(
          json['quick_stats'] as Map<String, dynamic>,
        ),
  upcomingRecurring:
      (json['upcoming_recurring'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const <Map<String, dynamic>>[],
);

Map<String, dynamic> _$$DashboardSummaryImplToJson(
  _$DashboardSummaryImpl instance,
) => <String, dynamic>{
  'period': instance.period,
  'currency_code': instance.currencyCode,
  'balance': const _DecimalConverter().toJson(instance.balance),
  'total_income': const _DecimalConverter().toJson(instance.totalIncome),
  'total_expense': const _DecimalConverter().toJson(instance.totalExpense),
  'recent_transactions': instance.recentTransactions,
  'quick_stats': instance.quickStats,
  'upcoming_recurring': instance.upcomingRecurring,
};

_$DashboardQuickStatsImpl _$$DashboardQuickStatsImplFromJson(
  Map<String, dynamic> json,
) => _$DashboardQuickStatsImpl(
  topCategory: json['top_category'] == null
      ? null
      : DashboardCategoryStat.fromJson(
          json['top_category'] as Map<String, dynamic>,
        ),
  avgDailySpend: const _DecimalConverter().fromJson(
    json['avg_daily_spend'] as String,
  ),
  transactionCount: (json['transaction_count'] as num).toInt(),
  savingsRate: const _DecimalConverter().fromJson(
    json['savings_rate'] as String,
  ),
  biggestTransaction: DashboardBiggestTransaction.fromJson(
    json['biggest_transaction'] as Map<String, dynamic>,
  ),
  topMerchant: DashboardTopMerchant.fromJson(
    json['top_merchant'] as Map<String, dynamic>,
  ),
  avgTransaction: const _DecimalConverter().fromJson(
    json['avg_transaction'] as String,
  ),
);

Map<String, dynamic> _$$DashboardQuickStatsImplToJson(
  _$DashboardQuickStatsImpl instance,
) => <String, dynamic>{
  'top_category': instance.topCategory,
  'avg_daily_spend': const _DecimalConverter().toJson(instance.avgDailySpend),
  'transaction_count': instance.transactionCount,
  'savings_rate': const _DecimalConverter().toJson(instance.savingsRate),
  'biggest_transaction': instance.biggestTransaction,
  'top_merchant': instance.topMerchant,
  'avg_transaction': const _DecimalConverter().toJson(instance.avgTransaction),
};

_$DashboardCategoryStatImpl _$$DashboardCategoryStatImplFromJson(
  Map<String, dynamic> json,
) => _$DashboardCategoryStatImpl(
  categoryId: (json['category_id'] as num).toInt(),
  categoryName: json['category_name'] as String,
  totalAmount: const _DecimalConverter().fromJson(
    json['total_amount'] as String,
  ),
);

Map<String, dynamic> _$$DashboardCategoryStatImplToJson(
  _$DashboardCategoryStatImpl instance,
) => <String, dynamic>{
  'category_id': instance.categoryId,
  'category_name': instance.categoryName,
  'total_amount': const _DecimalConverter().toJson(instance.totalAmount),
};

_$DashboardBiggestTransactionImpl _$$DashboardBiggestTransactionImplFromJson(
  Map<String, dynamic> json,
) => _$DashboardBiggestTransactionImpl(
  name: json['name'] as String? ?? '',
  amount: const _DecimalConverter().fromJson(json['amount'] as String),
  icon: json['icon'] as String? ?? '',
  color: json['color'] as String? ?? '',
);

Map<String, dynamic> _$$DashboardBiggestTransactionImplToJson(
  _$DashboardBiggestTransactionImpl instance,
) => <String, dynamic>{
  'name': instance.name,
  'amount': const _DecimalConverter().toJson(instance.amount),
  'icon': instance.icon,
  'color': instance.color,
};

_$DashboardTopMerchantImpl _$$DashboardTopMerchantImplFromJson(
  Map<String, dynamic> json,
) => _$DashboardTopMerchantImpl(
  name: json['name'] as String? ?? '',
  amount: const _DecimalConverter().fromJson(json['amount'] as String),
);

Map<String, dynamic> _$$DashboardTopMerchantImplToJson(
  _$DashboardTopMerchantImpl instance,
) => <String, dynamic>{
  'name': instance.name,
  'amount': const _DecimalConverter().toJson(instance.amount),
};
