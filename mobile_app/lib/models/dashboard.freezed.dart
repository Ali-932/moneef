// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboard.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

DashboardPeriod _$DashboardPeriodFromJson(Map<String, dynamic> json) {
  return _DashboardPeriod.fromJson(json);
}

/// @nodoc
mixin _$DashboardPeriod {
  @JsonKey(name: 'start_date')
  DateTime get startDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'end_date')
  DateTime get endDate => throw _privateConstructorUsedError;

  /// Serializes this DashboardPeriod to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DashboardPeriod
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DashboardPeriodCopyWith<DashboardPeriod> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardPeriodCopyWith<$Res> {
  factory $DashboardPeriodCopyWith(
    DashboardPeriod value,
    $Res Function(DashboardPeriod) then,
  ) = _$DashboardPeriodCopyWithImpl<$Res, DashboardPeriod>;
  @useResult
  $Res call({
    @JsonKey(name: 'start_date') DateTime startDate,
    @JsonKey(name: 'end_date') DateTime endDate,
  });
}

/// @nodoc
class _$DashboardPeriodCopyWithImpl<$Res, $Val extends DashboardPeriod>
    implements $DashboardPeriodCopyWith<$Res> {
  _$DashboardPeriodCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DashboardPeriod
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? startDate = null, Object? endDate = null}) {
    return _then(
      _value.copyWith(
            startDate: null == startDate
                ? _value.startDate
                : startDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            endDate: null == endDate
                ? _value.endDate
                : endDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DashboardPeriodImplCopyWith<$Res>
    implements $DashboardPeriodCopyWith<$Res> {
  factory _$$DashboardPeriodImplCopyWith(
    _$DashboardPeriodImpl value,
    $Res Function(_$DashboardPeriodImpl) then,
  ) = __$$DashboardPeriodImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'start_date') DateTime startDate,
    @JsonKey(name: 'end_date') DateTime endDate,
  });
}

