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

BangumiSubjectResp _$BangumiSubjectRespFromJson(Map<String, dynamic> json) =>
    BangumiSubjectResp(
      code: json['code'] as int,
      message: json['message'] as String,
      data: BangumiSubject.fromJson(json['data'] as Map<String, dynamic>),
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
