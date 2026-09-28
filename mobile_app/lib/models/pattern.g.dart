// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pattern.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PatternImpl _$$PatternImplFromJson(Map<String, dynamic> json) =>
    _$PatternImpl(
      id: (json['id'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      name: json['name'] as String,
      description: json['description'] as String,
      metadata:
          json['metadata'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
      icon: json['icon'] as String? ?? '',
      color: json['color'] as String? ?? '',
      patternType: json['pattern_type'] as String,
      finalScore: (json['final_score'] as num).toDouble(),
      profileId: (json['profile_id'] as num).toInt(),
    );

Map<String, dynamic> _$$PatternImplToJson(_$PatternImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'name': instance.name,
      'description': instance.description,
      'metadata': instance.metadata,
      'icon': instance.icon,
      'color': instance.color,
      'pattern_type': instance.patternType,
      'final_score': instance.finalScore,
      'profile_id': instance.profileId,
    };
