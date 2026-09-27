// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CategoryImpl _$$CategoryImplFromJson(Map<String, dynamic> json) =>
    _$CategoryImpl(
      id: (json['id'] as num).toInt(),
      profileId: (json['profile_id'] as num?)?.toInt(),
      name: json['name'] as String,
      type: json['type'] as String,
      icon: json['icon'] as String? ?? '',
      color: json['color'] as String? ?? '',
    );

Map<String, dynamic> _$$CategoryImplToJson(_$CategoryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'profile_id': instance.profileId,
      'name': instance.name,
      'type': instance.type,
      'icon': instance.icon,
      'color': instance.color,
    };
