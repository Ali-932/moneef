// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TransactionCategory _$TransactionCategoryFromJson(Map<String, dynamic> json) {
  return _TransactionCategory.fromJson(json);
}

/// @nodoc
mixin _$TransactionCategory {
  int get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'category_id')
  int get categoryId => throw _privateConstructorUsedError;
  @_DecimalConverter()
  Decimal get amount => throw _privateConstructorUsedError;
  @JsonKey(name: 'Category')
  Map<String, dynamic>? get category => throw _privateConstructorUsedError;

  /// Serializes this TransactionCategory to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TransactionCategory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TransactionCategoryCopyWith<TransactionCategory> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TransactionCategoryCopyWith<$Res> {
  factory $TransactionCategoryCopyWith(
    TransactionCategory value,
    $Res Function(TransactionCategory) then,
  ) = _$TransactionCategoryCopyWithImpl<$Res, TransactionCategory>;
  @useResult
  $Res call({
    int id,
    @JsonKey(name: 'category_id') int categoryId,
    @_DecimalConverter() Decimal amount,
    @JsonKey(name: 'Category') Map<String, dynamic>? category,
  });
}

/// @nodoc
class _$TransactionCategoryCopyWithImpl<$Res, $Val extends TransactionCategory>
    implements $TransactionCategoryCopyWith<$Res> {
  _$TransactionCategoryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TransactionCategory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? categoryId = null,
    Object? amount = null,
    Object? category = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            categoryId: null == categoryId
                ? _value.categoryId
                : categoryId // ignore: cast_nullable_to_non_nullable
                      as int,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as Decimal,
            category: freezed == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TransactionCategoryImplCopyWith<$Res>
    implements $TransactionCategoryCopyWith<$Res> {
  factory _$$TransactionCategoryImplCopyWith(
    _$TransactionCategoryImpl value,
    $Res Function(_$TransactionCategoryImpl) then,
  ) = __$$TransactionCategoryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    @JsonKey(name: 'category_id') int categoryId,
    @_DecimalConverter() Decimal amount,
    @JsonKey(name: 'Category') Map<String, dynamic>? category,
  });
}

