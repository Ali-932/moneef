import 'package:freezed_annotation/freezed_annotation.dart';

part 'pattern.freezed.dart';
part 'pattern.g.dart';

@freezed
class Pattern with _$Pattern {
  const factory Pattern({
    required int id,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    required String name,
    required String description,
    @Default(<String, dynamic>{}) Map<String, dynamic>? metadata,
    @Default('') String icon,
    @Default('') String color,
    @JsonKey(name: 'pattern_type') required String patternType,
    @JsonKey(name: 'final_score') required double finalScore,
    @JsonKey(name: 'profile_id') required int profileId,
  }) = _Pattern;

  factory Pattern.fromJson(Map<String, dynamic> json) =>
      _$PatternFromJson(json);
}
