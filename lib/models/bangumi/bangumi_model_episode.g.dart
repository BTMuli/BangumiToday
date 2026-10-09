// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_model_episode.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiEpisode _$BangumiEpisodeFromJson(Map<String, dynamic> json) =>
    BangumiEpisode(
      id: (json['id'] as num).toInt(),
      type: $enumDecode(_$BangumiEpTypeEnumMap, json['type']),
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      sort: (json['sort'] as num).toDouble(),
      ep: (json['ep'] as num).toDouble(),
      airDate: json['airdate'] as String,
      comment: (json['comment'] as num).toInt(),
      duration: json['duration'] as String,
      desc: json['desc'] as String,
      disc: (json['disc'] as num).toInt(),
      durationSeconds: (json['duration_seconds'] as num).toInt(),
    );

Map<String, dynamic> _$BangumiEpisodeToJson(BangumiEpisode instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$BangumiEpTypeEnumMap[instance.type]!,
      'name': instance.name,
      'name_cn': instance.nameCn,
      'sort': instance.sort,
      'ep': instance.ep,
      'airdate': instance.airDate,
      'comment': instance.comment,
      'duration': instance.duration,
      'desc': instance.desc,
      'disc': instance.disc,
      'duration_seconds': instance.durationSeconds,
    };

const _$BangumiEpTypeEnumMap = {
  BangumiEpType.main: 0,
  BangumiEpType.sp: 1,
  BangumiEpType.op: 2,
  BangumiEpType.ed: 3,
  BangumiEpType.cm: 4,
  BangumiEpType.mad: 5,
  BangumiEpType.other: 6,
};

BangumiEpisodeDetail _$BangumiEpisodeDetailFromJson(
  Map<String, dynamic> json,
) => BangumiEpisodeDetail(
  id: (json['id'] as num).toInt(),
  subjectId: (json['subjectID'] as num).toInt(),
  type: $enumDecode(_$BangumiEpTypeEnumMap, json['type']),
  name: json['name'] as String,
  nameCn: json['nameCN'] as String,
  sort: (json['sort'] as num).toDouble(),
  airDate: json['airdate'] as String,
  duration: json['duration'] as String,
  desc: json['desc'] as String,
  comment: (json['comment'] as num).toInt(),
  disc: (json['disc'] as num).toInt(),
  subject: json['subject'] == null
      ? null
      : BangumiEpisodeSubject.fromJson(json['subject'] as Map<String, dynamic>),
  collection: json['collection'] == null
      ? null
      : BangumiEpisodeCollection.fromJson(
          json['collection'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$BangumiEpisodeDetailToJson(
  BangumiEpisodeDetail instance,
) => <String, dynamic>{
  'id': instance.id,
  'subjectID': instance.subjectId,
  'type': _$BangumiEpTypeEnumMap[instance.type]!,
  'name': instance.name,
  'nameCN': instance.nameCn,
  'sort': instance.sort,
  'airdate': instance.airDate,
  'duration': instance.duration,
  'desc': instance.desc,
  'comment': instance.comment,
  'disc': instance.disc,
  'subject': instance.subject?.toJson(),
  'collection': instance.collection?.toJson(),
};

BangumiEpisodeSubject _$BangumiEpisodeSubjectFromJson(
  Map<String, dynamic> json,
) => BangumiEpisodeSubject(
  id: (json['id'] as num).toInt(),
  type: $enumDecode(_$BangumiSubjectTypeEnumMap, json['type']),
  name: json['name'] as String,
  nameCn: json['nameCN'] as String,
  info: json['info'] as String,
  metaTags: (json['metaTags'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  images: json['images'] == null
      ? null
      : BangumiImages.fromJson(json['images'] as Map<String, dynamic>),
  rating: json['rating'] == null
      ? null
      : BangumiEpisodeSubjectRating.fromJson(
          json['rating'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$BangumiEpisodeSubjectToJson(
  BangumiEpisodeSubject instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': _$BangumiSubjectTypeEnumMap[instance.type]!,
  'name': instance.name,
  'nameCN': instance.nameCn,
  'info': instance.info,
  'metaTags': instance.metaTags,
  'images': instance.images?.toJson(),
  'rating': instance.rating?.toJson(),
};

const _$BangumiSubjectTypeEnumMap = {
  BangumiSubjectType.book: 1,
  BangumiSubjectType.anime: 2,
  BangumiSubjectType.music: 3,
  BangumiSubjectType.game: 4,
  BangumiSubjectType.real: 6,
};

BangumiEpisodeSubjectRating _$BangumiEpisodeSubjectRatingFromJson(
  Map<String, dynamic> json,
) => BangumiEpisodeSubjectRating(
  score: (json['score'] as num).toDouble(),
  total: (json['total'] as num).toInt(),
  rank: (json['rank'] as num?)?.toInt(),
);

Map<String, dynamic> _$BangumiEpisodeSubjectRatingToJson(
  BangumiEpisodeSubjectRating instance,
) => <String, dynamic>{
  'score': instance.score,
  'total': instance.total,
  'rank': instance.rank,
};

BangumiEpisodeCollection _$BangumiEpisodeCollectionFromJson(
  Map<String, dynamic> json,
) => BangumiEpisodeCollection(
  status: $enumDecode(_$BangumiEpisodeCollectionTypeEnumMap, json['status']),
  updatedAt: (json['updatedAt'] as num?)?.toInt(),
);

Map<String, dynamic> _$BangumiEpisodeCollectionToJson(
  BangumiEpisodeCollection instance,
) => <String, dynamic>{
  'status': _$BangumiEpisodeCollectionTypeEnumMap[instance.status]!,
  'updatedAt': instance.updatedAt,
};

const _$BangumiEpisodeCollectionTypeEnumMap = {
  BangumiEpisodeCollectionType.none: 0,
  BangumiEpisodeCollectionType.wish: 1,
  BangumiEpisodeCollectionType.done: 2,
  BangumiEpisodeCollectionType.dropped: 3,
};
