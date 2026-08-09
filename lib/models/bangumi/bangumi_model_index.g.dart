// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_model_index.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiIndex _$BangumiIndexFromJson(Map<String, dynamic> json) => BangumiIndex(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  desc: json['desc'] as String,
  total: (json['total'] as num).toInt(),
  stat: BangumiStat.fromJson(json['stat'] as Map<String, dynamic>),
  createdAt: json['created_at'] as String,
  updatedAt: json['updated_at'] as String,
  creator: BangumiCreator.fromJson(json['creator'] as Map<String, dynamic>),
  nsfw: json['nsfw'] as bool,
);

Map<String, dynamic> _$BangumiIndexToJson(BangumiIndex instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'desc': instance.desc,
      'total': instance.total,
      'stat': instance.stat.toJson(),
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'creator': instance.creator.toJson(),
      'nsfw': instance.nsfw,
    };

BangumiIndexSubject _$BangumiIndexSubjectFromJson(Map<String, dynamic> json) =>
    BangumiIndexSubject(
      id: (json['id'] as num).toInt(),
      type: $enumDecode(_$BangumiSubjectTypeEnumMap, json['type']),
      name: json['name'] as String,
      images: BangumiImages.fromJson(json['images'] as Map<String, dynamic>),
      infobox: (json['infobox'] as List<dynamic>)
          .map((e) => BangumiInfoBoxItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      date: json['date'] as String,
      comment: json['comment'] as String,
      addedAt: json['added_at'] as String,
    );

Map<String, dynamic> _$BangumiIndexSubjectToJson(
  BangumiIndexSubject instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': _$BangumiSubjectTypeEnumMap[instance.type]!,
  'name': instance.name,
  'images': instance.images.toJson(),
  'infobox': instance.infobox.map((e) => e.toJson()).toList(),
  'date': instance.date,
  'comment': instance.comment,
  'added_at': instance.addedAt,
};

const _$BangumiSubjectTypeEnumMap = {
  BangumiSubjectType.book: 1,
  BangumiSubjectType.anime: 2,
  BangumiSubjectType.music: 3,
  BangumiSubjectType.game: 4,
  BangumiSubjectType.real: 6,
};

BangumiIndexBasicInfo1 _$BangumiIndexBasicInfo1FromJson(
  Map<String, dynamic> json,
) => BangumiIndexBasicInfo1(
  title: json['title'] as String,
  description: json['description'] as String,
);

Map<String, dynamic> _$BangumiIndexBasicInfo1ToJson(
  BangumiIndexBasicInfo1 instance,
) => <String, dynamic>{
  'title': instance.title,
  'description': instance.description,
};

BangumiIndexBasicInfo2 _$BangumiIndexBasicInfo2FromJson(
  Map<String, dynamic> json,
) => BangumiIndexBasicInfo2(
  subjectId: (json['subject_id'] as num).toInt(),
  sort: (json['sort'] as num).toInt(),
  comment: json['comment'] as String,
);

Map<String, dynamic> _$BangumiIndexBasicInfo2ToJson(
  BangumiIndexBasicInfo2 instance,
) => <String, dynamic>{
  'subject_id': instance.subjectId,
  'sort': instance.sort,
  'comment': instance.comment,
};

BangumiIndexBasicInfo3 _$BangumiIndexBasicInfo3FromJson(
  Map<String, dynamic> json,
) => BangumiIndexBasicInfo3(
  sort: (json['sort'] as num).toInt(),
  comment: json['comment'] as String,
);

Map<String, dynamic> _$BangumiIndexBasicInfo3ToJson(
  BangumiIndexBasicInfo3 instance,
) => <String, dynamic>{'sort': instance.sort, 'comment': instance.comment};

BangumiInfoBoxItem _$BangumiInfoBoxItemFromJson(Map<String, dynamic> json) =>
    BangumiInfoBoxItem(key: json['key'] as String, value: json['value']);

Map<String, dynamic> _$BangumiInfoBoxItemToJson(BangumiInfoBoxItem instance) =>
    <String, dynamic>{'key': instance.key, 'value': instance.value};

BangumiPage _$BangumiPageFromJson(Map<String, dynamic> json) => BangumiPage(
  total: (json['total'] as num).toInt(),
  limit: (json['limit'] as num).toInt(),
  offset: (json['offset'] as num).toInt(),
);

Map<String, dynamic> _$BangumiPageToJson(BangumiPage instance) =>
    <String, dynamic>{
      'total': instance.total,
      'limit': instance.limit,
      'offset': instance.offset,
    };

BangumiPageT<T> _$BangumiPageTFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) => BangumiPageT<T>(
  total: (json['total'] as num).toInt(),
  limit: (json['limit'] as num).toInt(),
  offset: (json['offset'] as num).toInt(),
  data: (json['data'] as List<dynamic>).map(fromJsonT).toList(),
);

Map<String, dynamic> _$BangumiPageTToJson<T>(
  BangumiPageT<T> instance,
  Object? Function(T value) toJsonT,
) => <String, dynamic>{
  'total': instance.total,
  'limit': instance.limit,
  'offset': instance.offset,
  'data': instance.data.map(toJsonT).toList(),
};
