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
  type: $enumDecode(_$BangumiEpTypeEnumMap, json['type']),
  name: json['name'] as String,
  nameCn: json['name_cn'] as String,
  sort: (json['sort'] as num).toInt(),
  ep: (json['ep'] as num).toInt(),
  airDate: json['airdate'] as String,
  comment: (json['comment'] as num).toInt(),
  duration: json['duration'] as String,
  desc: json['desc'] as String,
  disc: (json['disc'] as num).toInt(),
  subjectId: (json['subject_id'] as num).toInt(),
);

Map<String, dynamic> _$BangumiEpisodeDetailToJson(
  BangumiEpisodeDetail instance,
) => <String, dynamic>{
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
  'subject_id': instance.subjectId,
};
