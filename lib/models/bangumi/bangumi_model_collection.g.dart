// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_model_collection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiUserSubjectCollection _$BangumiUserSubjectCollectionFromJson(
  Map<String, dynamic> json,
) => BangumiUserSubjectCollection(
  subjectId: (json['subject_id'] as num).toInt(),
  subjectType: $enumDecode(_$BangumiSubjectTypeEnumMap, json['subject_type']),
  rate: (json['rate'] as num).toInt(),
  type: $enumDecode(_$BangumiCollectionTypeEnumMap, json['type']),
  comment: json['comment'] as String?,
  tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
  epStatus: (json['ep_status'] as num).toInt(),
  volStatus: (json['vol_status'] as num).toInt(),
  updatedAt: json['updated_at'] as String,
  private: json['private'] as bool,
  subject: BangumiSlimSubject.fromJson(json['subject'] as Map<String, dynamic>),
);

Map<String, dynamic> _$BangumiUserSubjectCollectionToJson(
  BangumiUserSubjectCollection instance,
) => <String, dynamic>{
  'subject_id': instance.subjectId,
  'subject_type': _$BangumiSubjectTypeEnumMap[instance.subjectType]!,
  'rate': instance.rate,
  'type': _$BangumiCollectionTypeEnumMap[instance.type]!,
  'comment': instance.comment,
  'tags': instance.tags,
  'ep_status': instance.epStatus,
  'vol_status': instance.volStatus,
  'updated_at': instance.updatedAt,
  'private': instance.private,
  'subject': instance.subject.toJson(),
};

const _$BangumiCollectionTypeEnumMap = {
  BangumiCollectionType.unknown: 0,
  BangumiCollectionType.wish: 1,
  BangumiCollectionType.collect: 2,
  BangumiCollectionType.doing: 3,
  BangumiCollectionType.onHold: 4,
  BangumiCollectionType.dropped: 5,
};

BangumiUserSubjectCollectionModifyPayload
_$BangumiUserSubjectCollectionModifyPayloadFromJson(
  Map<String, dynamic> json,
) => BangumiUserSubjectCollectionModifyPayload(
  type: $enumDecode(_$BangumiCollectionTypeEnumMap, json['type']),
  rate: (json['rate'] as num).toInt(),
  epStatus: (json['ep_status'] as num).toInt(),
  volStatus: (json['vol_status'] as num).toInt(),
  comment: json['comment'] as String,
  private: json['private'] as bool,
  tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$BangumiUserSubjectCollectionModifyPayloadToJson(
  BangumiUserSubjectCollectionModifyPayload instance,
) => <String, dynamic>{
  'type': _$BangumiCollectionTypeEnumMap[instance.type]!,
  'rate': instance.rate,
  'ep_status': instance.epStatus,
  'vol_status': instance.volStatus,
  'comment': instance.comment,
  'private': instance.private,
  'tags': instance.tags,
};

BangumiUserEpisodeCollection _$BangumiUserEpisodeCollectionFromJson(
  Map<String, dynamic> json,
) => BangumiUserEpisodeCollection(
  episode: BangumiEpisode.fromJson(json['episode'] as Map<String, dynamic>),
  type: $enumDecode(_$BangumiEpisodeCollectionTypeEnumMap, json['type']),
);

Map<String, dynamic> _$BangumiUserEpisodeCollectionToJson(
  BangumiUserEpisodeCollection instance,
) => <String, dynamic>{
  'episode': instance.episode.toJson(),
  'type': _$BangumiEpisodeCollectionTypeEnumMap[instance.type]!,
};

const _$BangumiEpisodeCollectionTypeEnumMap = {
  BangumiEpisodeCollectionType.none: 0,
  BangumiEpisodeCollectionType.wish: 1,
  BangumiEpisodeCollectionType.done: 2,
  BangumiEpisodeCollectionType.dropped: 3,
};

const _$BangumiSubjectTypeEnumMap = {
  BangumiSubjectType.book: 1,
  BangumiSubjectType.anime: 2,
  BangumiSubjectType.music: 3,
  BangumiSubjectType.game: 4,
  BangumiSubjectType.real: 6,
};
