// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_subject.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiCalendarResp _$BangumiCalendarRespFromJson(Map<String, dynamic> json) =>
    BangumiCalendarResp(
      code: json['code'] as int,
      message: json['message'] as String,
      data: (json['data'] as List<dynamic>)
          .map((e) =>
              BangumiCalendarRespData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

BangumiSubjectSearchResp _$BangumiSubjectSearchRespFromJson(
        Map<String, dynamic> json) =>
    BangumiSubjectSearchResp(
      code: json['code'] as int,
      message: json['message'] as String,
      data: BangumiPageT<BangumiSubjectSearchData>.fromJson(
          json['data'] as Map<String, dynamic>,
          (value) =>
              BangumiSubjectSearchData.fromJson(value as Map<String, dynamic>)),
    );

BangumiSubjectResp _$BangumiSubjectRespFromJson(Map<String, dynamic> json) =>
    BangumiSubjectResp(
      code: json['code'] as int,
      message: json['message'] as String,
      data: BangumiSubject.fromJson(json['data'] as Map<String, dynamic>),
    );

BangumiSubjectRelationsResp _$BangumiSubjectRelationsRespFromJson(
        Map<String, dynamic> json) =>
    BangumiSubjectRelationsResp(
      code: json['code'] as int,
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
      id: json['id'] as int,
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
      id: json['id'] as int,
      type: $enumDecodeNullable(_$BangumiSubjectTypeEnumMap, json['type']),
      date: json['date'] as String,
      image: json['image'] as String,
      summary: json['summary'] as String,
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      tags: (json['tags'] as List<dynamic>)
          .map((e) => BangumiTag.fromJson(e as Map<String, dynamic>))
          .toList(),
      score: (json['score'] as num).toDouble(),
      rank: json['rank'] as int,
    );

Map<String, dynamic> _$BangumiSubjectSearchDataToJson(
        BangumiSubjectSearchData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$BangumiSubjectTypeEnumMap[instance.type],
      'date': instance.date,
      'image': instance.image,
      'summary': instance.summary,
      'name': instance.name,
      'name_cn': instance.nameCn,
      'tags': instance.tags.map((e) => e.toJson()).toList(),
      'score': instance.score,
      'rank': instance.rank,
    };

const _$BangumiSubjectTypeEnumMap = {
  BangumiSubjectType.book: 1,
  BangumiSubjectType.anime: 2,
  BangumiSubjectType.music: 3,
  BangumiSubjectType.game: 4,
  BangumiSubjectType.real: 6,
};
