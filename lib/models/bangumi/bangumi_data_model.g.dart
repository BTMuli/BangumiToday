// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_data_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiDataJson _$BangumiDataJsonFromJson(Map<String, dynamic> json) =>
    BangumiDataJson(
      siteMeta: (json['siteMeta'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, BangumiDataSite.fromJson(e as Map<String, dynamic>)),
      ),
      items: (json['items'] as List<dynamic>)
          .map((e) => BangumiDataItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BangumiDataJsonToJson(BangumiDataJson instance) =>
    <String, dynamic>{
      'siteMeta': instance.siteMeta.map((k, e) => MapEntry(k, e.toJson())),
      'items': instance.items.map((e) => e.toJson()).toList(),
    };

BangumiDataSite _$BangumiDataSiteFromJson(Map<String, dynamic> json) =>
    BangumiDataSite(
      title: json['title'] as String,
      urlTemplate: json['urlTemplate'] as String,
      type: json['type'] as String,
      regions: (json['regions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$BangumiDataSiteToJson(BangumiDataSite instance) =>
    <String, dynamic>{
      'title': instance.title,
      'urlTemplate': instance.urlTemplate,
      'type': instance.type,
      'regions': instance.regions,
    };

BangumiDataItem _$BangumiDataItemFromJson(Map<String, dynamic> json) =>
    BangumiDataItem(
      title: json['title'] as String,
      titleTranslate: BangumiDataItemTitleTranslate.fromJson(
        json['titleTranslate'] as Map<String, dynamic>,
      ),
      type: json['type'] as String,
      lang: json['lang'] as String,
      officialSite: json['officialSite'] as String,
      begin: json['begin'] as String,
      broadcast: json['broadcast'] as String?,
      end: json['end'] as String,
      comment: json['comment'] as String?,
      sites: (json['sites'] as List<dynamic>)
          .map((e) => BangumiDataItemSite.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BangumiDataItemToJson(BangumiDataItem instance) =>
    <String, dynamic>{
      'title': instance.title,
      'titleTranslate': instance.titleTranslate.toJson(),
      'type': instance.type,
      'lang': instance.lang,
      'officialSite': instance.officialSite,
      'begin': instance.begin,
      'broadcast': instance.broadcast,
      'end': instance.end,
      'comment': instance.comment,
      'sites': instance.sites.map((e) => e.toJson()).toList(),
    };

BangumiDataItemTitleTranslate _$BangumiDataItemTitleTranslateFromJson(
  Map<String, dynamic> json,
) => BangumiDataItemTitleTranslate(
  zh: (json['zh-Hans'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$BangumiDataItemTitleTranslateToJson(
  BangumiDataItemTitleTranslate instance,
) => <String, dynamic>{'zh-Hans': instance.zh};

BangumiDataItemSite _$BangumiDataItemSiteFromJson(Map<String, dynamic> json) =>
    BangumiDataItemSite(
      site: json['site'] as String,
      id: json['id'] as String?,
      begin: json['begin'] as String?,
      broadcast: json['broadcast'] as String?,
    );

Map<String, dynamic> _$BangumiDataItemSiteToJson(
  BangumiDataItemSite instance,
) => <String, dynamic>{
  'site': instance.site,
  'id': instance.id,
  'begin': instance.begin,
  'broadcast': instance.broadcast,
};

BangumiDataSiteFull _$BangumiDataSiteFullFromJson(Map<String, dynamic> json) =>
    BangumiDataSiteFull(
      key: json['key'] as String,
      title: json['title'] as String,
      urlTemplate: json['urlTemplate'] as String,
      type: json['type'] as String,
      regions: (json['regions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$BangumiDataSiteFullToJson(
  BangumiDataSiteFull instance,
) => <String, dynamic>{
  'title': instance.title,
  'urlTemplate': instance.urlTemplate,
  'type': instance.type,
  'regions': instance.regions,
  'key': instance.key,
};

BangumiDataResp _$BangumiDataRespFromJson(Map<String, dynamic> json) =>
    BangumiDataResp(
      code: (json['code'] as num).toInt(),
      message: json['message'] as String,
      data: BangumiDataJson.fromJson(json['data'] as Map<String, dynamic>),
    );
