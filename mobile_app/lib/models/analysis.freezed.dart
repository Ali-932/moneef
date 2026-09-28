// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analysis.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CategorySummary _$CategorySummaryFromJson(Map<String, dynamic> json) {
  return _CategorySummary.fromJson(json);
}

/// @nodoc
mixin _$CategorySummary {
  @JsonKey(name: 'category_id')
  int get categoryId => throw _privateConstructorUsedError;
  @JsonKey(name: 'category_name')
  String get categoryName => throw _privateConstructorUsedError;
  @_DecimalConverter()
  @JsonKey(name: 'total_amount')
  Decimal get totalAmount => throw _privateConstructorUsedError;
  @_DecimalConverter()
  Decimal get percentage => throw _privateConstructorUsedError;
  String get icon => throw _privateConstructorUsedError;
  String get color => throw _privateConstructorUsedError;

  /// Serializes this CategorySummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CategorySummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CategorySummaryCopyWith<CategorySummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CategorySummaryCopyWith<$Res> {
  factory $CategorySummaryCopyWith(
    CategorySummary value,
    $Res Function(CategorySummary) then,
  ) = _$CategorySummaryCopyWithImpl<$Res, CategorySummary>;
  @useResult
  $Res call({
    @JsonKey(name: 'category_id') int categoryId,
    @JsonKey(name: 'category_name') String categoryName,
    @_DecimalConverter() @JsonKey(name: 'total_amount') Decimal totalAmount,
    @_DecimalConverter() Decimal percentage,
    String icon,
    String color,
  });
}

/// @nodoc
class _$CategorySummaryCopyWithImpl<$Res, $Val extends CategorySummary>
    implements $CategorySummaryCopyWith<$Res> {
  _$CategorySummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CategorySummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categoryId = null,
    Object? categoryName = null,
    Object? totalAmount = null,
    Object? percentage = null,
    Object? icon = null,
    Object? color = null,
  }) {
    return _then(
      _value.copyWith(
            categoryId: null == categoryId
                ? _value.categoryId
                : categoryId // ignore: cast_nullable_to_non_nullable
                      as int,
            categoryName: null == categoryName
                ? _value.categoryName
                : categoryName // ignore: cast_nullable_to_non_nullable
                      as String,
            totalAmount: null == totalAmount
                ? _value.totalAmount
                : totalAmount // ignore: cast_nullable_to_non_nullable
                      as Decimal,
            percentage: null == percentage
                ? _value.percentage
                : percentage // ignore: cast_nullable_to_non_nullable
                      as Decimal,
            icon: null == icon
                ? _value.icon
                : icon // ignore: cast_nullable_to_non_nullable
                      as String,
            color: null == color
                ? _value.color
                : color // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CategorySummaryImplCopyWith<$Res>
    implements $CategorySummaryCopyWith<$Res> {
  factory _$$CategorySummaryImplCopyWith(
    _$CategorySummaryImpl value,
    $Res Function(_$CategorySummaryImpl) then,
  ) = __$$CategorySummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'category_id') int categoryId,
    @JsonKey(name: 'category_name') String categoryName,
    @_DecimalConverter() @JsonKey(name: 'total_amount') Decimal totalAmount,
    @_DecimalConverter() Decimal percentage,
    String icon,
    String color,
  });
}

/// @nodoc
class __$$CategorySummaryImplCopyWithImpl<$Res>
    extends _$CategorySummaryCopyWithImpl<$Res, _$CategorySummaryImpl>
    implements _$$CategorySummaryImplCopyWith<$Res> {
  __$$CategorySummaryImplCopyWithImpl(
    _$CategorySummaryImpl _value,
    $Res Function(_$CategorySummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CategorySummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categoryId = null,
    Object? categoryName = null,
    Object? totalAmount = null,
    Object? percentage = null,
    Object? icon = null,
    Object? color = null,
  }) {
    return _then(
      _$CategorySummaryImpl(
        categoryId: null == categoryId
            ? _value.categoryId
            : categoryId // ignore: cast_nullable_to_non_nullable
                  as int,
        categoryName: null == categoryName
            ? _value.categoryName
            : categoryName // ignore: cast_nullable_to_non_nullable
                  as String,
        totalAmount: null == totalAmount
            ? _value.totalAmount
            : totalAmount // ignore: cast_nullable_to_non_nullable
                  as Decimal,
        percentage: null == percentage
            ? _value.percentage
            : percentage // ignore: cast_nullable_to_non_nullable
                  as Decimal,
        icon: null == icon
            ? _value.icon
            : icon // ignore: cast_nullable_to_non_nullable
                  as String,
        color: null == color
            ? _value.color
            : color // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CategorySummaryImpl implements _CategorySummary {
  const _$CategorySummaryImpl({
    @JsonKey(name: 'category_id') required this.categoryId,
    @JsonKey(name: 'category_name') required this.categoryName,
    @_DecimalConverter()
    @JsonKey(name: 'total_amount')
    required this.totalAmount,
    @_DecimalConverter() required this.percentage,
    this.icon = '',
    this.color = '',
  });

  factory _$CategorySummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$CategorySummaryImplFromJson(json);

  @override
  @JsonKey(name: 'category_id')
  final int categoryId;
  @override
  @JsonKey(name: 'category_name')
  final String categoryName;
  @override
  @_DecimalConverter()
  @JsonKey(name: 'total_amount')
  final Decimal totalAmount;
  @override
  @_DecimalConverter()
  final Decimal percentage;
  @override
  @JsonKey()
  final String icon;
  @override
  @JsonKey()
  final String color;

  @override
  String toString() {
    return 'CategorySummary(categoryId: $categoryId, categoryName: $categoryName, totalAmount: $totalAmount, percentage: $percentage, icon: $icon, color: $color)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CategorySummaryImpl &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.percentage, percentage) ||
                other.percentage == percentage) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.color, color) || other.color == color));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    categoryId,
    categoryName,
    totalAmount,
    percentage,
    icon,
    color,
  );

  /// Create a copy of CategorySummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CategorySummaryImplCopyWith<_$CategorySummaryImpl> get copyWith =>
      __$$CategorySummaryImplCopyWithImpl<_$CategorySummaryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$CategorySummaryImplToJson(this);
  }
}

