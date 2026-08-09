// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import 'bangumi_enum.dart';
import 'bangumi_model_episode.dart';
import 'bangumi_model_subject.dart';

part 'bangumi_model_collection.g.dart';

/// UserSubjectCollection
@JsonSerializable(explicitToJson: true)
class BangumiUserSubjectCollection {
  /// subject_id
  @JsonKey(name: 'subject_id')
  int subjectId;

  /// subject_type
  @JsonKey(name: 'subject_type')
  BangumiSubjectType subjectType;

  /// rate
  @JsonKey(name: 'rate')
  int rate;

  /// type
  @JsonKey(name: 'type')
  BangumiCollectionType type;

  /// comment
  @JsonKey(name: 'comment')
  String? comment;

  /// tags
  @JsonKey(name: 'tags')
  List<String> tags;

  /// ep_status
  @JsonKey(name: 'ep_status')
  int epStatus;

  /// vol_status
  @JsonKey(name: 'vol_status')
  int volStatus;

  /// updated_at
  @JsonKey(name: 'updated_at')
  String updatedAt;

  /// private
  @JsonKey(name: 'private')
  bool private;

  /// subject
  @JsonKey(name: 'subject')
  BangumiSlimSubject subject;

  /// constructor
  BangumiUserSubjectCollection({
    required this.subjectId,
    required this.subjectType,
    required this.rate,
    required this.type,
    required this.comment,
    required this.tags,
    required this.epStatus,
    required this.volStatus,
    required this.updatedAt,
    required this.private,
    required this.subject,
  });

  /// from json
  factory BangumiUserSubjectCollection.fromJson(Map<String, dynamic> json) =>
      _$BangumiUserSubjectCollectionFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiUserSubjectCollectionToJson(this);

  /// toSqlJson
  /// 参照：libs/database/bangumi/bangumi_collection.dart的表格定义
  Map<String, dynamic> toSqlJson() {
    return {
      'subjectId': subjectId,
      'subjectType': subjectType.value,
      'rate': rate,
      'collectionType': type.value,
      'comment': comment,
      'tags': jsonEncode(tags),
      'epStat': epStatus,
      'volStat': volStatus,
      'updatedAt': updatedAt,
      'private': private ? 1 : 0,
      'subject': jsonEncode(subject.toJson()),
    };
  }

  /// fromSqlJson
  /// 参照：libs/database/bangumi/bangumi_collection.dart的表格定义
  factory BangumiUserSubjectCollection.fromSqlJson(Map<String, dynamic> json) {
    return BangumiUserSubjectCollection.fromJson({
      'subject_id': json['subjectId'],
      'subject_type': json['subjectType'],
      'rate': json['rate'],
      'type': json['collectionType'],
      'comment': json['comment'],
      'tags': jsonDecode(json['tags']),
      'ep_status': json['epStat'],
      'vol_status': json['volStat'],
      'updated_at': json['updatedAt'],
      'private': json['private'] == 1,
      'subject': jsonDecode(json['subject']),
    });
  }
}

/// UserSubjectCollectionModifyPayload
@JsonSerializable()
class BangumiUserSubjectCollectionModifyPayload {
  /// type
  @JsonKey(name: 'type')
  BangumiCollectionType type;

  /// rate
  @JsonKey(name: 'rate')
  int rate;

  /// ep_status
  @JsonKey(name: 'ep_status')
  int epStatus;

  /// vol_status
  @JsonKey(name: 'vol_status')
  int volStatus;

  /// comment
  @JsonKey(name: 'comment')
  String comment;

  /// private
  @JsonKey(name: 'private')
  bool private;

  /// tags
  @JsonKey(name: 'tags')
  List<String> tags;

  /// constructor
  BangumiUserSubjectCollectionModifyPayload({
    required this.type,
    required this.rate,
    required this.epStatus,
    required this.volStatus,
    required this.comment,
    required this.private,
    required this.tags,
  });

  /// from json
  factory BangumiUserSubjectCollectionModifyPayload.fromJson(
    Map<String, dynamic> json,
  ) => _$BangumiUserSubjectCollectionModifyPayloadFromJson(json);

  /// to json
  Map<String, dynamic> toJson() =>
      _$BangumiUserSubjectCollectionModifyPayloadToJson(this);
}

/// UserEpisodeCollection
@JsonSerializable(explicitToJson: true)
class BangumiUserEpisodeCollection {
  /// episode
  @JsonKey(name: 'episode')
  BangumiEpisode episode;

  /// type
  @JsonKey(name: 'type')
  BangumiEpisodeCollectionType type;

  /// constructor
  BangumiUserEpisodeCollection({required this.episode, required this.type});

  /// from json
  factory BangumiUserEpisodeCollection.fromJson(Map<String, dynamic> json) =>
      _$BangumiUserEpisodeCollectionFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiUserEpisodeCollectionToJson(this);
}
