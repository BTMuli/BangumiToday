// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_meta.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiData _$BangumiDataFromJson(Map<String, dynamic> json) => BangumiData(
      siteMeta: (json['siteMeta'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, BangumiDataSite.fromJson(e as Map<String, dynamic>)),
      ),
      items: (json['items'] as List<dynamic>)
          .map((e) => BangumiDataItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BangumiDataToJson(BangumiData instance) =>
    <String, dynamic>{
      'siteMeta': instance.siteMeta,
      'items': instance.items,
    };

BangumiDataSite _$BangumiDataSiteFromJson(Map<String, dynamic> json) =>
    BangumiDataSite(
      title: json['title'] as String,
      urlTemplate: json['urlTemplate'] as String,
      type: json['type'] as String,
      regions:
          (json['regions'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$BangumiDataSiteToJson(BangumiDataSite instance) =>
    <String, dynamic>{
      'title': instance.title,
      'urlTemplate': instance.urlTemplate,
      'type': instance.type,
      'regions': instance.regions,
    };

BangumiDataSiteFull _$BangumiDataSiteFullFromJson(Map<String, dynamic> json) =>
    BangumiDataSiteFull(
      key: json['key'] as String,
      title: json['title'] as String,
      urlTemplate: json['urlTemplate'] as String,
      type: json['type'] as String,
      regions:
          (json['regions'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$BangumiDataSiteFullToJson(
        BangumiDataSiteFull instance) =>
    <String, dynamic>{
      'key': instance.key,
      'title': instance.title,
      'urlTemplate': instance.urlTemplate,
      'type': instance.type,
      'regions': instance.regions,
    };
