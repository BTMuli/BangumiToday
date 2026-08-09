// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import 'bangumi_enum.dart';
import 'bangumi_model_index.dart';
import 'bangumi_model_patch.dart';
import 'bangumi_model_person.dart';

part 'bangumi_model_subject.g.dart';

/// Subject
@JsonSerializable(explicitToJson: true)
class BangumiSubject {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  @JsonKey(name: 'type')
  BangumiSubjectType type;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// summary
  @JsonKey(name: 'summary')
  String summary;

  /// nsfw
  @JsonKey(name: 'nsfw')
  bool nsfw;

  /// locked
  @JsonKey(name: 'locked')
  bool locked;

  /// date
  @JsonKey(name: 'date')
  String? date;

  /// platform
  @JsonKey(name: 'platform')
  String platform;

  /// images
  @JsonKey(name: 'images')
  BangumiImages images;

  /// infobox
  @JsonKey(name: 'infobox')
  List<BangumiInfoBoxItem> infobox;

  /// volumes
  @JsonKey(name: 'volumes')
  int volumes;

  /// eps
  @JsonKey(name: 'eps')
  int eps;

  /// total_episodes
  @JsonKey(name: 'total_episodes')
  int totalEpisodes;

  /// rating
  @JsonKey(name: 'rating')
  BangumiPatchRating rating;

  /// collection
  @JsonKey(name: 'collection')
  BangumiPatchCollection collection;

  /// tags
  @JsonKey(name: 'tags')
  List<BangumiTag> tags;

  /// constructor
  BangumiSubject({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.nsfw,
    required this.locked,
    required this.date,
    required this.platform,
    required this.images,
    required this.infobox,
    required this.volumes,
    required this.eps,
    required this.totalEpisodes,
    required this.rating,
    required this.collection,
    required this.tags,
  });

  /// from json
  factory BangumiSubject.fromJson(Map<String, dynamic> json) =>
      _$BangumiSubjectFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiSubjectToJson(this);
}

/// SlimSubject
@JsonSerializable(explicitToJson: true)
class BangumiSlimSubject {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  @JsonKey(name: 'type')
  BangumiSubjectType type;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// short_summary
  @JsonKey(name: 'short_summary')
  String shortSummary;

  /// date
  @JsonKey(name: 'date')
  String? date;

  /// images
  @JsonKey(name: 'images')
  BangumiImages images;

  /// volumes
  @JsonKey(name: 'volumes')
  int volumes;

  /// eps
  @JsonKey(name: 'eps')
  int eps;

  /// collection_total
  @JsonKey(name: 'collection_total')
  int collectionTotal;

  /// score
  @JsonKey(name: 'score')
  double score;

  /// tags
  @JsonKey(name: 'tags')
  List<BangumiTag> tags;

  /// constructor
  BangumiSlimSubject({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.shortSummary,
    required this.date,
    required this.images,
    required this.volumes,
    required this.eps,
    required this.collectionTotal,
    required this.score,
    required this.tags,
  });

  /// from json
  factory BangumiSlimSubject.fromJson(Map<String, dynamic> json) =>
      _$BangumiSlimSubjectFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiSlimSubjectToJson(this);
}

/// Tags
/// 因为本身是个列表，所以定义列表的内容
@JsonSerializable()
class BangumiTag {
  /// name
  @JsonKey(name: 'name')
  String name;

  /// count
  @JsonKey(name: 'count')
  int count;

  /// constructor
  BangumiTag({required this.name, required this.count});

  /// from json
  factory BangumiTag.fromJson(Map<String, dynamic> json) =>
      _$BangumiTagFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiTagToJson(this);
}

/// RelatedSubject
@JsonSerializable()
class BangumiRelatedSubject {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// staff
  @JsonKey(name: 'staff')
  String staff;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// image
  @JsonKey(name: 'image')
  String image;

  /// constructor
  BangumiRelatedSubject({
    required this.id,
    required this.staff,
    required this.name,
    required this.nameCn,
    required this.image,
  });

  /// from json
  factory BangumiRelatedSubject.fromJson(Map<String, dynamic> json) =>
      _$BangumiRelatedSubjectFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiRelatedSubjectToJson(this);
}

/// SubjectRelation
@JsonSerializable(explicitToJson: true)
class BangumiSubjectRelation {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  @JsonKey(name: 'type')
  BangumiSubjectType type;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// images
  @JsonKey(name: 'images')
  BangumiImages images;

  /// relation
  @JsonKey(name: 'relation')
  String relation;

  /// constructor
  BangumiSubjectRelation({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.images,
    required this.relation,
  });

  /// from json
  factory BangumiSubjectRelation.fromJson(Map<String, dynamic> json) =>
      _$BangumiSubjectRelationFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiSubjectRelationToJson(this);
}
