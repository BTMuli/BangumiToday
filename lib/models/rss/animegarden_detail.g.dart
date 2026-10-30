// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'animegarden_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnimeGardenDetailResponse _$AnimeGardenDetailResponseFromJson(
  Map<String, dynamic> json,
) => AnimeGardenDetailResponse(
  resource: AnimeGardenResource.fromJson(
    json['resource'] as Map<String, dynamic>,
  ),
  isDeleted: json['isDeleted'] as bool?,
  detail: json['detail'] == null
      ? null
      : AnimeGardenDetail.fromJson(json['detail'] as Map<String, dynamic>),
  duplicatedId: (json['duplicatedId'] as num?)?.toInt(),
);

Map<String, dynamic> _$AnimeGardenDetailResponseToJson(
  AnimeGardenDetailResponse instance,
) => <String, dynamic>{
  'resource': instance.resource.toJson(),
  'isDeleted': instance.isDeleted,
  'detail': instance.detail?.toJson(),
  'duplicatedId': instance.duplicatedId,
};

AnimeGardenDetail _$AnimeGardenDetailFromJson(Map<String, dynamic> json) =>
    AnimeGardenDetail(
      id: (json['id'] as num).toInt(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      description: json['description'] as String,
      files: (json['files'] as List<dynamic>)
          .map((e) => AnimeGardenFile.fromJson(e as Map<String, dynamic>))
          .toList(),
      magnets: (json['magnets'] as List<dynamic>)
          .map((e) => AnimeGardenMagnet.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMoreFiles: json['hasMoreFiles'] as bool,
    );

Map<String, dynamic> _$AnimeGardenDetailToJson(AnimeGardenDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fetchedAt': instance.fetchedAt.toIso8601String(),
      'description': instance.description,
      'files': instance.files.map((e) => e.toJson()).toList(),
      'magnets': instance.magnets.map((e) => e.toJson()).toList(),
      'hasMoreFiles': instance.hasMoreFiles,
    };

AnimeGardenFile _$AnimeGardenFileFromJson(Map<String, dynamic> json) =>
    AnimeGardenFile(name: json['name'] as String, size: json['size'] as String);

Map<String, dynamic> _$AnimeGardenFileToJson(AnimeGardenFile instance) =>
    <String, dynamic>{'name': instance.name, 'size': instance.size};

AnimeGardenMagnet _$AnimeGardenMagnetFromJson(Map<String, dynamic> json) =>
    AnimeGardenMagnet(name: json['name'] as String, url: json['url'] as String);

Map<String, dynamic> _$AnimeGardenMagnetToJson(AnimeGardenMagnet instance) =>
    <String, dynamic>{'name': instance.name, 'url': instance.url};
