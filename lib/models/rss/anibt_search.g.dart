// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anibt_search.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnibtSearchItem _$AnibtSearchItemFromJson(Map<String, dynamic> json) =>
    AnibtSearchItem(
      bgmId: (json['bgmId'] as num).toInt(),
      name: json['name'] as String,
      nameCn: json['nameCn'] as String?,
      date: json['date'] as String?,
    );

Map<String, dynamic> _$AnibtSearchItemToJson(AnibtSearchItem instance) =>
    <String, dynamic>{
      'bgmId': instance.bgmId,
      'name': instance.name,
      'nameCn': instance.nameCn,
      'date': instance.date,
    };

AnibtAnimeGroup _$AnibtAnimeGroupFromJson(Map<String, dynamic> json) =>
    AnibtAnimeGroup(
      slug: json['slug'] as String,
      name: json['name'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => AnibtGroupRelease.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalReleases: (json['totalReleases'] as num?)?.toInt(),
      lastUpdatedAt: (json['lastUpdatedAt'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AnibtAnimeGroupToJson(AnibtAnimeGroup instance) =>
    <String, dynamic>{
      'slug': instance.slug,
      'name': instance.name,
      'totalReleases': instance.totalReleases,
      'lastUpdatedAt': instance.lastUpdatedAt,
      'items': instance.items.map((e) => e.toJson()).toList(),
    };

AnibtGroupRelease _$AnibtGroupReleaseFromJson(Map<String, dynamic> json) =>
    AnibtGroupRelease(
      releaseId: json['releaseId'] as String,
      title: json['title'] as String,
      languages: (json['language'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      publishedAt: (json['publishedAt'] as num).toInt(),
      size: (json['size'] as num?)?.toInt(),
      resolution: json['resolution'] as String?,
      subtitle: json['subtitle'] as String?,
    );

Map<String, dynamic> _$AnibtGroupReleaseToJson(AnibtGroupRelease instance) =>
    <String, dynamic>{
      'releaseId': instance.releaseId,
      'title': instance.title,
      'size': instance.size,
      'resolution': instance.resolution,
      'subtitle': instance.subtitle,
      'language': instance.languages,
      'publishedAt': instance.publishedAt,
    };
