// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import 'bangumi_enum.dart';
import 'bangumi_model_person.dart';

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

/// 章节详情（Next API）
///
/// 除章节本体外还内嵌所属条目摘要与当前用户的章节收藏状态。
/// 文档：https://github.com/bangumi/server-private/blob/master/openapi.json
@JsonSerializable(explicitToJson: true)
class BangumiEpisodeDetail {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// 所属条目 id
  @JsonKey(name: 'subjectID')
  int subjectId;

  /// type
  @JsonKey(name: 'type')
  BangumiEpType type;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// nameCN
  @JsonKey(name: 'nameCN')
  String nameCn;

  /// sort
  @JsonKey(name: 'sort')
  double sort;

  /// airdate
  @JsonKey(name: 'airdate')
  String airDate;

  /// duration
  @JsonKey(name: 'duration')
  String duration;

  /// desc
  @JsonKey(name: 'desc')
  String desc;

  /// 吐槽数，含回复
  @JsonKey(name: 'comment')
  int comment;

  /// 碟号
  @JsonKey(name: 'disc')
  int disc;

  /// 所属条目摘要
  @JsonKey(name: 'subject')
  BangumiEpisodeSubject? subject;

  /// 当前用户收藏状态，未登录时为空
  @JsonKey(name: 'collection')
  BangumiEpisodeCollection? collection;

  /// constructor
  BangumiEpisodeDetail({
    required this.id,
    required this.subjectId,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.sort,
    required this.airDate,
    required this.duration,
    required this.desc,
    required this.comment,
    required this.disc,
    required this.subject,
    required this.collection,
  });

  /// from json
  factory BangumiEpisodeDetail.fromJson(Map<String, dynamic> json) =>
      _$BangumiEpisodeDetailFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiEpisodeDetailToJson(this);
}

/// 章节详情内嵌的条目摘要
@JsonSerializable(explicitToJson: true)
class BangumiEpisodeSubject {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  @JsonKey(name: 'type')
  BangumiSubjectType type;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// nameCN
  @JsonKey(name: 'nameCN')
  String nameCn;

  /// info，如「12话 / 2026年10月2日 / ...」
  @JsonKey(name: 'info')
  String info;

  /// metaTags
  @JsonKey(name: 'metaTags')
  List<String> metaTags;

  /// images
  @JsonKey(name: 'images')
  BangumiImages? images;

  /// rating
  @JsonKey(name: 'rating')
  BangumiEpisodeSubjectRating? rating;

  /// constructor
  BangumiEpisodeSubject({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.info,
    required this.metaTags,
    required this.images,
    required this.rating,
  });

  /// from json
  factory BangumiEpisodeSubject.fromJson(Map<String, dynamic> json) =>
      _$BangumiEpisodeSubjectFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiEpisodeSubjectToJson(this);
}

/// 章节详情内嵌条目的评分摘要
@JsonSerializable()
class BangumiEpisodeSubjectRating {
  /// score
  @JsonKey(name: 'score')
  double score;

  /// total
  @JsonKey(name: 'total')
  int total;

  /// rank
  @JsonKey(name: 'rank')
  int? rank;

  /// constructor
  BangumiEpisodeSubjectRating({
    required this.score,
    required this.total,
    required this.rank,
  });

  /// from json
  factory BangumiEpisodeSubjectRating.fromJson(Map<String, dynamic> json) =>
      _$BangumiEpisodeSubjectRatingFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiEpisodeSubjectRatingToJson(this);
}

/// 章节收藏状态
@JsonSerializable()
class BangumiEpisodeCollection {
  /// status
  @JsonKey(name: 'status')
  BangumiEpisodeCollectionType status;

  /// updatedAt
  @JsonKey(name: 'updatedAt')
  int? updatedAt;

  /// constructor
  BangumiEpisodeCollection({required this.status, required this.updatedAt});

  /// from json
  factory BangumiEpisodeCollection.fromJson(Map<String, dynamic> json) =>
      _$BangumiEpisodeCollectionFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiEpisodeCollectionToJson(this);
}
