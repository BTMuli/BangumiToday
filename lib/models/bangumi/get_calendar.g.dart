// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_calendar.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CalendarItem _$CalendarItemFromJson(Map<String, dynamic> json) => CalendarItem(
      weekday:
          CalendarItemWeekday.fromJson(json['weekday'] as Map<String, dynamic>),
      items: (json['items'] as List<dynamic>)
          .map((e) => CalendarItemBangumi.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CalendarItemToJson(CalendarItem instance) =>
    <String, dynamic>{
      'weekday': instance.weekday,
      'items': instance.items,
    };

CalendarItemWeekday _$CalendarItemWeekdayFromJson(Map<String, dynamic> json) =>
    CalendarItemWeekday(
      en: json['en'] as String,
      cn: json['cn'] as String,
      ja: json['ja'] as String,
      id: json['id'] as int,
    );

Map<String, dynamic> _$CalendarItemWeekdayToJson(
        CalendarItemWeekday instance) =>
    <String, dynamic>{
      'en': instance.en,
      'cn': instance.cn,
      'ja': instance.ja,
      'id': instance.id,
    };

CalendarItemBangumi _$CalendarItemBangumiFromJson(Map<String, dynamic> json) =>
    CalendarItemBangumi(
      id: json['id'] as int,
      url: json['url'] as String,
      type: json['type'] as int,
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      summary: json['summary'] as String,
      airDate: json['air_date'] as String,
      airWeekday: json['air_weekday'] as int,
      images: json['images'] == null
          ? null
          : BangumiImage.fromJson(json['images'] as Map<String, dynamic>),
      eps: json['eps'] as int?,
      epsCount: json['eps_count'] as int?,
      rating: json['rating'] == null
          ? null
          : BangumiRating.fromJson(json['rating'] as Map<String, dynamic>),
      rank: json['rank'] as int?,
      collection: json['collection'] == null
          ? null
          : BangumiCollection.fromJson(
              json['collection'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CalendarItemBangumiToJson(
        CalendarItemBangumi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'type': instance.type,
      'name': instance.name,
      'name_cn': instance.nameCn,
      'summary': instance.summary,
      'air_date': instance.airDate,
      'air_weekday': instance.airWeekday,
      'images': instance.images,
      'eps': instance.eps,
      'eps_count': instance.epsCount,
      'rating': instance.rating,
      'rank': instance.rank,
      'collection': instance.collection,
    };
