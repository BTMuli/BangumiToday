// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_subject.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiCalendarResp _$BangumiCalendarRespFromJson(Map<String, dynamic> json) =>
    BangumiCalendarResp(
      code: (json['code'] as num).toInt(),
      message: json['message'] as String,
      data: (json['data'] as List<dynamic>)
          .map((e) =>
              BangumiCalendarRespData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

BangumiSubjectSearchResp _$BangumiSubjectSearchRespFromJson(
        Map<String, dynamic> json) =>
    BangumiSubjectSearchResp(
      code: (json['code'] as num).toInt(),
      message: json['message'] as String,
      data: BangumiPageT<BangumiSubjectSearchData>.fromJson(
          json['data'] as Map<String, dynamic>,
          (value) =>
              BangumiSubjectSearchData.fromJson(value as Map<String, dynamic>)),
    );

BangumiSubjectResp _$BangumiSubjectRespFromJson(Map<String, dynamic> json) =>
    BangumiSubjectResp(
      code: (json['code'] as num).toInt(),
      message: json['message'] as String,
      data: BangumiSubject.fromJson(json['data'] as Map<String, dynamic>),
    );

BangumiSubjectRelationsResp _$BangumiSubjectRelationsRespFromJson(
        Map<String, dynamic> json) =>
    BangumiSubjectRelationsResp(
      code: (json['code'] as num).toInt(),
      message: json['message'] as String,
      data: (json['data'] as List<dynamic>)
          .map(
              (e) => BangumiSubjectRelation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

BangumiCalendarRespData _$BangumiCalendarRespDataFromJson(
        Map<String, dynamic> json) =>
    BangumiCalendarRespData(
      weekday: BangumiCalendarRespWeek.fromJson(
          json['weekday'] as Map<String, dynamic>),
      items: (json['items'] as List<dynamic>)
          .map((e) =>
              BangumiLegacySubjectSmall.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BangumiCalendarRespDataToJson(
        BangumiCalendarRespData instance) =>
    <String, dynamic>{
      'weekday': instance.weekday.toJson(),
      'items': instance.items.map((e) => e.toJson()).toList(),
    };

BangumiCalendarRespWeek _$BangumiCalendarRespWeekFromJson(
        Map<String, dynamic> json) =>
    BangumiCalendarRespWeek(
      en: json['en'] as String,
      cn: json['cn'] as String,
      ja: json['ja'] as String,
      id: (json['id'] as num).toInt(),
    );

Map<String, dynamic> _$BangumiCalendarRespWeekToJson(
        BangumiCalendarRespWeek instance) =>
    <String, dynamic>{
      'en': instance.en,
      'cn': instance.cn,
      'ja': instance.ja,
      'id': instance.id,
    };

BangumiSubjectSearchData _$BangumiSubjectSearchDataFromJson(
        Map<String, dynamic> json) =>
    BangumiSubjectSearchData(
      id: (json['id'] as num).toInt(),
      type: $enumDecodeNullable(_$BangumiSubjectTypeEnumMap, json['type']),
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      summary: json['summary'] as String,
      series: json['series'] as bool,
      nsfw: json['nsfw'] as bool,
      locked: json['locked'] as bool,
      date: json['date'] as String?,
      platform: json['platform'] as String,
      images: BangumiImages.fromJson(json['images'] as Map<String, dynamic>),
      infobox: json['infobox'],
      volumes: (json['volumes'] as num).toInt(),
      eps: (json['eps'] as num).toInt(),
      totalEpisodes: (json['total_episodes'] as num?)?.toInt(),
      rating:
          BangumiPatchRating.fromJson(json['rating'] as Map<String, dynamic>),
      collection: BangumiPatchCollection.fromJson(
          json['collection'] as Map<String, dynamic>),
      metaTags:
          (json['meta_tags'] as List<dynamic>).map((e) => e as String).toList(),
      tags: (json['tags'] as List<dynamic>)
          .map((e) => BangumiTag.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BangumiSubjectSearchDataToJson(
        BangumiSubjectSearchData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$BangumiSubjectTypeEnumMap[instance.type],
      'name': instance.name,
      'name_cn': instance.nameCn,
      'summary': instance.summary,
      'series': instance.series,
      'nsfw': instance.nsfw,
      'locked': instance.locked,
      'date': instance.date,
      'platform': instance.platform,
      'images': instance.images.toJson(),
      'infobox': instance.infobox,
      'volumes': instance.volumes,
      'eps': instance.eps,
      'total_episodes': instance.totalEpisodes,
      'rating': instance.rating.toJson(),
      'collection': instance.collection.toJson(),
      'meta_tags': instance.metaTags,
      'tags': instance.tags.map((e) => e.toJson()).toList(),
    };

const _$BangumiSubjectTypeEnumMap = {
  BangumiSubjectType.book: 1,
  BangumiSubjectType.anime: 2,
  BangumiSubjectType.music: 3,
  BangumiSubjectType.game: 4,
  BangumiSubjectType.real: 6,
};
