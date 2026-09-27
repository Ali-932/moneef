import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recurrence_occurrence.freezed.dart';
part 'recurrence_occurrence.g.dart';

class _DecimalConverter implements JsonConverter<Decimal, String> {
  const _DecimalConverter();

  @override
  Decimal fromJson(String json) => Decimal.parse(json);

  @override
  String toJson(Decimal object) => object.toString();
}

@freezed
class RecurrenceOccurrence with _$RecurrenceOccurrence {
  const factory RecurrenceOccurrence({
    required int id,
    required String name,
    required String type,
    @_DecimalConverter() required Decimal amount,
    @JsonKey(name: 'currency') @Default('') String currencyCode,
    @Default('') String icon,
    @Default('') String color,
    required DateTime date,
  }) = _RecurrenceOccurrence;

  factory RecurrenceOccurrence.fromJson(Map<String, dynamic> json) =>
      _$RecurrenceOccurrenceFromJson(json);
}
