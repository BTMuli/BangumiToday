// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import 'bangumi_enum.dart';

part 'bangumi_model_episode.g.dart';

/// Episode
@JsonSerializable()
class BangumiEpisode {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  @JsonKey(name: 'type')
  BangumiEpType type;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// sort
  @JsonKey(name: 'sort')
  double sort;

  /// ep
  @JsonKey(name: 'ep')
  double ep;

  /// airdate
  @JsonKey(name: 'airdate')
  String airDate;

  /// comment
  @JsonKey(name: 'comment')
  int comment;

  /// duration
  @JsonKey(name: 'duration')
  String duration;

  /// desc
  @JsonKey(name: 'desc')
  String desc;

  /// disc
  @JsonKey(name: 'disc')
  int disc;

  /// duration_seconds
  @JsonKey(name: 'duration_seconds')
  int durationSeconds;

  /// constructor
  BangumiEpisode({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.sort,
    required this.ep,
    required this.airDate,
    required this.comment,
    required this.duration,
    required this.desc,
    required this.disc,
    required this.durationSeconds,
  });

  /// from json
  factory BangumiEpisode.fromJson(Map<String, dynamic> json) =>
      _$BangumiEpisodeFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiEpisodeToJson(this);
}

/// EpisodeDetail
@JsonSerializable()
class BangumiEpisodeDetail {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  @JsonKey(name: 'type')
  BangumiEpType type;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// sort
  @JsonKey(name: 'sort')
  int sort;

  /// ep
  @JsonKey(name: 'ep')
  int ep;

  /// airdate
  @JsonKey(name: 'airdate')
  String airDate;

  /// comment
  @JsonKey(name: 'comment')
  int comment;

  /// duration
  @JsonKey(name: 'duration')
  String duration;

  /// desc
  @JsonKey(name: 'desc')
  String desc;

  /// disc
  @JsonKey(name: 'disc')
  int disc;

  /// subject_id
  @JsonKey(name: 'subject_id')
  int subjectId;

  /// constructor
  BangumiEpisodeDetail({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.sort,
    required this.ep,
    required this.airDate,
    required this.comment,
    required this.duration,
    required this.desc,
    required this.disc,
    required this.subjectId,
  });

  /// from json
  factory BangumiEpisodeDetail.fromJson(Map<String, dynamic> json) =>
      _$BangumiEpisodeDetailFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiEpisodeDetailToJson(this);
}