/// @nodoc
class __$$TransactionCategoryImplCopyWithImpl<$Res>
    extends _$TransactionCategoryCopyWithImpl<$Res, _$TransactionCategoryImpl>
    implements _$$TransactionCategoryImplCopyWith<$Res> {
  __$$TransactionCategoryImplCopyWithImpl(
    _$TransactionCategoryImpl _value,
    $Res Function(_$TransactionCategoryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TransactionCategory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? categoryId = null,
    Object? amount = null,
    Object? category = freezed,
  }) {
    return _then(
      _$TransactionCategoryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        categoryId: null == categoryId
            ? _value.categoryId
            : categoryId // ignore: cast_nullable_to_non_nullable
                  as int,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as Decimal,
        category: freezed == category
            ? _value._category
            : category // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TransactionCategoryImpl implements _TransactionCategory {
  const _$TransactionCategoryImpl({
    required this.id,
    @JsonKey(name: 'category_id') required this.categoryId,
    @_DecimalConverter() required this.amount,
    @JsonKey(name: 'Category') final Map<String, dynamic>? category,
  }) : _category = category;

  factory _$TransactionCategoryImpl.fromJson(Map<String, dynamic> json) =>
      _$$TransactionCategoryImplFromJson(json);

  @override
  final int id;
  @override
  @JsonKey(name: 'category_id')
  final int categoryId;
  @override
  @_DecimalConverter()
  final Decimal amount;
  final Map<String, dynamic>? _category;
  @override
  @JsonKey(name: 'Category')
  Map<String, dynamic>? get category {
    final value = _category;
    if (value == null) return null;
    if (_category is EqualUnmodifiableMapView) return _category;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'TransactionCategory(id: $id, categoryId: $categoryId, amount: $amount, category: $category)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TransactionCategoryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            const DeepCollectionEquality().equals(other._category, _category));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    categoryId,
    amount,
    const DeepCollectionEquality().hash(_category),
  );

  /// Create a copy of TransactionCategory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TransactionCategoryImplCopyWith<_$TransactionCategoryImpl> get copyWith =>
      __$$TransactionCategoryImplCopyWithImpl<_$TransactionCategoryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TransactionCategoryImplToJson(this);
  }
}

abstract class _TransactionCategory implements TransactionCategory {
  const factory _TransactionCategory({
    required final int id,
    @JsonKey(name: 'category_id') required final int categoryId,
    @_DecimalConverter() required final Decimal amount,
    @JsonKey(name: 'Category') final Map<String, dynamic>? category,
  }) = _$TransactionCategoryImpl;

  factory _TransactionCategory.fromJson(Map<String, dynamic> json) =
      _$TransactionCategoryImpl.fromJson;

  @override
  int get id;
  @override
  @JsonKey(name: 'category_id')
  int get categoryId;
  @override
  @_DecimalConverter()
  Decimal get amount;
  @override
  @JsonKey(name: 'Category')
  Map<String, dynamic>? get category;

  /// Create a copy of TransactionCategory
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TransactionCategoryImplCopyWith<_$TransactionCategoryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Transaction _$TransactionFromJson(Map<String, dynamic> json) {
  return _Transaction.fromJson(json);
}

/// @nodoc
mixin _$Transaction {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;
  @JsonKey(name: 'currency_code')
  String get currencyCode => throw _privateConstructorUsedError;
  String get icon => throw _privateConstructorUsedError;
  String get color => throw _privateConstructorUsedError;
  @JsonKey(name: 'merchant_name')
  String get merchantName => throw _privateConstructorUsedError;
  String get notes => throw _privateConstructorUsedError;
  @JsonKey(name: 'TransactionCategory')
  List<TransactionCategory> get categories =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'account_id')
  int? get accountId => throw _privateConstructorUsedError;

  /// Serializes this Transaction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TransactionCopyWith<Transaction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TransactionCopyWith<$Res> {
  factory $TransactionCopyWith(
    Transaction value,
    $Res Function(Transaction) then,
  ) = _$TransactionCopyWithImpl<$Res, Transaction>;
  @useResult
  $Res call({
    int id,
    String name,
    String type,
    DateTime date,
    @JsonKey(name: 'currency_code') String currencyCode,
    String icon,
    String color,
    @JsonKey(name: 'merchant_name') String merchantName,
    String notes,
    @JsonKey(name: 'TransactionCategory') List<TransactionCategory> categories,
    @JsonKey(name: 'account_id') int? accountId,
  });
}

/// @nodoc
class _$TransactionCopyWithImpl<$Res, $Val extends Transaction>
    implements $TransactionCopyWith<$Res> {
  _$TransactionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? date = null,
    Object? currencyCode = null,
    Object? icon = null,
    Object? color = null,
    Object? merchantName = null,
    Object? notes = null,
    Object? categories = null,
    Object? accountId = freezed,
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
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
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
            merchantName: null == merchantName
                ? _value.merchantName
                : merchantName // ignore: cast_nullable_to_non_nullable
                      as String,
            notes: null == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String,
            categories: null == categories
                ? _value.categories
                : categories // ignore: cast_nullable_to_non_nullable
                      as List<TransactionCategory>,
            accountId: freezed == accountId
                ? _value.accountId
                : accountId // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TransactionImplCopyWith<$Res>
    implements $TransactionCopyWith<$Res> {
  factory _$$TransactionImplCopyWith(
    _$TransactionImpl value,
    $Res Function(_$TransactionImpl) then,
  ) = __$$TransactionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    String name,
    String type,
    DateTime date,
    @JsonKey(name: 'currency_code') String currencyCode,
    String icon,
    String color,
    @JsonKey(name: 'merchant_name') String merchantName,
    String notes,
    @JsonKey(name: 'TransactionCategory') List<TransactionCategory> categories,
    @JsonKey(name: 'account_id') int? accountId,
  });
}

