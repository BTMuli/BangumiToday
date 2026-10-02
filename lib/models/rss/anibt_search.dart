// Package imports:
import 'package:json_annotation/json_annotation.dart';

part 'anibt_search.g.dart';

@JsonSerializable()
class AnibtSearchItem {
  final int bgmId;
  final String name;
  final String? nameCn;
  final String? date;

  const AnibtSearchItem({
    required this.bgmId,
    required this.name,
    this.nameCn,
    this.date,
  });

  String get title => nameCn?.trim().isNotEmpty == true ? nameCn! : name;

  factory AnibtSearchItem.fromJson(Map<String, dynamic> json) =>
      _$AnibtSearchItemFromJson(json);

  Map<String, dynamic> toJson() => _$AnibtSearchItemToJson(this);
}

@JsonSerializable(explicitToJson: true)
class AnibtAnimeGroup {
  final String slug;
  final String name;
  final int? totalReleases;
  final int? lastUpdatedAt;
  final List<AnibtGroupRelease> items;

  const AnibtAnimeGroup({
    required this.slug,
    required this.name,
    required this.items,
    this.totalReleases,
    this.lastUpdatedAt,
  });

  factory AnibtAnimeGroup.fromJson(Map<String, dynamic> json) =>
      _$AnibtAnimeGroupFromJson(json);

  Map<String, dynamic> toJson() => _$AnibtAnimeGroupToJson(this);
}

@JsonSerializable()
class AnibtGroupRelease {
  final String releaseId;
  final String title;
  final int? size;
  final String? resolution;
  final String? subtitle;
  @JsonKey(name: 'language')
  final List<String> languages;
  final int publishedAt;

  const AnibtGroupRelease({
    required this.releaseId,
    required this.title,
    required this.languages,
    required this.publishedAt,
    this.size,
    this.resolution,
    this.subtitle,
  });

  factory AnibtGroupRelease.fromJson(Map<String, dynamic> json) =>
      _$AnibtGroupReleaseFromJson(json);

  Map<String, dynamic> toJson() => _$AnibtGroupReleaseToJson(this);
}