/// @nodoc
class __$$DashboardPeriodImplCopyWithImpl<$Res>
    extends _$DashboardPeriodCopyWithImpl<$Res, _$DashboardPeriodImpl>
    implements _$$DashboardPeriodImplCopyWith<$Res> {
  __$$DashboardPeriodImplCopyWithImpl(
    _$DashboardPeriodImpl _value,
    $Res Function(_$DashboardPeriodImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DashboardPeriod
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? startDate = null, Object? endDate = null}) {
    return _then(
      _$DashboardPeriodImpl(
        startDate: null == startDate
            ? _value.startDate
            : startDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        endDate: null == endDate
            ? _value.endDate
            : endDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DashboardPeriodImpl implements _DashboardPeriod {
  const _$DashboardPeriodImpl({
    @JsonKey(name: 'start_date') required this.startDate,
    @JsonKey(name: 'end_date') required this.endDate,
  });

  factory _$DashboardPeriodImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardPeriodImplFromJson(json);

  @override
  @JsonKey(name: 'start_date')
  final DateTime startDate;
  @override
  @JsonKey(name: 'end_date')
  final DateTime endDate;

  @override
  String toString() {
    return 'DashboardPeriod(startDate: $startDate, endDate: $endDate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardPeriodImpl &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, startDate, endDate);

  /// Create a copy of DashboardPeriod
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardPeriodImplCopyWith<_$DashboardPeriodImpl> get copyWith =>
      __$$DashboardPeriodImplCopyWithImpl<_$DashboardPeriodImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardPeriodImplToJson(this);
  }
}

abstract class _DashboardPeriod implements DashboardPeriod {
  const factory _DashboardPeriod({
    @JsonKey(name: 'start_date') required final DateTime startDate,
    @JsonKey(name: 'end_date') required final DateTime endDate,
  }) = _$DashboardPeriodImpl;

  factory _DashboardPeriod.fromJson(Map<String, dynamic> json) =
      _$DashboardPeriodImpl.fromJson;

  @override
  @JsonKey(name: 'start_date')
  DateTime get startDate;
  @override
  @JsonKey(name: 'end_date')
  DateTime get endDate;

  /// Create a copy of DashboardPeriod
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardPeriodImplCopyWith<_$DashboardPeriodImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DashboardSummary _$DashboardSummaryFromJson(Map<String, dynamic> json) {
  return _DashboardSummary.fromJson(json);
}

/// @nodoc
mixin _$DashboardSummary {
  DashboardPeriod get period => throw _privateConstructorUsedError;
  @JsonKey(name: 'currency_code')
  String get currencyCode => throw _privateConstructorUsedError;
  @_DecimalConverter()
  Decimal get balance => throw _privateConstructorUsedError;
  @_DecimalConverter()
  @JsonKey(name: 'total_income')
  Decimal get totalIncome => throw _privateConstructorUsedError;
  @_DecimalConverter()
  @JsonKey(name: 'total_expense')
  Decimal get totalExpense => throw _privateConstructorUsedError;
  @JsonKey(name: 'recent_transactions')
  List<Transaction> get recentTransactions =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'quick_stats')
  DashboardQuickStats? get quickStats => throw _privateConstructorUsedError;
  @JsonKey(name: 'upcoming_recurring')
  List<Map<String, dynamic>> get upcomingRecurring =>
      throw _privateConstructorUsedError;

  /// Serializes this DashboardSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DashboardSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DashboardSummaryCopyWith<DashboardSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardSummaryCopyWith<$Res> {
  factory $DashboardSummaryCopyWith(
    DashboardSummary value,
    $Res Function(DashboardSummary) then,
  ) = _$DashboardSummaryCopyWithImpl<$Res, DashboardSummary>;
  @useResult
  $Res call({
    DashboardPeriod period,
    @JsonKey(name: 'currency_code') String currencyCode,
    @_DecimalConverter() Decimal balance,
    @_DecimalConverter() @JsonKey(name: 'total_income') Decimal totalIncome,
    @_DecimalConverter() @JsonKey(name: 'total_expense') Decimal totalExpense,
    @JsonKey(name: 'recent_transactions') List<Transaction> recentTransactions,
    @JsonKey(name: 'quick_stats') DashboardQuickStats? quickStats,
    @JsonKey(name: 'upcoming_recurring')
    List<Map<String, dynamic>> upcomingRecurring,
  });

  $DashboardPeriodCopyWith<$Res> get period;
  $DashboardQuickStatsCopyWith<$Res>? get quickStats;
}

/// @nodoc
class _$DashboardSummaryCopyWithImpl<$Res, $Val extends DashboardSummary>
    implements $DashboardSummaryCopyWith<$Res> {
  _$DashboardSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DashboardSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? period = null,
    Object? currencyCode = null,
    Object? balance = null,
    Object? totalIncome = null,
    Object? totalExpense = null,
    Object? recentTransactions = null,
    Object? quickStats = freezed,
    Object? upcomingRecurring = null,
  }) {
    return _then(
      _value.copyWith(
            period: null == period
                ? _value.period
                : period // ignore: cast_nullable_to_non_nullable
                      as DashboardPeriod,
            currencyCode: null == currencyCode
                ? _value.currencyCode
                : currencyCode // ignore: cast_nullable_to_non_nullable
                      as String,
            balance: null == balance
                ? _value.balance
                : balance // ignore: cast_nullable_to_non_nullable
                      as Decimal,
            totalIncome: null == totalIncome
                ? _value.totalIncome
                : totalIncome // ignore: cast_nullable_to_non_nullable
                      as Decimal,
            totalExpense: null == totalExpense
                ? _value.totalExpense
                : totalExpense // ignore: cast_nullable_to_non_nullable
                      as Decimal,
            recentTransactions: null == recentTransactions
                ? _value.recentTransactions
                : recentTransactions // ignore: cast_nullable_to_non_nullable
                      as List<Transaction>,
            quickStats: freezed == quickStats
                ? _value.quickStats
                : quickStats // ignore: cast_nullable_to_non_nullable
                      as DashboardQuickStats?,
            upcomingRecurring: null == upcomingRecurring
                ? _value.upcomingRecurring
                : upcomingRecurring // ignore: cast_nullable_to_non_nullable
                      as List<Map<String, dynamic>>,
          )
          as $Val,
    );
  }

  /// Create a copy of DashboardSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DashboardPeriodCopyWith<$Res> get period {
    return $DashboardPeriodCopyWith<$Res>(_value.period, (value) {
      return _then(_value.copyWith(period: value) as $Val);
    });
  }

  /// Create a copy of DashboardSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DashboardQuickStatsCopyWith<$Res>? get quickStats {
    if (_value.quickStats == null) {
      return null;
    }

    return $DashboardQuickStatsCopyWith<$Res>(_value.quickStats!, (value) {
      return _then(_value.copyWith(quickStats: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$DashboardSummaryImplCopyWith<$Res>
    implements $DashboardSummaryCopyWith<$Res> {
  factory _$$DashboardSummaryImplCopyWith(
    _$DashboardSummaryImpl value,
    $Res Function(_$DashboardSummaryImpl) then,
  ) = __$$DashboardSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    DashboardPeriod period,
    @JsonKey(name: 'currency_code') String currencyCode,
    @_DecimalConverter() Decimal balance,
    @_DecimalConverter() @JsonKey(name: 'total_income') Decimal totalIncome,
    @_DecimalConverter() @JsonKey(name: 'total_expense') Decimal totalExpense,
    @JsonKey(name: 'recent_transactions') List<Transaction> recentTransactions,
    @JsonKey(name: 'quick_stats') DashboardQuickStats? quickStats,
    @JsonKey(name: 'upcoming_recurring')
    List<Map<String, dynamic>> upcomingRecurring,
  });

  @override
  $DashboardPeriodCopyWith<$Res> get period;
  @override
  $DashboardQuickStatsCopyWith<$Res>? get quickStats;
}

/// @nodoc
class __$$DashboardSummaryImplCopyWithImpl<$Res>
    extends _$DashboardSummaryCopyWithImpl<$Res, _$DashboardSummaryImpl>
    implements _$$DashboardSummaryImplCopyWith<$Res> {
  __$$DashboardSummaryImplCopyWithImpl(
    _$DashboardSummaryImpl _value,
    $Res Function(_$DashboardSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DashboardSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? period = null,
    Object? currencyCode = null,
    Object? balance = null,
    Object? totalIncome = null,
    Object? totalExpense = null,
    Object? recentTransactions = null,
    Object? quickStats = freezed,
    Object? upcomingRecurring = null,
  }) {
    return _then(
      _$DashboardSummaryImpl(
        period: null == period
            ? _value.period
            : period // ignore: cast_nullable_to_non_nullable
                  as DashboardPeriod,
        currencyCode: null == currencyCode
            ? _value.currencyCode
            : currencyCode // ignore: cast_nullable_to_non_nullable
                  as String,
        balance: null == balance
            ? _value.balance
            : balance // ignore: cast_nullable_to_non_nullable
                  as Decimal,
        totalIncome: null == totalIncome
            ? _value.totalIncome
            : totalIncome // ignore: cast_nullable_to_non_nullable
                  as Decimal,
        totalExpense: null == totalExpense
            ? _value.totalExpense
            : totalExpense // ignore: cast_nullable_to_non_nullable
                  as Decimal,
        recentTransactions: null == recentTransactions
            ? _value._recentTransactions
            : recentTransactions // ignore: cast_nullable_to_non_nullable
                  as List<Transaction>,
        quickStats: freezed == quickStats
            ? _value.quickStats
            : quickStats // ignore: cast_nullable_to_non_nullable
                  as DashboardQuickStats?,
        upcomingRecurring: null == upcomingRecurring
            ? _value._upcomingRecurring
            : upcomingRecurring // ignore: cast_nullable_to_non_nullable
                  as List<Map<String, dynamic>>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DashboardSummaryImpl implements _DashboardSummary {
  const _$DashboardSummaryImpl({
    required this.period,
    @JsonKey(name: 'currency_code') required this.currencyCode,
    @_DecimalConverter() required this.balance,
    @_DecimalConverter()
    @JsonKey(name: 'total_income')
    required this.totalIncome,
    @_DecimalConverter()
    @JsonKey(name: 'total_expense')
    required this.totalExpense,
    @JsonKey(name: 'recent_transactions')
    final List<Transaction> recentTransactions = const <Transaction>[],
    @JsonKey(name: 'quick_stats') this.quickStats,
    @JsonKey(name: 'upcoming_recurring')
    final List<Map<String, dynamic>> upcomingRecurring =
        const <Map<String, dynamic>>[],
  }) : _recentTransactions = recentTransactions,
       _upcomingRecurring = upcomingRecurring;

  factory _$DashboardSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardSummaryImplFromJson(json);

  @override
  final DashboardPeriod period;
  @override
  @JsonKey(name: 'currency_code')
  final String currencyCode;
  @override
  @_DecimalConverter()
  final Decimal balance;
  @override
  @_DecimalConverter()
  @JsonKey(name: 'total_income')
  final Decimal totalIncome;
  @override
  @_DecimalConverter()
  @JsonKey(name: 'total_expense')
  final Decimal totalExpense;
  final List<Transaction> _recentTransactions;
  @override
  @JsonKey(name: 'recent_transactions')
  List<Transaction> get recentTransactions {
    if (_recentTransactions is EqualUnmodifiableListView)
      return _recentTransactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recentTransactions);
  }

  @override
  @JsonKey(name: 'quick_stats')
  final DashboardQuickStats? quickStats;
  final List<Map<String, dynamic>> _upcomingRecurring;
  @override
  @JsonKey(name: 'upcoming_recurring')
  List<Map<String, dynamic>> get upcomingRecurring {
    if (_upcomingRecurring is EqualUnmodifiableListView)
      return _upcomingRecurring;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_upcomingRecurring);
  }

  @override
  String toString() {
    return 'DashboardSummary(period: $period, currencyCode: $currencyCode, balance: $balance, totalIncome: $totalIncome, totalExpense: $totalExpense, recentTransactions: $recentTransactions, quickStats: $quickStats, upcomingRecurring: $upcomingRecurring)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardSummaryImpl &&
            (identical(other.period, period) || other.period == period) &&
            (identical(other.currencyCode, currencyCode) ||
                other.currencyCode == currencyCode) &&
            (identical(other.balance, balance) || other.balance == balance) &&
            (identical(other.totalIncome, totalIncome) ||
                other.totalIncome == totalIncome) &&
            (identical(other.totalExpense, totalExpense) ||
                other.totalExpense == totalExpense) &&
            const DeepCollectionEquality().equals(
              other._recentTransactions,
              _recentTransactions,
            ) &&
            (identical(other.quickStats, quickStats) ||
                other.quickStats == quickStats) &&
            const DeepCollectionEquality().equals(
              other._upcomingRecurring,
              _upcomingRecurring,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    period,
    currencyCode,
    balance,
    totalIncome,
    totalExpense,
    const DeepCollectionEquality().hash(_recentTransactions),
    quickStats,
    const DeepCollectionEquality().hash(_upcomingRecurring),
  );

  /// Create a copy of DashboardSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardSummaryImplCopyWith<_$DashboardSummaryImpl> get copyWith =>
      __$$DashboardSummaryImplCopyWithImpl<_$DashboardSummaryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardSummaryImplToJson(this);
  }
}

abstract class _DashboardSummary implements DashboardSummary {
  const factory _DashboardSummary({
    required final DashboardPeriod period,
    @JsonKey(name: 'currency_code') required final String currencyCode,
    @_DecimalConverter() required final Decimal balance,
    @_DecimalConverter()
    @JsonKey(name: 'total_income')
    required final Decimal totalIncome,
    @_DecimalConverter()
    @JsonKey(name: 'total_expense')
    required final Decimal totalExpense,
    @JsonKey(name: 'recent_transactions')
    final List<Transaction> recentTransactions,
    @JsonKey(name: 'quick_stats') final DashboardQuickStats? quickStats,
    @JsonKey(name: 'upcoming_recurring')
    final List<Map<String, dynamic>> upcomingRecurring,
  }) = _$DashboardSummaryImpl;

  factory _DashboardSummary.fromJson(Map<String, dynamic> json) =
      _$DashboardSummaryImpl.fromJson;

  @override
  DashboardPeriod get period;
  @override
  @JsonKey(name: 'currency_code')
  String get currencyCode;
  @override
  @_DecimalConverter()
  Decimal get balance;
  @override
  @_DecimalConverter()
  @JsonKey(name: 'total_income')
  Decimal get totalIncome;
  @override
  @_DecimalConverter()
  @JsonKey(name: 'total_expense')
  Decimal get totalExpense;
  @override
  @JsonKey(name: 'recent_transactions')
  List<Transaction> get recentTransactions;
  @override
  @JsonKey(name: 'quick_stats')
  DashboardQuickStats? get quickStats;
  @override
  @JsonKey(name: 'upcoming_recurring')
  List<Map<String, dynamic>> get upcomingRecurring;

  /// Create a copy of DashboardSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardSummaryImplCopyWith<_$DashboardSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DashboardQuickStats _$DashboardQuickStatsFromJson(Map<String, dynamic> json) {
  return _DashboardQuickStats.fromJson(json);
}

/// @nodoc
mixin _$DashboardQuickStats {
  @JsonKey(name: 'top_category')
  DashboardCategoryStat? get topCategory => throw _privateConstructorUsedError;
  @_DecimalConverter()
  @JsonKey(name: 'avg_daily_spend')
  Decimal get avgDailySpend => throw _privateConstructorUsedError;
  @JsonKey(name: 'transaction_count')
  int get transactionCount => throw _privateConstructorUsedError;
  @_DecimalConverter()
  @JsonKey(name: 'savings_rate')
  Decimal get savingsRate => throw _privateConstructorUsedError;
  @JsonKey(name: 'biggest_transaction')
  DashboardBiggestTransaction get biggestTransaction =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'top_merchant')
  DashboardTopMerchant get topMerchant => throw _privateConstructorUsedError;
  @_DecimalConverter()
  @JsonKey(name: 'avg_transaction')
  Decimal get avgTransaction => throw _privateConstructorUsedError;

  /// Serializes this DashboardQuickStats to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DashboardQuickStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DashboardQuickStatsCopyWith<DashboardQuickStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardQuickStatsCopyWith<$Res> {
  factory $DashboardQuickStatsCopyWith(
    DashboardQuickStats value,
    $Res Function(DashboardQuickStats) then,
  ) = _$DashboardQuickStatsCopyWithImpl<$Res, DashboardQuickStats>;
  @useResult
  $Res call({
    @JsonKey(name: 'top_category') DashboardCategoryStat? topCategory,
    @_DecimalConverter()
    @JsonKey(name: 'avg_daily_spend')
    Decimal avgDailySpend,
    @JsonKey(name: 'transaction_count') int transactionCount,
    @_DecimalConverter() @JsonKey(name: 'savings_rate') Decimal savingsRate,
    @JsonKey(name: 'biggest_transaction')
    DashboardBiggestTransaction biggestTransaction,
    @JsonKey(name: 'top_merchant') DashboardTopMerchant topMerchant,
    @_DecimalConverter()
    @JsonKey(name: 'avg_transaction')
    Decimal avgTransaction,
  });

  $DashboardCategoryStatCopyWith<$Res>? get topCategory;
  $DashboardBiggestTransactionCopyWith<$Res> get biggestTransaction;
  $DashboardTopMerchantCopyWith<$Res> get topMerchant;
}

/// @nodoc
class _$DashboardQuickStatsCopyWithImpl<$Res, $Val extends DashboardQuickStats>
    implements $DashboardQuickStatsCopyWith<$Res> {
  _$DashboardQuickStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DashboardQuickStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? topCategory = freezed,
    Object? avgDailySpend = null,
    Object? transactionCount = null,
    Object? savingsRate = null,
    Object? biggestTransaction = null,
    Object? topMerchant = null,
    Object? avgTransaction = null,
  }) {
    return _then(
      _value.copyWith(
            topCategory: freezed == topCategory
                ? _value.topCategory
                : topCategory // ignore: cast_nullable_to_non_nullable
                      as DashboardCategoryStat?,
            avgDailySpend: null == avgDailySpend
                ? _value.avgDailySpend
                : avgDailySpend // ignore: cast_nullable_to_non_nullable
                      as Decimal,
            transactionCount: null == transactionCount
                ? _value.transactionCount
                : transactionCount // ignore: cast_nullable_to_non_nullable
                      as int,
            savingsRate: null == savingsRate
                ? _value.savingsRate
                : savingsRate // ignore: cast_nullable_to_non_nullable
                      as Decimal,
            biggestTransaction: null == biggestTransaction
                ? _value.biggestTransaction
                : biggestTransaction // ignore: cast_nullable_to_non_nullable
                      as DashboardBiggestTransaction,
            topMerchant: null == topMerchant
                ? _value.topMerchant
                : topMerchant // ignore: cast_nullable_to_non_nullable
                      as DashboardTopMerchant,
            avgTransaction: null == avgTransaction
                ? _value.avgTransaction
                : avgTransaction // ignore: cast_nullable_to_non_nullable
                      as Decimal,
          )
          as $Val,
    );
  }

  /// Create a copy of DashboardQuickStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DashboardCategoryStatCopyWith<$Res>? get topCategory {
    if (_value.topCategory == null) {
      return null;
    }

    return $DashboardCategoryStatCopyWith<$Res>(_value.topCategory!, (value) {
      return _then(_value.copyWith(topCategory: value) as $Val);
    });
  }

  /// Create a copy of DashboardQuickStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DashboardBiggestTransactionCopyWith<$Res> get biggestTransaction {
    return $DashboardBiggestTransactionCopyWith<$Res>(
      _value.biggestTransaction,
      (value) {
        return _then(_value.copyWith(biggestTransaction: value) as $Val);
      },
    );
  }

  /// Create a copy of DashboardQuickStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DashboardTopMerchantCopyWith<$Res> get topMerchant {
    return $DashboardTopMerchantCopyWith<$Res>(_value.topMerchant, (value) {
      return _then(_value.copyWith(topMerchant: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$DashboardQuickStatsImplCopyWith<$Res>
    implements $DashboardQuickStatsCopyWith<$Res> {
  factory _$$DashboardQuickStatsImplCopyWith(
    _$DashboardQuickStatsImpl value,
    $Res Function(_$DashboardQuickStatsImpl) then,
  ) = __$$DashboardQuickStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'top_category') DashboardCategoryStat? topCategory,
    @_DecimalConverter()
    @JsonKey(name: 'avg_daily_spend')
    Decimal avgDailySpend,
    @JsonKey(name: 'transaction_count') int transactionCount,
    @_DecimalConverter() @JsonKey(name: 'savings_rate') Decimal savingsRate,
    @JsonKey(name: 'biggest_transaction')
    DashboardBiggestTransaction biggestTransaction,
    @JsonKey(name: 'top_merchant') DashboardTopMerchant topMerchant,
    @_DecimalConverter()
    @JsonKey(name: 'avg_transaction')
    Decimal avgTransaction,
  });

  @override
  $DashboardCategoryStatCopyWith<$Res>? get topCategory;
  @override
  $DashboardBiggestTransactionCopyWith<$Res> get biggestTransaction;
  @override
  $DashboardTopMerchantCopyWith<$Res> get topMerchant;
}

/// @nodoc
class __$$DashboardQuickStatsImplCopyWithImpl<$Res>
    extends _$DashboardQuickStatsCopyWithImpl<$Res, _$DashboardQuickStatsImpl>
    implements _$$DashboardQuickStatsImplCopyWith<$Res> {
  __$$DashboardQuickStatsImplCopyWithImpl(
    _$DashboardQuickStatsImpl _value,
    $Res Function(_$DashboardQuickStatsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DashboardQuickStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? topCategory = freezed,
    Object? avgDailySpend = null,
    Object? transactionCount = null,
    Object? savingsRate = null,
    Object? biggestTransaction = null,
    Object? topMerchant = null,
    Object? avgTransaction = null,
  }) {
    return _then(
      _$DashboardQuickStatsImpl(
        topCategory: freezed == topCategory
            ? _value.topCategory
            : topCategory // ignore: cast_nullable_to_non_nullable
                  as DashboardCategoryStat?,
        avgDailySpend: null == avgDailySpend
            ? _value.avgDailySpend
            : avgDailySpend // ignore: cast_nullable_to_non_nullable
                  as Decimal,
        transactionCount: null == transactionCount
            ? _value.transactionCount
            : transactionCount // ignore: cast_nullable_to_non_nullable
                  as int,
        savingsRate: null == savingsRate
            ? _value.savingsRate
            : savingsRate // ignore: cast_nullable_to_non_nullable
                  as Decimal,
        biggestTransaction: null == biggestTransaction
            ? _value.biggestTransaction
            : biggestTransaction // ignore: cast_nullable_to_non_nullable
                  as DashboardBiggestTransaction,
        topMerchant: null == topMerchant
            ? _value.topMerchant
            : topMerchant // ignore: cast_nullable_to_non_nullable
                  as DashboardTopMerchant,
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
class _$DashboardQuickStatsImpl implements _DashboardQuickStats {
  const _$DashboardQuickStatsImpl({
    @JsonKey(name: 'top_category') this.topCategory,
    @_DecimalConverter()
    @JsonKey(name: 'avg_daily_spend')
    required this.avgDailySpend,
    @JsonKey(name: 'transaction_count') required this.transactionCount,
    @_DecimalConverter()
    @JsonKey(name: 'savings_rate')
    required this.savingsRate,
    @JsonKey(name: 'biggest_transaction') required this.biggestTransaction,
    @JsonKey(name: 'top_merchant') required this.topMerchant,
    @_DecimalConverter()
    @JsonKey(name: 'avg_transaction')
    required this.avgTransaction,
  });

  factory _$DashboardQuickStatsImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardQuickStatsImplFromJson(json);

  @override
  @JsonKey(name: 'top_category')
  final DashboardCategoryStat? topCategory;
  @override
  @_DecimalConverter()
  @JsonKey(name: 'avg_daily_spend')
  final Decimal avgDailySpend;
  @override
  @JsonKey(name: 'transaction_count')
  final int transactionCount;
  @override
  @_DecimalConverter()
  @JsonKey(name: 'savings_rate')
  final Decimal savingsRate;
  @override
  @JsonKey(name: 'biggest_transaction')
  final DashboardBiggestTransaction biggestTransaction;
  @override
  @JsonKey(name: 'top_merchant')
  final DashboardTopMerchant topMerchant;
  @override
  @_DecimalConverter()
  @JsonKey(name: 'avg_transaction')
  final Decimal avgTransaction;

  @override
  String toString() {
    return 'DashboardQuickStats(topCategory: $topCategory, avgDailySpend: $avgDailySpend, transactionCount: $transactionCount, savingsRate: $savingsRate, biggestTransaction: $biggestTransaction, topMerchant: $topMerchant, avgTransaction: $avgTransaction)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardQuickStatsImpl &&
            (identical(other.topCategory, topCategory) ||
                other.topCategory == topCategory) &&
            (identical(other.avgDailySpend, avgDailySpend) ||
                other.avgDailySpend == avgDailySpend) &&
            (identical(other.transactionCount, transactionCount) ||
                other.transactionCount == transactionCount) &&
            (identical(other.savingsRate, savingsRate) ||
                other.savingsRate == savingsRate) &&
            (identical(other.biggestTransaction, biggestTransaction) ||
                other.biggestTransaction == biggestTransaction) &&
            (identical(other.topMerchant, topMerchant) ||
                other.topMerchant == topMerchant) &&
            (identical(other.avgTransaction, avgTransaction) ||
                other.avgTransaction == avgTransaction));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    topCategory,
    avgDailySpend,
    transactionCount,
    savingsRate,
    biggestTransaction,
    topMerchant,
    avgTransaction,
  );

  /// Create a copy of DashboardQuickStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardQuickStatsImplCopyWith<_$DashboardQuickStatsImpl> get copyWith =>
      __$$DashboardQuickStatsImplCopyWithImpl<_$DashboardQuickStatsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardQuickStatsImplToJson(this);
  }
}

abstract class _DashboardQuickStats implements DashboardQuickStats {
  const factory _DashboardQuickStats({
    @JsonKey(name: 'top_category') final DashboardCategoryStat? topCategory,
    @_DecimalConverter()
    @JsonKey(name: 'avg_daily_spend')
    required final Decimal avgDailySpend,
    @JsonKey(name: 'transaction_count') required final int transactionCount,
    @_DecimalConverter()
    @JsonKey(name: 'savings_rate')
    required final Decimal savingsRate,
    @JsonKey(name: 'biggest_transaction')
    required final DashboardBiggestTransaction biggestTransaction,
    @JsonKey(name: 'top_merchant')
    required final DashboardTopMerchant topMerchant,
    @_DecimalConverter()
    @JsonKey(name: 'avg_transaction')
    required final Decimal avgTransaction,
  }) = _$DashboardQuickStatsImpl;

  factory _DashboardQuickStats.fromJson(Map<String, dynamic> json) =
      _$DashboardQuickStatsImpl.fromJson;

  @override
  @JsonKey(name: 'top_category')
  DashboardCategoryStat? get topCategory;
  @override
  @_DecimalConverter()
  @JsonKey(name: 'avg_daily_spend')
  Decimal get avgDailySpend;
  @override
  @JsonKey(name: 'transaction_count')
  int get transactionCount;
  @override
  @_DecimalConverter()
  @JsonKey(name: 'savings_rate')
  Decimal get savingsRate;
  @override
  @JsonKey(name: 'biggest_transaction')
  DashboardBiggestTransaction get biggestTransaction;
  @override
  @JsonKey(name: 'top_merchant')
  DashboardTopMerchant get topMerchant;
  @override
  @_DecimalConverter()
  @JsonKey(name: 'avg_transaction')
  Decimal get avgTransaction;

  /// Create a copy of DashboardQuickStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardQuickStatsImplCopyWith<_$DashboardQuickStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DashboardCategoryStat _$DashboardCategoryStatFromJson(
  Map<String, dynamic> json,
) {
  return _DashboardCategoryStat.fromJson(json);
}

/// @nodoc
mixin _$DashboardCategoryStat {
  @JsonKey(name: 'category_id')
  int get categoryId => throw _privateConstructorUsedError;
  @JsonKey(name: 'category_name')
  String get categoryName => throw _privateConstructorUsedError;
  @_DecimalConverter()
  @JsonKey(name: 'total_amount')
  Decimal get totalAmount => throw _privateConstructorUsedError;

  /// Serializes this DashboardCategoryStat to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DashboardCategoryStat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DashboardCategoryStatCopyWith<DashboardCategoryStat> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardCategoryStatCopyWith<$Res> {
  factory $DashboardCategoryStatCopyWith(
    DashboardCategoryStat value,
    $Res Function(DashboardCategoryStat) then,
  ) = _$DashboardCategoryStatCopyWithImpl<$Res, DashboardCategoryStat>;
  @useResult
  $Res call({
    @JsonKey(name: 'category_id') int categoryId,
    @JsonKey(name: 'category_name') String categoryName,
    @_DecimalConverter() @JsonKey(name: 'total_amount') Decimal totalAmount,
  });
}

/// @nodoc
class _$DashboardCategoryStatCopyWithImpl<
  $Res,
  $Val extends DashboardCategoryStat
>
    implements $DashboardCategoryStatCopyWith<$Res> {
  _$DashboardCategoryStatCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DashboardCategoryStat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categoryId = null,
    Object? categoryName = null,
    Object? totalAmount = null,
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
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DashboardCategoryStatImplCopyWith<$Res>
    implements $DashboardCategoryStatCopyWith<$Res> {
  factory _$$DashboardCategoryStatImplCopyWith(
    _$DashboardCategoryStatImpl value,
    $Res Function(_$DashboardCategoryStatImpl) then,
  ) = __$$DashboardCategoryStatImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'category_id') int categoryId,
    @JsonKey(name: 'category_name') String categoryName,
    @_DecimalConverter() @JsonKey(name: 'total_amount') Decimal totalAmount,
  });
}

/// @nodoc
class __$$DashboardCategoryStatImplCopyWithImpl<$Res>
    extends
        _$DashboardCategoryStatCopyWithImpl<$Res, _$DashboardCategoryStatImpl>
    implements _$$DashboardCategoryStatImplCopyWith<$Res> {
  __$$DashboardCategoryStatImplCopyWithImpl(
    _$DashboardCategoryStatImpl _value,
    $Res Function(_$DashboardCategoryStatImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DashboardCategoryStat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categoryId = null,
    Object? categoryName = null,
    Object? totalAmount = null,
  }) {
    return _then(
      _$DashboardCategoryStatImpl(
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
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DashboardCategoryStatImpl implements _DashboardCategoryStat {
  const _$DashboardCategoryStatImpl({
    @JsonKey(name: 'category_id') required this.categoryId,
    @JsonKey(name: 'category_name') required this.categoryName,
    @_DecimalConverter()
    @JsonKey(name: 'total_amount')
    required this.totalAmount,
  });

  factory _$DashboardCategoryStatImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardCategoryStatImplFromJson(json);

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
  String toString() {
    return 'DashboardCategoryStat(categoryId: $categoryId, categoryName: $categoryName, totalAmount: $totalAmount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardCategoryStatImpl &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, categoryId, categoryName, totalAmount);

  /// Create a copy of DashboardCategoryStat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardCategoryStatImplCopyWith<_$DashboardCategoryStatImpl>
  get copyWith =>
      __$$DashboardCategoryStatImplCopyWithImpl<_$DashboardCategoryStatImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardCategoryStatImplToJson(this);
  }
}

abstract class _DashboardCategoryStat implements DashboardCategoryStat {
  const factory _DashboardCategoryStat({
    @JsonKey(name: 'category_id') required final int categoryId,
    @JsonKey(name: 'category_name') required final String categoryName,
    @_DecimalConverter()
    @JsonKey(name: 'total_amount')
    required final Decimal totalAmount,
  }) = _$DashboardCategoryStatImpl;

  factory _DashboardCategoryStat.fromJson(Map<String, dynamic> json) =
      _$DashboardCategoryStatImpl.fromJson;

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

  /// Create a copy of DashboardCategoryStat
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardCategoryStatImplCopyWith<_$DashboardCategoryStatImpl>
  get copyWith => throw _privateConstructorUsedError;
}

DashboardBiggestTransaction _$DashboardBiggestTransactionFromJson(
  Map<String, dynamic> json,
) {
  return _DashboardBiggestTransaction.fromJson(json);
}

/// @nodoc
mixin _$DashboardBiggestTransaction {
  String get name => throw _privateConstructorUsedError;
  @_DecimalConverter()
  Decimal get amount => throw _privateConstructorUsedError;
  String get icon => throw _privateConstructorUsedError;
  String get color => throw _privateConstructorUsedError;

  /// Serializes this DashboardBiggestTransaction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DashboardBiggestTransaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DashboardBiggestTransactionCopyWith<DashboardBiggestTransaction>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardBiggestTransactionCopyWith<$Res> {
  factory $DashboardBiggestTransactionCopyWith(
    DashboardBiggestTransaction value,
    $Res Function(DashboardBiggestTransaction) then,
  ) =
      _$DashboardBiggestTransactionCopyWithImpl<
        $Res,
        DashboardBiggestTransaction
      >;
  @useResult
  $Res call({
    String name,
    @_DecimalConverter() Decimal amount,
    String icon,
    String color,
  });
}

/// @nodoc
class _$DashboardBiggestTransactionCopyWithImpl<
  $Res,
  $Val extends DashboardBiggestTransaction
>
    implements $DashboardBiggestTransactionCopyWith<$Res> {
  _$DashboardBiggestTransactionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DashboardBiggestTransaction
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
abstract class _$$DashboardBiggestTransactionImplCopyWith<$Res>
    implements $DashboardBiggestTransactionCopyWith<$Res> {
  factory _$$DashboardBiggestTransactionImplCopyWith(
    _$DashboardBiggestTransactionImpl value,
    $Res Function(_$DashboardBiggestTransactionImpl) then,
  ) = __$$DashboardBiggestTransactionImplCopyWithImpl<$Res>;
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
class __$$DashboardBiggestTransactionImplCopyWithImpl<$Res>
    extends
        _$DashboardBiggestTransactionCopyWithImpl<
          $Res,
          _$DashboardBiggestTransactionImpl
        >
    implements _$$DashboardBiggestTransactionImplCopyWith<$Res> {
  __$$DashboardBiggestTransactionImplCopyWithImpl(
    _$DashboardBiggestTransactionImpl _value,
    $Res Function(_$DashboardBiggestTransactionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DashboardBiggestTransaction
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
      _$DashboardBiggestTransactionImpl(
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
class _$DashboardBiggestTransactionImpl
    implements _DashboardBiggestTransaction {
  const _$DashboardBiggestTransactionImpl({
    this.name = '',
    @_DecimalConverter() required this.amount,
    this.icon = '',
    this.color = '',
  });

  factory _$DashboardBiggestTransactionImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$DashboardBiggestTransactionImplFromJson(json);

  @override
  @JsonKey()
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
    return 'DashboardBiggestTransaction(name: $name, amount: $amount, icon: $icon, color: $color)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardBiggestTransactionImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.color, color) || other.color == color));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, amount, icon, color);

  /// Create a copy of DashboardBiggestTransaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardBiggestTransactionImplCopyWith<_$DashboardBiggestTransactionImpl>
  get copyWith =>
      __$$DashboardBiggestTransactionImplCopyWithImpl<
        _$DashboardBiggestTransactionImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardBiggestTransactionImplToJson(this);
  }
}

abstract class _DashboardBiggestTransaction
    implements DashboardBiggestTransaction {
  const factory _DashboardBiggestTransaction({
    final String name,
    @_DecimalConverter() required final Decimal amount,
    final String icon,
    final String color,
  }) = _$DashboardBiggestTransactionImpl;

  factory _DashboardBiggestTransaction.fromJson(Map<String, dynamic> json) =
      _$DashboardBiggestTransactionImpl.fromJson;

  @override
  String get name;
  @override
  @_DecimalConverter()
  Decimal get amount;
  @override
  String get icon;
  @override
  String get color;

  /// Create a copy of DashboardBiggestTransaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardBiggestTransactionImplCopyWith<_$DashboardBiggestTransactionImpl>
  get copyWith => throw _privateConstructorUsedError;
}

DashboardTopMerchant _$DashboardTopMerchantFromJson(Map<String, dynamic> json) {
  return _DashboardTopMerchant.fromJson(json);
}

/// @nodoc
mixin _$DashboardTopMerchant {
  String get name => throw _privateConstructorUsedError;
  @_DecimalConverter()
  Decimal get amount => throw _privateConstructorUsedError;

  /// Serializes this DashboardTopMerchant to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DashboardTopMerchant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DashboardTopMerchantCopyWith<DashboardTopMerchant> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardTopMerchantCopyWith<$Res> {
  factory $DashboardTopMerchantCopyWith(
    DashboardTopMerchant value,
    $Res Function(DashboardTopMerchant) then,
  ) = _$DashboardTopMerchantCopyWithImpl<$Res, DashboardTopMerchant>;
  @useResult
  $Res call({String name, @_DecimalConverter() Decimal amount});
}

/// @nodoc
class _$DashboardTopMerchantCopyWithImpl<
  $Res,
  $Val extends DashboardTopMerchant
>
    implements $DashboardTopMerchantCopyWith<$Res> {
  _$DashboardTopMerchantCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DashboardTopMerchant
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
abstract class _$$DashboardTopMerchantImplCopyWith<$Res>
    implements $DashboardTopMerchantCopyWith<$Res> {
  factory _$$DashboardTopMerchantImplCopyWith(
    _$DashboardTopMerchantImpl value,
    $Res Function(_$DashboardTopMerchantImpl) then,
  ) = __$$DashboardTopMerchantImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, @_DecimalConverter() Decimal amount});
}

/// @nodoc
class __$$DashboardTopMerchantImplCopyWithImpl<$Res>
    extends _$DashboardTopMerchantCopyWithImpl<$Res, _$DashboardTopMerchantImpl>
    implements _$$DashboardTopMerchantImplCopyWith<$Res> {
  __$$DashboardTopMerchantImplCopyWithImpl(
    _$DashboardTopMerchantImpl _value,
    $Res Function(_$DashboardTopMerchantImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DashboardTopMerchant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null, Object? amount = null}) {
    return _then(
      _$DashboardTopMerchantImpl(
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
class _$DashboardTopMerchantImpl implements _DashboardTopMerchant {
  const _$DashboardTopMerchantImpl({
    this.name = '',
    @_DecimalConverter() required this.amount,
  });

  factory _$DashboardTopMerchantImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardTopMerchantImplFromJson(json);

  @override
  @JsonKey()
  final String name;
  @override
  @_DecimalConverter()
  final Decimal amount;

  @override
  String toString() {
    return 'DashboardTopMerchant(name: $name, amount: $amount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardTopMerchantImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.amount, amount) || other.amount == amount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, amount);

  /// Create a copy of DashboardTopMerchant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardTopMerchantImplCopyWith<_$DashboardTopMerchantImpl>
  get copyWith =>
      __$$DashboardTopMerchantImplCopyWithImpl<_$DashboardTopMerchantImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardTopMerchantImplToJson(this);
  }
}

abstract class _DashboardTopMerchant implements DashboardTopMerchant {
  const factory _DashboardTopMerchant({
    final String name,
    @_DecimalConverter() required final Decimal amount,
  }) = _$DashboardTopMerchantImpl;

  factory _DashboardTopMerchant.fromJson(Map<String, dynamic> json) =
      _$DashboardTopMerchantImpl.fromJson;

  @override
  String get name;
  @override
  @_DecimalConverter()
  Decimal get amount;

  /// Create a copy of DashboardTopMerchant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardTopMerchantImplCopyWith<_$DashboardTopMerchantImpl>
  get copyWith => throw _privateConstructorUsedError;
}