/// @nodoc
class __$$TransactionImplCopyWithImpl<$Res>
    extends _$TransactionCopyWithImpl<$Res, _$TransactionImpl>
    implements _$$TransactionImplCopyWith<$Res> {
  __$$TransactionImplCopyWithImpl(
    _$TransactionImpl _value,
    $Res Function(_$TransactionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = null,
    Object? date = null,
    Object? currencyCode = null,
    Object? icon = null,
    Object? color = null,
    Object? merchantName = null,
    Object? notes = null,
    Object? categories = null,
    Object? accountId = freezed,
  }) {
    return _then(
      _$TransactionImpl(
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
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
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
        merchantName: null == merchantName
            ? _value.merchantName
            : merchantName // ignore: cast_nullable_to_non_nullable
                  as String,
        notes: null == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String,
        categories: null == categories
            ? _value._categories
            : categories // ignore: cast_nullable_to_non_nullable
                  as List<TransactionCategory>,
        accountId: freezed == accountId
            ? _value.accountId
            : accountId // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TransactionImpl implements _Transaction {
  const _$TransactionImpl({
    required this.id,
    required this.name,
    required this.type,
    required this.date,
    @JsonKey(name: 'currency_code') required this.currencyCode,
    this.icon = '',
    this.color = '',
    @JsonKey(name: 'merchant_name') this.merchantName = '',
    this.notes = '',
    @JsonKey(name: 'TransactionCategory')
    final List<TransactionCategory> categories = const <TransactionCategory>[],
    @JsonKey(name: 'account_id') this.accountId,
  }) : _categories = categories;

  factory _$TransactionImpl.fromJson(Map<String, dynamic> json) =>
      _$$TransactionImplFromJson(json);

  @override
  final int id;
  @override
  final String name;
  @override
  final String type;
  @override
  final DateTime date;
  @override
  @JsonKey(name: 'currency_code')
  final String currencyCode;
  @override
  @JsonKey()
  final String icon;
  @override
  @JsonKey()
  final String color;
  @override
  @JsonKey(name: 'merchant_name')
  final String merchantName;
  @override
  @JsonKey()
  final String notes;
  final List<TransactionCategory> _categories;
  @override
  @JsonKey(name: 'TransactionCategory')
  List<TransactionCategory> get categories {
    if (_categories is EqualUnmodifiableListView) return _categories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categories);
  }

  @override
  @JsonKey(name: 'account_id')
  final int? accountId;

  @override
  String toString() {
    return 'Transaction(id: $id, name: $name, type: $type, date: $date, currencyCode: $currencyCode, icon: $icon, color: $color, merchantName: $merchantName, notes: $notes, categories: $categories, accountId: $accountId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TransactionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.currencyCode, currencyCode) ||
                other.currencyCode == currencyCode) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.merchantName, merchantName) ||
                other.merchantName == merchantName) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            const DeepCollectionEquality().equals(
              other._categories,
              _categories,
            ) &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    type,
    date,
    currencyCode,
    icon,
    color,
    merchantName,
    notes,
    const DeepCollectionEquality().hash(_categories),
    accountId,
  );

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      __$$TransactionImplCopyWithImpl<_$TransactionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TransactionImplToJson(this);
  }
}

abstract class _Transaction implements Transaction {
  const factory _Transaction({
    required final int id,
    required final String name,
    required final String type,
    required final DateTime date,
    @JsonKey(name: 'currency_code') required final String currencyCode,
    final String icon,
    final String color,
    @JsonKey(name: 'merchant_name') final String merchantName,
    final String notes,
    @JsonKey(name: 'TransactionCategory')
    final List<TransactionCategory> categories,
    @JsonKey(name: 'account_id') final int? accountId,
  }) = _$TransactionImpl;

  factory _Transaction.fromJson(Map<String, dynamic> json) =
      _$TransactionImpl.fromJson;

  @override
  int get id;
  @override
  String get name;
  @override
  String get type;
  @override
  DateTime get date;
  @override
  @JsonKey(name: 'currency_code')
  String get currencyCode;
  @override
  String get icon;
  @override
  String get color;
  @override
  @JsonKey(name: 'merchant_name')
  String get merchantName;
  @override
  String get notes;
  @override
  @JsonKey(name: 'TransactionCategory')
  List<TransactionCategory> get categories;
  @override
  @JsonKey(name: 'account_id')
  int? get accountId;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
