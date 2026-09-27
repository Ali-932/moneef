// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recurrence_occurrence.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

RecurrenceOccurrence _$RecurrenceOccurrenceFromJson(Map<String, dynamic> json) {
  return _RecurrenceOccurrence.fromJson(json);
}

/// @nodoc
mixin _$RecurrenceOccurrence {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  @_DecimalConverter()
  Decimal get amount => throw _privateConstructorUsedError;
  @JsonKey(name: 'currency')
  String get currencyCode => throw _privateConstructorUsedError;
  String get icon => throw _privateConstructorUsedError;
  String get color => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;

  /// Serializes this RecurrenceOccurrence to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecurrenceOccurrence
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecurrenceOccurrenceCopyWith<RecurrenceOccurrence> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecurrenceOccurrenceCopyWith<$Res> {
  factory $RecurrenceOccurrenceCopyWith(
    RecurrenceOccurrence value,
    $Res Function(RecurrenceOccurrence) then,
  ) = _$RecurrenceOccurrenceCopyWithImpl<$Res, RecurrenceOccurrence>;
  @useResult
  $Res call({
    int id,
    String name,
    String type,
    @_DecimalConverter() Decimal amount,
    @JsonKey(name: 'currency') String currencyCode,
    String icon,
    String color,
    DateTime date,
  });
}

/// @nodoc
class _$RecurrenceOccurrenceCopyWithImpl<
  $Res,
  $Val extends RecurrenceOccurrence
>
    implements $RecurrenceOccurrenceCopyWith<$Res> {
  _$RecurrenceOccurrenceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecurrenceOccurrence
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? amount = null,
    Object? currencyCode = null,
    Object? icon = null,
    Object? color = null,
    Object? date = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as Decimal,
            currencyCode: null == currencyCode
                ? _value.currencyCode
                : currencyCode // ignore: cast_nullable_to_non_nullable
                      as String,
            icon: null == icon
                ? _value.icon
                : icon // ignore: cast_nullable_to_non_nullable
                      as String,
            color: null == color
                ? _value.color
                : color // ignore: cast_nullable_to_non_nullable
                      as String,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecurrenceOccurrenceImplCopyWith<$Res>
    implements $RecurrenceOccurrenceCopyWith<$Res> {
  factory _$$RecurrenceOccurrenceImplCopyWith(
    _$RecurrenceOccurrenceImpl value,
    $Res Function(_$RecurrenceOccurrenceImpl) then,
  ) = __$$RecurrenceOccurrenceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    String name,
    String type,
    @_DecimalConverter() Decimal amount,
    @JsonKey(name: 'currency') String currencyCode,
    String icon,
    String color,
    DateTime date,
  });
}

/// @nodoc
class __$$RecurrenceOccurrenceImplCopyWithImpl<$Res>
    extends _$RecurrenceOccurrenceCopyWithImpl<$Res, _$RecurrenceOccurrenceImpl>
    implements _$$RecurrenceOccurrenceImplCopyWith<$Res> {
  __$$RecurrenceOccurrenceImplCopyWithImpl(
    _$RecurrenceOccurrenceImpl _value,
    $Res Function(_$RecurrenceOccurrenceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecurrenceOccurrence
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? amount = null,
    Object? currencyCode = null,
    Object? icon = null,
    Object? color = null,
    Object? date = null,
  }) {
    return _then(
      _$RecurrenceOccurrenceImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as Decimal,
        currencyCode: null == currencyCode
            ? _value.currencyCode
            : currencyCode // ignore: cast_nullable_to_non_nullable
                  as String,
        icon: null == icon
            ? _value.icon
            : icon // ignore: cast_nullable_to_non_nullable
                  as String,
        color: null == color
            ? _value.color
            : color // ignore: cast_nullable_to_non_nullable
                  as String,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecurrenceOccurrenceImpl implements _RecurrenceOccurrence {
  const _$RecurrenceOccurrenceImpl({
    required this.id,
    required this.name,
    required this.type,
    @_DecimalConverter() required this.amount,
    @JsonKey(name: 'currency') this.currencyCode = '',
    this.icon = '',
    this.color = '',
    required this.date,
  });

  factory _$RecurrenceOccurrenceImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecurrenceOccurrenceImplFromJson(json);

  @override
  final int id;
  @override
  final String name;
  @override
  final String type;
  @override
  @_DecimalConverter()
  final Decimal amount;
  @override
  @JsonKey(name: 'currency')
  final String currencyCode;
  @override
  @JsonKey()
  final String icon;
  @override
  @JsonKey()
  final String color;
  @override
  final DateTime date;

  @override
  String toString() {
    return 'RecurrenceOccurrence(id: $id, name: $name, type: $type, amount: $amount, currencyCode: $currencyCode, icon: $icon, color: $color, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecurrenceOccurrenceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.currencyCode, currencyCode) ||
                other.currencyCode == currencyCode) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.date, date) || other.date == date));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    type,
    amount,
    currencyCode,
    icon,
    color,
    date,
  );

  /// Create a copy of RecurrenceOccurrence
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecurrenceOccurrenceImplCopyWith<_$RecurrenceOccurrenceImpl>
  get copyWith =>
      __$$RecurrenceOccurrenceImplCopyWithImpl<_$RecurrenceOccurrenceImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RecurrenceOccurrenceImplToJson(this);
  }
}

abstract class _RecurrenceOccurrence implements RecurrenceOccurrence {
  const factory _RecurrenceOccurrence({
    required final int id,
    required final String name,
    required final String type,
    @_DecimalConverter() required final Decimal amount,
    @JsonKey(name: 'currency') final String currencyCode,
    final String icon,
    final String color,
    required final DateTime date,
  }) = _$RecurrenceOccurrenceImpl;

  factory _RecurrenceOccurrence.fromJson(Map<String, dynamic> json) =
      _$RecurrenceOccurrenceImpl.fromJson;

  @override
  int get id;
  @override
  String get name;
  @override
  String get type;
  @override
  @_DecimalConverter()
  Decimal get amount;
  @override
  @JsonKey(name: 'currency')
  String get currencyCode;
  @override
  String get icon;
  @override
  String get color;
  @override
  DateTime get date;

  /// Create a copy of RecurrenceOccurrence
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecurrenceOccurrenceImplCopyWith<_$RecurrenceOccurrenceImpl>
  get copyWith => throw _privateConstructorUsedError;
}
