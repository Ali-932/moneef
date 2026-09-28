// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurrence_occurrence.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RecurrenceOccurrenceImpl _$$RecurrenceOccurrenceImplFromJson(
  Map<String, dynamic> json,
) => _$RecurrenceOccurrenceImpl(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  type: json['type'] as String,
  amount: const _DecimalConverter().fromJson(json['amount'] as String),
  currencyCode: json['currency'] as String? ?? '',
  icon: json['icon'] as String? ?? '',
  color: json['color'] as String? ?? '',
  date: DateTime.parse(json['date'] as String),
);

Map<String, dynamic> _$$RecurrenceOccurrenceImplToJson(
  _$RecurrenceOccurrenceImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': instance.type,
  'amount': const _DecimalConverter().toJson(instance.amount),
  'currency': instance.currencyCode,
  'icon': instance.icon,
  'color': instance.color,
  'date': instance.date.toIso8601String(),
};
