import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

/// Decimal converter — Go's `pkg/types.Money` marshals as a string.
/// See `mobilebridge/API.md` § Money serialization.
class _DecimalConverter implements JsonConverter<Decimal, String> {
  const _DecimalConverter();

  @override
  Decimal fromJson(String json) => Decimal.parse(json);

  @override
  String toJson(Decimal object) => object.toString();
}

@freezed
class TransactionCategory with _$TransactionCategory {
  const factory TransactionCategory({
    required int id,
    @JsonKey(name: 'category_id') required int categoryId,
    @_DecimalConverter() required Decimal amount,
    @JsonKey(name: 'Category') Map<String, dynamic>? category,
  }) = _TransactionCategory;

  factory TransactionCategory.fromJson(Map<String, dynamic> json) =>
      _$TransactionCategoryFromJson(json);
}

@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required int id,
    required String name,
    required String type,
    required DateTime date,
    @JsonKey(name: 'currency_code') required String currencyCode,
    @Default('') String icon,
    @Default('') String color,
    @JsonKey(name: 'merchant_name') @Default('') String merchantName,
    @Default('') String notes,
    @JsonKey(name: 'TransactionCategory')
    @Default(<TransactionCategory>[])
    List<TransactionCategory> categories,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
}

/// Helper exposed for screens that want to format an amount safely.
extension TransactionTotal on Transaction {
  Decimal get totalAmount =>
      categories.fold(Decimal.zero, (sum, c) => sum + c.amount);
}
