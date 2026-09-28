import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';
part 'category.g.dart';

/// Mirrors `internal/models.Category` as serialized over the gomobile bridge.
///
/// Built-in categories have `profileId == null`; profile-owned (custom)
/// categories carry the active profile id.
@freezed
class Category with _$Category {
  const factory Category({
    required int id,
    @JsonKey(name: 'profile_id') int? profileId,
    required String name,
    required String type,
    @Default('') String icon,
    @Default('') String color,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}
