// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'animegarden_resource.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnimeGardenResource _$AnimeGardenResourceFromJson(Map<String, dynamic> json) =>
    AnimeGardenResource(
      id: (json['id'] as num).toInt(),
      provider: json['provider'] as String,
      providerId: json['providerId'] as String,
      title: json['title'] as String,
      href: json['href'] as String,
      type: json['type'] as String,
      magnet: json['magnet'] as String,
      size: (json['size'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      publisher: AnimeGardenParty.fromJson(
        json['publisher'] as Map<String, dynamic>,
      ),
      tracker: json['tracker'] as String?,
      fansub: json['fansub'] == null
          ? null
          : AnimeGardenParty.fromJson(json['fansub'] as Map<String, dynamic>),
      subjectId: (json['subjectId'] as num?)?.toInt(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$AnimeGardenResourceToJson(
  AnimeGardenResource instance,
) => <String, dynamic>{
  'id': instance.id,
  'provider': instance.provider,
  'providerId': instance.providerId,
  'title': instance.title,
  'href': instance.href,
  'type': instance.type,
  'magnet': instance.magnet,
  'size': instance.size,
  'createdAt': instance.createdAt.toIso8601String(),
  'fetchedAt': instance.fetchedAt.toIso8601String(),
  'publisher': instance.publisher.toJson(),
  'tracker': instance.tracker,
  'fansub': instance.fansub?.toJson(),
  'subjectId': instance.subjectId,
  'metadata': instance.metadata,
};

AnimeGardenParty _$AnimeGardenPartyFromJson(Map<String, dynamic> json) =>
    AnimeGardenParty(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
    );

Map<String, dynamic> _$AnimeGardenPartyToJson(AnimeGardenParty instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'avatar': instance.avatar,
    };

AnimeGardenPagination _$AnimeGardenPaginationFromJson(
  Map<String, dynamic> json,
) => AnimeGardenPagination(
  page: (json['page'] as num).toInt(),
  pageSize: (json['pageSize'] as num).toInt(),
  complete: json['complete'] as bool,
);

Map<String, dynamic> _$AnimeGardenPaginationToJson(
  AnimeGardenPagination instance,
) => <String, dynamic>{
  'page': instance.page,
  'pageSize': instance.pageSize,
  'complete': instance.complete,
};

AnimeGardenPage _$AnimeGardenPageFromJson(Map<String, dynamic> json) =>
    AnimeGardenPage(
      resources: (json['resources'] as List<dynamic>)
          .map((e) => AnimeGardenResource.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: AnimeGardenPagination.fromJson(
        json['pagination'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$AnimeGardenPageToJson(AnimeGardenPage instance) =>
    <String, dynamic>{
      'resources': instance.resources.map((e) => e.toJson()).toList(),
      'pagination': instance.pagination.toJson(),
    };
