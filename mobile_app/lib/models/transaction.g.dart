// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TransactionCategoryImpl _$$TransactionCategoryImplFromJson(
  Map<String, dynamic> json,
) => _$TransactionCategoryImpl(
  id: (json['id'] as num).toInt(),
  categoryId: (json['category_id'] as num).toInt(),
  amount: const _DecimalConverter().fromJson(json['amount'] as String),
  category: json['Category'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$$TransactionCategoryImplToJson(
  _$TransactionCategoryImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'category_id': instance.categoryId,
  'amount': const _DecimalConverter().toJson(instance.amount),
  'Category': instance.category,
};

_$TransactionImpl _$$TransactionImplFromJson(Map<String, dynamic> json) =>
    _$TransactionImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: json['type'] as String,
      date: DateTime.parse(json['date'] as String),
      currencyCode: json['currency_code'] as String,
      icon: json['icon'] as String? ?? '',
      color: json['color'] as String? ?? '',
      merchantName: json['merchant_name'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      categories:
          (json['TransactionCategory'] as List<dynamic>?)
              ?.map(
                (e) => TransactionCategory.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <TransactionCategory>[],
    );

Map<String, dynamic> _$$TransactionImplToJson(_$TransactionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'date': instance.date.toIso8601String(),
      'currency_code': instance.currencyCode,
      'icon': instance.icon,
      'color': instance.color,
      'merchant_name': instance.merchantName,
      'notes': instance.notes,
      'TransactionCategory': instance.categories,
    };