abstract class _CategorySummary implements CategorySummary {
  const factory _CategorySummary({
    @JsonKey(name: 'category_id') required final int categoryId,
    @JsonKey(name: 'category_name') required final String categoryName,
    @_DecimalConverter()
    @JsonKey(name: 'total_amount')
    required final Decimal totalAmount,
    @_DecimalConverter() required final Decimal percentage,
    final String icon,
    final String color,
  }) = _$CategorySummaryImpl;

  factory _CategorySummary.fromJson(Map<String, dynamic> json) =
      _$CategorySummaryImpl.fromJson;

  @override
  @JsonKey(name: 'category_id')
  int get categoryId;
  @override
  @JsonKey(name: 'category_name')
  String get categoryName;
  @override
  @_DecimalConverter()
  @JsonKey(name: 'total_amount')
  Decimal get totalAmount;
  @override
  @_DecimalConverter()
  Decimal get percentage;
  @override
  String get icon;
  @override
  String get color;

  /// Create a copy of CategorySummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CategorySummaryImplCopyWith<_$CategorySummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AmountPerDay _$AmountPerDayFromJson(Map<String, dynamic> json) {
  return _AmountPerDay.fromJson(json);
}

/// @nodoc
mixin _$AmountPerDay {
  DateTime get date => throw _privateConstructorUsedError;
  @_DecimalConverter()
  Decimal get amount => throw _privateConstructorUsedError;

  /// Serializes this AmountPerDay to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AmountPerDay
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AmountPerDayCopyWith<AmountPerDay> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AmountPerDayCopyWith<$Res> {
  factory $AmountPerDayCopyWith(
    AmountPerDay value,
    $Res Function(AmountPerDay) then,
  ) = _$AmountPerDayCopyWithImpl<$Res, AmountPerDay>;
  @useResult
  $Res call({DateTime date, @_DecimalConverter() Decimal amount});
}

/// @nodoc
class _$AmountPerDayCopyWithImpl<$Res, $Val extends AmountPerDay>
    implements $AmountPerDayCopyWith<$Res> {
  _$AmountPerDayCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AmountPerDay
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? date = null, Object? amount = null}) {
    return _then(
      _value.copyWith(
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as Decimal,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AmountPerDayImplCopyWith<$Res>
    implements $AmountPerDayCopyWith<$Res> {
  factory _$$AmountPerDayImplCopyWith(
    _$AmountPerDayImpl value,
    $Res Function(_$AmountPerDayImpl) then,
  ) = __$$AmountPerDayImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DateTime date, @_DecimalConverter() Decimal amount});
}

/// @nodoc
class __$$AmountPerDayImplCopyWithImpl<$Res>
    extends _$AmountPerDayCopyWithImpl<$Res, _$AmountPerDayImpl>
    implements _$$AmountPerDayImplCopyWith<$Res> {
  __$$AmountPerDayImplCopyWithImpl(
    _$AmountPerDayImpl _value,
    $Res Function(_$AmountPerDayImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AmountPerDay
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? date = null, Object? amount = null}) {
    return _then(
      _$AmountPerDayImpl(
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as Decimal,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AmountPerDayImpl implements _AmountPerDay {
  const _$AmountPerDayImpl({
    required this.date,
    @_DecimalConverter() required this.amount,
  });

  factory _$AmountPerDayImpl.fromJson(Map<String, dynamic> json) =>
      _$$AmountPerDayImplFromJson(json);

  @override
  final DateTime date;
  @override
  @_DecimalConverter()
  final Decimal amount;

  @override
  String toString() {
    return 'AmountPerDay(date: $date, amount: $amount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AmountPerDayImpl &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.amount, amount) || other.amount == amount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, date, amount);

  /// Create a copy of AmountPerDay
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AmountPerDayImplCopyWith<_$AmountPerDayImpl> get copyWith =>
      __$$AmountPerDayImplCopyWithImpl<_$AmountPerDayImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AmountPerDayImplToJson(this);
  }
}

abstract class _AmountPerDay implements AmountPerDay {
  const factory _AmountPerDay({
    required final DateTime date,
    @_DecimalConverter() required final Decimal amount,
  }) = _$AmountPerDayImpl;

  factory _AmountPerDay.fromJson(Map<String, dynamic> json) =
      _$AmountPerDayImpl.fromJson;

  @override
  DateTime get date;
  @override
  @_DecimalConverter()
  Decimal get amount;

  /// Create a copy of AmountPerDay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AmountPerDayImplCopyWith<_$AmountPerDayImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

NextRecurringTransaction _$NextRecurringTransactionFromJson(
  Map<String, dynamic> json,
) {
  return _NextRecurringTransaction.fromJson(json);
}

/// @nodoc
mixin _$NextRecurringTransaction {
  @_DecimalConverter()
  Decimal get amount => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;

  /// Serializes this NextRecurringTransaction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NextRecurringTransaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NextRecurringTransactionCopyWith<NextRecurringTransaction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NextRecurringTransactionCopyWith<$Res> {
  factory $NextRecurringTransactionCopyWith(
    NextRecurringTransaction value,
    $Res Function(NextRecurringTransaction) then,
  ) = _$NextRecurringTransactionCopyWithImpl<$Res, NextRecurringTransaction>;
  @useResult
  $Res call({@_DecimalConverter() Decimal amount, DateTime date, String name});
}

/// @nodoc
class _$NextRecurringTransactionCopyWithImpl<
  $Res,
  $Val extends NextRecurringTransaction
>
    implements $NextRecurringTransactionCopyWith<$Res> {
  _$NextRecurringTransactionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NextRecurringTransaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? amount = null, Object? date = null, Object? name = null}) {
    return _then(
      _value.copyWith(
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as Decimal,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NextRecurringTransactionImplCopyWith<$Res>
    implements $NextRecurringTransactionCopyWith<$Res> {
  factory _$$NextRecurringTransactionImplCopyWith(
    _$NextRecurringTransactionImpl value,
    $Res Function(_$NextRecurringTransactionImpl) then,
  ) = __$$NextRecurringTransactionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({@_DecimalConverter() Decimal amount, DateTime date, String name});
}

/// @nodoc
class __$$NextRecurringTransactionImplCopyWithImpl<$Res>
    extends
        _$NextRecurringTransactionCopyWithImpl<
          $Res,
          _$NextRecurringTransactionImpl
        >
    implements _$$NextRecurringTransactionImplCopyWith<$Res> {
  __$$NextRecurringTransactionImplCopyWithImpl(
    _$NextRecurringTransactionImpl _value,
    $Res Function(_$NextRecurringTransactionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NextRecurringTransaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? amount = null, Object? date = null, Object? name = null}) {
    return _then(
      _$NextRecurringTransactionImpl(
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as Decimal,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NextRecurringTransactionImpl implements _NextRecurringTransaction {
  const _$NextRecurringTransactionImpl({
    @_DecimalConverter() required this.amount,
    required this.date,
    required this.name,
  });

  factory _$NextRecurringTransactionImpl.fromJson(Map<String, dynamic> json) =>
      _$$NextRecurringTransactionImplFromJson(json);

  @override
  @_DecimalConverter()
  final Decimal amount;
  @override
  final DateTime date;
  @override
  final String name;

  @override
  String toString() {
    return 'NextRecurringTransaction(amount: $amount, date: $date, name: $name)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NextRecurringTransactionImpl &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.name, name) || other.name == name));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, amount, date, name);

  /// Create a copy of NextRecurringTransaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NextRecurringTransactionImplCopyWith<_$NextRecurringTransactionImpl>
  get copyWith =>
      __$$NextRecurringTransactionImplCopyWithImpl<
        _$NextRecurringTransactionImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NextRecurringTransactionImplToJson(this);
  }
}

abstract class _NextRecurringTransaction implements NextRecurringTransaction {
  const factory _NextRecurringTransaction({
    @_DecimalConverter() required final Decimal amount,
    required final DateTime date,
    required final String name,
  }) = _$NextRecurringTransactionImpl;

  factory _NextRecurringTransaction.fromJson(Map<String, dynamic> json) =
      _$NextRecurringTransactionImpl.fromJson;

  @override
  @_DecimalConverter()
  Decimal get amount;
  @override
  DateTime get date;
  @override
  String get name;

  /// Create a copy of NextRecurringTransaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NextRecurringTransactionImplCopyWith<_$NextRecurringTransactionImpl>
  get copyWith => throw _privateConstructorUsedError;
}

BiggestTransaction _$BiggestTransactionFromJson(Map<String, dynamic> json) {
  return _BiggestTransaction.fromJson(json);
}

/// @nodoc
mixin _$BiggestTransaction {
  String get name => throw _privateConstructorUsedError;
  @_DecimalConverter()
  Decimal get amount => throw _privateConstructorUsedError;
  String get icon => throw _privateConstructorUsedError;
  String get color => throw _privateConstructorUsedError;

  /// Serializes this BiggestTransaction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BiggestTransaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BiggestTransactionCopyWith<BiggestTransaction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BiggestTransactionCopyWith<$Res> {
  factory $BiggestTransactionCopyWith(
    BiggestTransaction value,
    $Res Function(BiggestTransaction) then,
  ) = _$BiggestTransactionCopyWithImpl<$Res, BiggestTransaction>;
  @useResult
  $Res call({
    String name,
    @_DecimalConverter() Decimal amount,
    String icon,
    String color,
  });
}

/// @nodoc
class _$BiggestTransactionCopyWithImpl<$Res, $Val extends BiggestTransaction>
    implements $BiggestTransactionCopyWith<$Res> {
  _$BiggestTransactionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BiggestTransaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? amount = null,
    Object? icon = null,
    Object? color = null,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as Decimal,
            icon: null == icon
                ? _value.icon
                : icon // ignore: cast_nullable_to_non_nullable
                      as String,
            color: null == color
                ? _value.color
                : color // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BiggestTransactionImplCopyWith<$Res>
    implements $BiggestTransactionCopyWith<$Res> {
  factory _$$BiggestTransactionImplCopyWith(
    _$BiggestTransactionImpl value,
    $Res Function(_$BiggestTransactionImpl) then,
  ) = __$$BiggestTransactionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    @_DecimalConverter() Decimal amount,
    String icon,
    String color,
  });
}

/// @nodoc
class __$$BiggestTransactionImplCopyWithImpl<$Res>
    extends _$BiggestTransactionCopyWithImpl<$Res, _$BiggestTransactionImpl>
    implements _$$BiggestTransactionImplCopyWith<$Res> {
  __$$BiggestTransactionImplCopyWithImpl(
    _$BiggestTransactionImpl _value,
    $Res Function(_$BiggestTransactionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BiggestTransaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? amount = null,
    Object? icon = null,
    Object? color = null,
  }) {
    return _then(
      _$BiggestTransactionImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as Decimal,
        icon: null == icon
            ? _value.icon
            : icon // ignore: cast_nullable_to_non_nullable
                  as String,
        color: null == color
            ? _value.color
            : color // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BiggestTransactionImpl implements _BiggestTransaction {
  const _$BiggestTransactionImpl({
    required this.name,
    @_DecimalConverter() required this.amount,
    this.icon = '',
    this.color = '',
  });

  factory _$BiggestTransactionImpl.fromJson(Map<String, dynamic> json) =>
      _$$BiggestTransactionImplFromJson(json);

  @override
  final String name;
  @override
  @_DecimalConverter()
  final Decimal amount;
  @override
  @JsonKey()
  final String icon;
  @override
  @JsonKey()
  final String color;

  @override
  String toString() {
    return 'BiggestTransaction(name: $name, amount: $amount, icon: $icon, color: $color)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BiggestTransactionImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.color, color) || other.color == color));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, amount, icon, color);

  /// Create a copy of BiggestTransaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BiggestTransactionImplCopyWith<_$BiggestTransactionImpl> get copyWith =>
      __$$BiggestTransactionImplCopyWithImpl<_$BiggestTransactionImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$BiggestTransactionImplToJson(this);
  }
}

abstract class _BiggestTransaction implements BiggestTransaction {
  const factory _BiggestTransaction({
    required final String name,
    @_DecimalConverter() required final Decimal amount,
    final String icon,
    final String color,
  }) = _$BiggestTransactionImpl;

  factory _BiggestTransaction.fromJson(Map<String, dynamic> json) =
      _$BiggestTransactionImpl.fromJson;

  @override
  String get name;
  @override
  @_DecimalConverter()
  Decimal get amount;
  @override
  String get icon;
  @override
  String get color;

  /// Create a copy of BiggestTransaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BiggestTransactionImplCopyWith<_$BiggestTransactionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TopMerchant _$TopMerchantFromJson(Map<String, dynamic> json) {
  return _TopMerchant.fromJson(json);
}

/// @nodoc
mixin _$TopMerchant {
  String get name => throw _privateConstructorUsedError;
  @_DecimalConverter()
  Decimal get amount => throw _privateConstructorUsedError;

  /// Serializes this TopMerchant to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TopMerchant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TopMerchantCopyWith<TopMerchant> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TopMerchantCopyWith<$Res> {
  factory $TopMerchantCopyWith(
    TopMerchant value,
    $Res Function(TopMerchant) then,
  ) = _$TopMerchantCopyWithImpl<$Res, TopMerchant>;
  @useResult
  $Res call({String name, @_DecimalConverter() Decimal amount});
}

/// @nodoc
class _$TopMerchantCopyWithImpl<$Res, $Val extends TopMerchant>
    implements $TopMerchantCopyWith<$Res> {
  _$TopMerchantCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TopMerchant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null, Object? amount = null}) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as Decimal,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TopMerchantImplCopyWith<$Res>
    implements $TopMerchantCopyWith<$Res> {
  factory _$$TopMerchantImplCopyWith(
    _$TopMerchantImpl value,
    $Res Function(_$TopMerchantImpl) then,
  ) = __$$TopMerchantImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, @_DecimalConverter() Decimal amount});
}

/// @nodoc
class __$$TopMerchantImplCopyWithImpl<$Res>
    extends _$TopMerchantCopyWithImpl<$Res, _$TopMerchantImpl>
    implements _$$TopMerchantImplCopyWith<$Res> {
  __$$TopMerchantImplCopyWithImpl(
    _$TopMerchantImpl _value,
    $Res Function(_$TopMerchantImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TopMerchant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null, Object? amount = null}) {
    return _then(
      _$TopMerchantImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as Decimal,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TopMerchantImpl implements _TopMerchant {
  const _$TopMerchantImpl({
    required this.name,
    @_DecimalConverter() required this.amount,
  });

  factory _$TopMerchantImpl.fromJson(Map<String, dynamic> json) =>
      _$$TopMerchantImplFromJson(json);

  @override
  final String name;
  @override
  @_DecimalConverter()
  final Decimal amount;

  @override
  String toString() {
    return 'TopMerchant(name: $name, amount: $amount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TopMerchantImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.amount, amount) || other.amount == amount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, amount);

  /// Create a copy of TopMerchant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TopMerchantImplCopyWith<_$TopMerchantImpl> get copyWith =>
      __$$TopMerchantImplCopyWithImpl<_$TopMerchantImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TopMerchantImplToJson(this);
  }
}

abstract class _TopMerchant implements TopMerchant {
  const factory _TopMerchant({
    required final String name,
    @_DecimalConverter() required final Decimal amount,
  }) = _$TopMerchantImpl;

  factory _TopMerchant.fromJson(Map<String, dynamic> json) =
      _$TopMerchantImpl.fromJson;

  @override
  String get name;
  @override
  @_DecimalConverter()
  Decimal get amount;

  /// Create a copy of TopMerchant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TopMerchantImplCopyWith<_$TopMerchantImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

QuickStats _$QuickStatsFromJson(Map<String, dynamic> json) {
  return _QuickStats.fromJson(json);
}

/// @nodoc
mixin _$QuickStats {
  @_DecimalConverter()
  @JsonKey(name: 'savings_rate')
  Decimal get savingsRate => throw _privateConstructorUsedError;
  @JsonKey(name: 'biggest_transaction')
  BiggestTransaction get biggestTransaction =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'transaction_count')
  int get transactionCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'top_merchant')
  TopMerchant get topMerchant => throw _privateConstructorUsedError;
  @_DecimalConverter()
  @JsonKey(name: 'avg_transaction')
  Decimal get avgTransaction => throw _privateConstructorUsedError;

  /// Serializes this QuickStats to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of QuickStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuickStatsCopyWith<QuickStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuickStatsCopyWith<$Res> {
  factory $QuickStatsCopyWith(
    QuickStats value,
    $Res Function(QuickStats) then,
  ) = _$QuickStatsCopyWithImpl<$Res, QuickStats>;
  @useResult
  $Res call({
    @_DecimalConverter() @JsonKey(name: 'savings_rate') Decimal savingsRate,
    @JsonKey(name: 'biggest_transaction') BiggestTransaction biggestTransaction,
    @JsonKey(name: 'transaction_count') int transactionCount,
    @JsonKey(name: 'top_merchant') TopMerchant topMerchant,
    @_DecimalConverter()
    @JsonKey(name: 'avg_transaction')
    Decimal avgTransaction,
  });

  $BiggestTransactionCopyWith<$Res> get biggestTransaction;
  $TopMerchantCopyWith<$Res> get topMerchant;
}

/// @nodoc
class _$QuickStatsCopyWithImpl<$Res, $Val extends QuickStats>
    implements $QuickStatsCopyWith<$Res> {
  _$QuickStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QuickStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? savingsRate = null,
    Object? biggestTransaction = null,
    Object? transactionCount = null,
    Object? topMerchant = null,
    Object? avgTransaction = null,
  }) {
    return _then(
      _value.copyWith(
            savingsRate: null == savingsRate
                ? _value.savingsRate
                : savingsRate // ignore: cast_nullable_to_non_nullable
                      as Decimal,
            biggestTransaction: null == biggestTransaction
                ? _value.biggestTransaction
                : biggestTransaction // ignore: cast_nullable_to_non_nullable
                      as BiggestTransaction,
            transactionCount: null == transactionCount
                ? _value.transactionCount
                : transactionCount // ignore: cast_nullable_to_non_nullable
                      as int,
            topMerchant: null == topMerchant
                ? _value.topMerchant
                : topMerchant // ignore: cast_nullable_to_non_nullable
                      as TopMerchant,
            avgTransaction: null == avgTransaction
                ? _value.avgTransaction
                : avgTransaction // ignore: cast_nullable_to_non_nullable
                      as Decimal,
          )
          as $Val,
    );
  }

  /// Create a copy of QuickStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BiggestTransactionCopyWith<$Res> get biggestTransaction {
    return $BiggestTransactionCopyWith<$Res>(_value.biggestTransaction, (
      value,
    ) {
      return _then(_value.copyWith(biggestTransaction: value) as $Val);
    });
  }

  /// Create a copy of QuickStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TopMerchantCopyWith<$Res> get topMerchant {
    return $TopMerchantCopyWith<$Res>(_value.topMerchant, (value) {
      return _then(_value.copyWith(topMerchant: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$QuickStatsImplCopyWith<$Res>
    implements $QuickStatsCopyWith<$Res> {
  factory _$$QuickStatsImplCopyWith(
    _$QuickStatsImpl value,
    $Res Function(_$QuickStatsImpl) then,
  ) = __$$QuickStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @_DecimalConverter() @JsonKey(name: 'savings_rate') Decimal savingsRate,
    @JsonKey(name: 'biggest_transaction') BiggestTransaction biggestTransaction,
    @JsonKey(name: 'transaction_count') int transactionCount,
    @JsonKey(name: 'top_merchant') TopMerchant topMerchant,
    @_DecimalConverter()
    @JsonKey(name: 'avg_transaction')
    Decimal avgTransaction,
  });

  @override
  $BiggestTransactionCopyWith<$Res> get biggestTransaction;
  @override
  $TopMerchantCopyWith<$Res> get topMerchant;
}

/// @nodoc
class __$$QuickStatsImplCopyWithImpl<$Res>
    extends _$QuickStatsCopyWithImpl<$Res, _$QuickStatsImpl>
    implements _$$QuickStatsImplCopyWith<$Res> {
  __$$QuickStatsImplCopyWithImpl(
    _$QuickStatsImpl _value,
    $Res Function(_$QuickStatsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of QuickStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? savingsRate = null,
    Object? biggestTransaction = null,
    Object? transactionCount = null,
    Object? topMerchant = null,
    Object? avgTransaction = null,
  }) {
    return _then(
      _$QuickStatsImpl(
        savingsRate: null == savingsRate
            ? _value.savingsRate
            : savingsRate // ignore: cast_nullable_to_non_nullable
                  as Decimal,
        biggestTransaction: null == biggestTransaction
            ? _value.biggestTransaction
            : biggestTransaction // ignore: cast_nullable_to_non_nullable
                  as BiggestTransaction,
        transactionCount: null == transactionCount
            ? _value.transactionCount
            : transactionCount // ignore: cast_nullable_to_non_nullable
                  as int,
        topMerchant: null == topMerchant
            ? _value.topMerchant
            : topMerchant // ignore: cast_nullable_to_non_nullable
                  as TopMerchant,
        avgTransaction: null == avgTransaction
            ? _value.avgTransaction
            : avgTransaction // ignore: cast_nullable_to_non_nullable
                  as Decimal,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$QuickStatsImpl implements _QuickStats {
  const _$QuickStatsImpl({
    @_DecimalConverter()
    @JsonKey(name: 'savings_rate')
    required this.savingsRate,
    @JsonKey(name: 'biggest_transaction') required this.biggestTransaction,
    @JsonKey(name: 'transaction_count') required this.transactionCount,
    @JsonKey(name: 'top_merchant') required this.topMerchant,
    @_DecimalConverter()
    @JsonKey(name: 'avg_transaction')
    required this.avgTransaction,
  });

  factory _$QuickStatsImpl.fromJson(Map<String, dynamic> json) =>
      _$$QuickStatsImplFromJson(json);

  @override
  @_DecimalConverter()
  @JsonKey(name: 'savings_rate')
  final Decimal savingsRate;
  @override
  @JsonKey(name: 'biggest_transaction')
  final BiggestTransaction biggestTransaction;
  @override
  @JsonKey(name: 'transaction_count')
  final int transactionCount;
  @override
  @JsonKey(name: 'top_merchant')
  final TopMerchant topMerchant;
  @override
  @_DecimalConverter()
  @JsonKey(name: 'avg_transaction')
  final Decimal avgTransaction;

  @override
  String toString() {
    return 'QuickStats(savingsRate: $savingsRate, biggestTransaction: $biggestTransaction, transactionCount: $transactionCount, topMerchant: $topMerchant, avgTransaction: $avgTransaction)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuickStatsImpl &&
            (identical(other.savingsRate, savingsRate) ||
                other.savingsRate == savingsRate) &&
            (identical(other.biggestTransaction, biggestTransaction) ||
                other.biggestTransaction == biggestTransaction) &&
            (identical(other.transactionCount, transactionCount) ||
                other.transactionCount == transactionCount) &&
            (identical(other.topMerchant, topMerchant) ||
                other.topMerchant == topMerchant) &&
            (identical(other.avgTransaction, avgTransaction) ||
                other.avgTransaction == avgTransaction));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    savingsRate,
    biggestTransaction,
    transactionCount,
    topMerchant,
    avgTransaction,
  );

  /// Create a copy of QuickStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuickStatsImplCopyWith<_$QuickStatsImpl> get copyWith =>
      __$$QuickStatsImplCopyWithImpl<_$QuickStatsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$QuickStatsImplToJson(this);
  }
}

abstract class _QuickStats implements QuickStats {
  const factory _QuickStats({
    @_DecimalConverter()
    @JsonKey(name: 'savings_rate')
    required final Decimal savingsRate,
    @JsonKey(name: 'biggest_transaction')
    required final BiggestTransaction biggestTransaction,
    @JsonKey(name: 'transaction_count') required final int transactionCount,
    @JsonKey(name: 'top_merchant') required final TopMerchant topMerchant,
    @_DecimalConverter()
    @JsonKey(name: 'avg_transaction')
    required final Decimal avgTransaction,
  }) = _$QuickStatsImpl;

  factory _QuickStats.fromJson(Map<String, dynamic> json) =
      _$QuickStatsImpl.fromJson;

  @override
  @_DecimalConverter()
  @JsonKey(name: 'savings_rate')
  Decimal get savingsRate;
  @override
  @JsonKey(name: 'biggest_transaction')
  BiggestTransaction get biggestTransaction;
  @override
  @JsonKey(name: 'transaction_count')
  int get transactionCount;
  @override
  @JsonKey(name: 'top_merchant')
  TopMerchant get topMerchant;
  @override
  @_DecimalConverter()
  @JsonKey(name: 'avg_transaction')
  Decimal get avgTransaction;

  /// Create a copy of QuickStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuickStatsImplCopyWith<_$QuickStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AnalysisCharts _$AnalysisChartsFromJson(Map<String, dynamic> json) {
  return _AnalysisCharts.fromJson(json);
}

/// @nodoc
mixin _$AnalysisCharts {
  List<CategorySummary> get categories => throw _privateConstructorUsedError;
  @JsonKey(name: 'categories_last_period')
  List<CategorySummary> get categoriesLastPeriod =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'spent_per_day')
  List<AmountPerDay> get spentPerDay => throw _privateConstructorUsedError;
  @JsonKey(name: 'spent_per_day_last_period')
  List<AmountPerDay> get spentPerDayLastPeriod =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'next_recurring_transactions')
  List<NextRecurringTransaction> get nextRecurringTransactions =>
      throw _privateConstructorUsedError;
  @_DecimalConverter()
  Decimal get total => throw _privateConstructorUsedError;
  @JsonKey(name: 'quick_stats')
  QuickStats get quickStats => throw _privateConstructorUsedError;

  /// Serializes this AnalysisCharts to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AnalysisCharts
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnalysisChartsCopyWith<AnalysisCharts> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnalysisChartsCopyWith<$Res> {
  factory $AnalysisChartsCopyWith(
    AnalysisCharts value,
    $Res Function(AnalysisCharts) then,
  ) = _$AnalysisChartsCopyWithImpl<$Res, AnalysisCharts>;
  @useResult
  $Res call({
    List<CategorySummary> categories,
    @JsonKey(name: 'categories_last_period')
    List<CategorySummary> categoriesLastPeriod,
    @JsonKey(name: 'spent_per_day') List<AmountPerDay> spentPerDay,
    @JsonKey(name: 'spent_per_day_last_period')
    List<AmountPerDay> spentPerDayLastPeriod,
    @JsonKey(name: 'next_recurring_transactions')
    List<NextRecurringTransaction> nextRecurringTransactions,
    @_DecimalConverter() Decimal total,
    @JsonKey(name: 'quick_stats') QuickStats quickStats,
  });

  $QuickStatsCopyWith<$Res> get quickStats;
}

/// @nodoc
class _$AnalysisChartsCopyWithImpl<$Res, $Val extends AnalysisCharts>
    implements $AnalysisChartsCopyWith<$Res> {
  _$AnalysisChartsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnalysisCharts
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categories = null,
    Object? categoriesLastPeriod = null,
    Object? spentPerDay = null,
    Object? spentPerDayLastPeriod = null,
    Object? nextRecurringTransactions = null,
    Object? total = null,
    Object? quickStats = null,
  }) {
    return _then(
      _value.copyWith(
            categories: null == categories
                ? _value.categories
                : categories // ignore: cast_nullable_to_non_nullable
                      as List<CategorySummary>,
            categoriesLastPeriod: null == categoriesLastPeriod
                ? _value.categoriesLastPeriod
                : categoriesLastPeriod // ignore: cast_nullable_to_non_nullable
                      as List<CategorySummary>,
            spentPerDay: null == spentPerDay
                ? _value.spentPerDay
                : spentPerDay // ignore: cast_nullable_to_non_nullable
                      as List<AmountPerDay>,
            spentPerDayLastPeriod: null == spentPerDayLastPeriod
                ? _value.spentPerDayLastPeriod
                : spentPerDayLastPeriod // ignore: cast_nullable_to_non_nullable
                      as List<AmountPerDay>,
            nextRecurringTransactions: null == nextRecurringTransactions
                ? _value.nextRecurringTransactions
                : nextRecurringTransactions // ignore: cast_nullable_to_non_nullable
                      as List<NextRecurringTransaction>,
            total: null == total
                ? _value.total
                : total // ignore: cast_nullable_to_non_nullable
                      as Decimal,
            quickStats: null == quickStats
                ? _value.quickStats
                : quickStats // ignore: cast_nullable_to_non_nullable
                      as QuickStats,
          )
          as $Val,
    );
  }

  /// Create a copy of AnalysisCharts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $QuickStatsCopyWith<$Res> get quickStats {
    return $QuickStatsCopyWith<$Res>(_value.quickStats, (value) {
      return _then(_value.copyWith(quickStats: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AnalysisChartsImplCopyWith<$Res>
    implements $AnalysisChartsCopyWith<$Res> {
  factory _$$AnalysisChartsImplCopyWith(
    _$AnalysisChartsImpl value,
    $Res Function(_$AnalysisChartsImpl) then,
  ) = __$$AnalysisChartsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<CategorySummary> categories,
    @JsonKey(name: 'categories_last_period')
    List<CategorySummary> categoriesLastPeriod,
    @JsonKey(name: 'spent_per_day') List<AmountPerDay> spentPerDay,
    @JsonKey(name: 'spent_per_day_last_period')
    List<AmountPerDay> spentPerDayLastPeriod,
    @JsonKey(name: 'next_recurring_transactions')
    List<NextRecurringTransaction> nextRecurringTransactions,
    @_DecimalConverter() Decimal total,
    @JsonKey(name: 'quick_stats') QuickStats quickStats,
  });

  @override
  $QuickStatsCopyWith<$Res> get quickStats;
}

/// @nodoc
class __$$AnalysisChartsImplCopyWithImpl<$Res>
    extends _$AnalysisChartsCopyWithImpl<$Res, _$AnalysisChartsImpl>
    implements _$$AnalysisChartsImplCopyWith<$Res> {
  __$$AnalysisChartsImplCopyWithImpl(
    _$AnalysisChartsImpl _value,
    $Res Function(_$AnalysisChartsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AnalysisCharts
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categories = null,
    Object? categoriesLastPeriod = null,
    Object? spentPerDay = null,
    Object? spentPerDayLastPeriod = null,
    Object? nextRecurringTransactions = null,
    Object? total = null,
    Object? quickStats = null,
  }) {
    return _then(
      _$AnalysisChartsImpl(
        categories: null == categories
            ? _value._categories
            : categories // ignore: cast_nullable_to_non_nullable
                  as List<CategorySummary>,
        categoriesLastPeriod: null == categoriesLastPeriod
            ? _value._categoriesLastPeriod
            : categoriesLastPeriod // ignore: cast_nullable_to_non_nullable
                  as List<CategorySummary>,
        spentPerDay: null == spentPerDay
            ? _value._spentPerDay
            : spentPerDay // ignore: cast_nullable_to_non_nullable
                  as List<AmountPerDay>,
        spentPerDayLastPeriod: null == spentPerDayLastPeriod
            ? _value._spentPerDayLastPeriod
            : spentPerDayLastPeriod // ignore: cast_nullable_to_non_nullable
                  as List<AmountPerDay>,
        nextRecurringTransactions: null == nextRecurringTransactions
            ? _value._nextRecurringTransactions
            : nextRecurringTransactions // ignore: cast_nullable_to_non_nullable
                  as List<NextRecurringTransaction>,
        total: null == total
            ? _value.total
            : total // ignore: cast_nullable_to_non_nullable
                  as Decimal,
        quickStats: null == quickStats
            ? _value.quickStats
            : quickStats // ignore: cast_nullable_to_non_nullable
                  as QuickStats,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AnalysisChartsImpl implements _AnalysisCharts {
  const _$AnalysisChartsImpl({
    final List<CategorySummary> categories = const <CategorySummary>[],
    @JsonKey(name: 'categories_last_period')
    final List<CategorySummary> categoriesLastPeriod =
        const <CategorySummary>[],
    @JsonKey(name: 'spent_per_day')
    final List<AmountPerDay> spentPerDay = const <AmountPerDay>[],
    @JsonKey(name: 'spent_per_day_last_period')
    final List<AmountPerDay> spentPerDayLastPeriod = const <AmountPerDay>[],
    @JsonKey(name: 'next_recurring_transactions')
    final List<NextRecurringTransaction> nextRecurringTransactions =
        const <NextRecurringTransaction>[],
    @_DecimalConverter() required this.total,
    @JsonKey(name: 'quick_stats') required this.quickStats,
  }) : _categories = categories,
       _categoriesLastPeriod = categoriesLastPeriod,
       _spentPerDay = spentPerDay,
       _spentPerDayLastPeriod = spentPerDayLastPeriod,
       _nextRecurringTransactions = nextRecurringTransactions;

  factory _$AnalysisChartsImpl.fromJson(Map<String, dynamic> json) =>
      _$$AnalysisChartsImplFromJson(json);

  final List<CategorySummary> _categories;
  @override
  @JsonKey()
  List<CategorySummary> get categories {
    if (_categories is EqualUnmodifiableListView) return _categories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categories);
  }

  final List<CategorySummary> _categoriesLastPeriod;
  @override
  @JsonKey(name: 'categories_last_period')
  List<CategorySummary> get categoriesLastPeriod {
    if (_categoriesLastPeriod is EqualUnmodifiableListView)
      return _categoriesLastPeriod;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categoriesLastPeriod);
  }

  final List<AmountPerDay> _spentPerDay;
  @override
  @JsonKey(name: 'spent_per_day')
  List<AmountPerDay> get spentPerDay {
    if (_spentPerDay is EqualUnmodifiableListView) return _spentPerDay;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_spentPerDay);
  }

  final List<AmountPerDay> _spentPerDayLastPeriod;
  @override
  @JsonKey(name: 'spent_per_day_last_period')
  List<AmountPerDay> get spentPerDayLastPeriod {
    if (_spentPerDayLastPeriod is EqualUnmodifiableListView)
      return _spentPerDayLastPeriod;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_spentPerDayLastPeriod);
  }

  final List<NextRecurringTransaction> _nextRecurringTransactions;
  @override
  @JsonKey(name: 'next_recurring_transactions')
  List<NextRecurringTransaction> get nextRecurringTransactions {
    if (_nextRecurringTransactions is EqualUnmodifiableListView)
      return _nextRecurringTransactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_nextRecurringTransactions);
  }

  @override
  @_DecimalConverter()
  final Decimal total;
  @override
  @JsonKey(name: 'quick_stats')
  final QuickStats quickStats;

  @override
  String toString() {
    return 'AnalysisCharts(categories: $categories, categoriesLastPeriod: $categoriesLastPeriod, spentPerDay: $spentPerDay, spentPerDayLastPeriod: $spentPerDayLastPeriod, nextRecurringTransactions: $nextRecurringTransactions, total: $total, quickStats: $quickStats)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnalysisChartsImpl &&
            const DeepCollectionEquality().equals(
              other._categories,
              _categories,
            ) &&
            const DeepCollectionEquality().equals(
              other._categoriesLastPeriod,
              _categoriesLastPeriod,
            ) &&
            const DeepCollectionEquality().equals(
              other._spentPerDay,
              _spentPerDay,
            ) &&
            const DeepCollectionEquality().equals(
              other._spentPerDayLastPeriod,
              _spentPerDayLastPeriod,
            ) &&
            const DeepCollectionEquality().equals(
              other._nextRecurringTransactions,
              _nextRecurringTransactions,
            ) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.quickStats, quickStats) ||
                other.quickStats == quickStats));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_categories),
    const DeepCollectionEquality().hash(_categoriesLastPeriod),
    const DeepCollectionEquality().hash(_spentPerDay),
    const DeepCollectionEquality().hash(_spentPerDayLastPeriod),
    const DeepCollectionEquality().hash(_nextRecurringTransactions),
    total,
    quickStats,
  );

  /// Create a copy of AnalysisCharts
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnalysisChartsImplCopyWith<_$AnalysisChartsImpl> get copyWith =>
      __$$AnalysisChartsImplCopyWithImpl<_$AnalysisChartsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AnalysisChartsImplToJson(this);
  }
}

abstract class _AnalysisCharts implements AnalysisCharts {
  const factory _AnalysisCharts({
    final List<CategorySummary> categories,
    @JsonKey(name: 'categories_last_period')
    final List<CategorySummary> categoriesLastPeriod,
    @JsonKey(name: 'spent_per_day') final List<AmountPerDay> spentPerDay,
    @JsonKey(name: 'spent_per_day_last_period')
    final List<AmountPerDay> spentPerDayLastPeriod,
    @JsonKey(name: 'next_recurring_transactions')
    final List<NextRecurringTransaction> nextRecurringTransactions,
    @_DecimalConverter() required final Decimal total,
    @JsonKey(name: 'quick_stats') required final QuickStats quickStats,
  }) = _$AnalysisChartsImpl;

  factory _AnalysisCharts.fromJson(Map<String, dynamic> json) =
      _$AnalysisChartsImpl.fromJson;

  @override
  List<CategorySummary> get categories;
  @override
  @JsonKey(name: 'categories_last_period')
  List<CategorySummary> get categoriesLastPeriod;
  @override
  @JsonKey(name: 'spent_per_day')
  List<AmountPerDay> get spentPerDay;
  @override
  @JsonKey(name: 'spent_per_day_last_period')
  List<AmountPerDay> get spentPerDayLastPeriod;
  @override
  @JsonKey(name: 'next_recurring_transactions')
  List<NextRecurringTransaction> get nextRecurringTransactions;
  @override
  @_DecimalConverter()
  Decimal get total;
  @override
  @JsonKey(name: 'quick_stats')
  QuickStats get quickStats;

  /// Create a copy of AnalysisCharts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnalysisChartsImplCopyWith<_$AnalysisChartsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
