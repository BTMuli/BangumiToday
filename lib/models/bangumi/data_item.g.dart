// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiDataItem _$BangumiDataItemFromJson(Map<String, dynamic> json) =>
    BangumiDataItem(
      title: json['title'] as String,
      titleTranslate: BangumiDataItemTitleTranslate.fromJson(
          json['titleTranslate'] as Map<String, dynamic>),
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
      'titleTranslate': instance.titleTranslate,
      'type': instance.type,
      'lang': instance.lang,
      'officialSite': instance.officialSite,
      'begin': instance.begin,
      'broadcast': instance.broadcast,
      'end': instance.end,
      'comment': instance.comment,
      'sites': instance.sites,
    };

BangumiDataItemTitleTranslate _$BangumiDataItemTitleTranslateFromJson(
        Map<String, dynamic> json) =>
    BangumiDataItemTitleTranslate(
      zh: (json['zh-Hans'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$BangumiDataItemTitleTranslateToJson(
        BangumiDataItemTitleTranslate instance) =>
    <String, dynamic>{
      'zh-Hans': instance.zh,
    };

BangumiDataItemSite _$BangumiDataItemSiteFromJson(Map<String, dynamic> json) =>
    BangumiDataItemSite(
      site: json['site'] as String,
      id: json['id'] as String?,
      begin: json['begin'] as String?,
      broadcast: json['broadcast'] as String?,
    );

Map<String, dynamic> _$BangumiDataItemSiteToJson(
        BangumiDataItemSite instance) =>
    <String, dynamic>{
      'site': instance.site,
      'id': instance.id,
      'begin': instance.begin,
      'broadcast': instance.broadcast,
    };
