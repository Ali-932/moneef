// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pattern.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Pattern _$PatternFromJson(Map<String, dynamic> json) {
  return _Pattern.fromJson(json);
}

/// @nodoc
mixin _$Pattern {
  int get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;
  String get icon => throw _privateConstructorUsedError;
  String get color => throw _privateConstructorUsedError;
  @JsonKey(name: 'pattern_type')
  String get patternType => throw _privateConstructorUsedError;
  @JsonKey(name: 'final_score')
  double get finalScore => throw _privateConstructorUsedError;
  @JsonKey(name: 'profile_id')
  int get profileId => throw _privateConstructorUsedError;

  /// Serializes this Pattern to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Pattern
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PatternCopyWith<Pattern> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PatternCopyWith<$Res> {
  factory $PatternCopyWith(Pattern value, $Res Function(Pattern) then) =
      _$PatternCopyWithImpl<$Res, Pattern>;
  @useResult
  $Res call({
    int id,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
    String name,
    String description,
    Map<String, dynamic>? metadata,
    String icon,
    String color,
    @JsonKey(name: 'pattern_type') String patternType,
    @JsonKey(name: 'final_score') double finalScore,
    @JsonKey(name: 'profile_id') int profileId,
  });
}

/// @nodoc
class _$PatternCopyWithImpl<$Res, $Val extends Pattern>
    implements $PatternCopyWith<$Res> {
  _$PatternCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Pattern
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? name = null,
    Object? description = null,
    Object? metadata = freezed,
    Object? icon = null,
    Object? color = null,
    Object? patternType = null,
    Object? finalScore = null,
    Object? profileId = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            metadata: freezed == metadata
                ? _value.metadata
                : metadata // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            icon: null == icon
                ? _value.icon
                : icon // ignore: cast_nullable_to_non_nullable
                      as String,
            color: null == color
                ? _value.color
                : color // ignore: cast_nullable_to_non_nullable
                      as String,
            patternType: null == patternType
                ? _value.patternType
                : patternType // ignore: cast_nullable_to_non_nullable
                      as String,
            finalScore: null == finalScore
                ? _value.finalScore
                : finalScore // ignore: cast_nullable_to_non_nullable
                      as double,
            profileId: null == profileId
                ? _value.profileId
                : profileId // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PatternImplCopyWith<$Res> implements $PatternCopyWith<$Res> {
  factory _$$PatternImplCopyWith(
    _$PatternImpl value,
    $Res Function(_$PatternImpl) then,
  ) = __$$PatternImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
    String name,
    String description,
    Map<String, dynamic>? metadata,
    String icon,
    String color,
    @JsonKey(name: 'pattern_type') String patternType,
    @JsonKey(name: 'final_score') double finalScore,
    @JsonKey(name: 'profile_id') int profileId,
  });
}

/// @nodoc
class __$$PatternImplCopyWithImpl<$Res>
    extends _$PatternCopyWithImpl<$Res, _$PatternImpl>
    implements _$$PatternImplCopyWith<$Res> {
  __$$PatternImplCopyWithImpl(
    _$PatternImpl _value,
    $Res Function(_$PatternImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Pattern
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? name = null,
    Object? description = null,
    Object? metadata = freezed,
    Object? icon = null,
    Object? color = null,
    Object? patternType = null,
    Object? finalScore = null,
    Object? profileId = null,
  }) {
    return _then(
      _$PatternImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        metadata: freezed == metadata
            ? _value._metadata
            : metadata // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        icon: null == icon
            ? _value.icon
            : icon // ignore: cast_nullable_to_non_nullable
                  as String,
        color: null == color
            ? _value.color
            : color // ignore: cast_nullable_to_non_nullable
                  as String,
        patternType: null == patternType
            ? _value.patternType
            : patternType // ignore: cast_nullable_to_non_nullable
                  as String,
        finalScore: null == finalScore
            ? _value.finalScore
            : finalScore // ignore: cast_nullable_to_non_nullable
                  as double,
        profileId: null == profileId
            ? _value.profileId
            : profileId // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PatternImpl implements _Pattern {
  const _$PatternImpl({
    required this.id,
    @JsonKey(name: 'created_at') required this.createdAt,
    @JsonKey(name: 'updated_at') required this.updatedAt,
    required this.name,
    required this.description,
    final Map<String, dynamic>? metadata = const <String, dynamic>{},
    this.icon = '',
    this.color = '',
    @JsonKey(name: 'pattern_type') required this.patternType,
    @JsonKey(name: 'final_score') required this.finalScore,
    @JsonKey(name: 'profile_id') required this.profileId,
  }) : _metadata = metadata;

  factory _$PatternImpl.fromJson(Map<String, dynamic> json) =>
      _$$PatternImplFromJson(json);

  @override
  final int id;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @override
  final String name;
  @override
  final String description;
  final Map<String, dynamic>? _metadata;
  @override
  @JsonKey()
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey()
  final String icon;
  @override
  @JsonKey()
  final String color;
  @override
  @JsonKey(name: 'pattern_type')
  final String patternType;
  @override
  @JsonKey(name: 'final_score')
  final double finalScore;
  @override
  @JsonKey(name: 'profile_id')
  final int profileId;

  @override
  String toString() {
    return 'Pattern(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, name: $name, description: $description, metadata: $metadata, icon: $icon, color: $color, patternType: $patternType, finalScore: $finalScore, profileId: $profileId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PatternImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.patternType, patternType) ||
                other.patternType == patternType) &&
            (identical(other.finalScore, finalScore) ||
                other.finalScore == finalScore) &&
            (identical(other.profileId, profileId) ||
                other.profileId == profileId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    createdAt,
    updatedAt,
    name,
    description,
    const DeepCollectionEquality().hash(_metadata),
    icon,
    color,
    patternType,
    finalScore,
    profileId,
  );

  /// Create a copy of Pattern
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PatternImplCopyWith<_$PatternImpl> get copyWith =>
      __$$PatternImplCopyWithImpl<_$PatternImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PatternImplToJson(this);
  }
}

abstract class _Pattern implements Pattern {
  const factory _Pattern({
    required final int id,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
    @JsonKey(name: 'updated_at') required final DateTime updatedAt,
    required final String name,
    required final String description,
    final Map<String, dynamic>? metadata,
    final String icon,
    final String color,
    @JsonKey(name: 'pattern_type') required final String patternType,
    @JsonKey(name: 'final_score') required final double finalScore,
    @JsonKey(name: 'profile_id') required final int profileId,
  }) = _$PatternImpl;

  factory _Pattern.fromJson(Map<String, dynamic> json) = _$PatternImpl.fromJson;

  @override
  int get id;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;
  @override
  String get name;
  @override
  String get description;
  @override
  Map<String, dynamic>? get metadata;
  @override
  String get icon;
  @override
  String get color;
  @override
  @JsonKey(name: 'pattern_type')
  String get patternType;
  @override
  @JsonKey(name: 'final_score')
  double get finalScore;
  @override
  @JsonKey(name: 'profile_id')
  int get profileId;

  /// Create a copy of Pattern
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PatternImplCopyWith<_$PatternImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
