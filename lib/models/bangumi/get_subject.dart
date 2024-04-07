import 'package:json_annotation/json_annotation.dart';

import 'common_model.dart';

part 'get_subject.g.dart';

/// 获取番剧详情
/// 详细文档请参考 https://bangumi.github.io/api/
/// get => https://api.bgm.tv/v0/subject/:id
@JsonSerializable()
class Subject {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  @JsonKey(name: 'type')
  int type;

  /// platform
  @JsonKey(name: 'platform')
  String platform;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// summary
  @JsonKey(name: 'summary')
  String summary;

  /// date yyyy-MM-dd
  @JsonKey(name: 'date')
  String date;

  /// images
  @JsonKey(name: 'images')
  BangumiImage images;

  /// eps
  @JsonKey(name: 'eps')
  int eps;

  /// volumes
  @JsonKey(name: 'volumes')
  int volumes;

  /// tags
  @JsonKey(name: 'tags')
  List<SubjectTag> tags;

  /// infobox
  @JsonKey(name: 'infobox')
  List<SubjectInfoBox> infobox;

  /// rating
  @JsonKey(name: 'rating')
  SubjectRating rating;

  /// total_episodes
  @JsonKey(name: 'total_episodes')
  int totalEpisodes;

  /// collection
  @JsonKey(name: 'collection')
  BangumiCollection collection;

  /// locked
  @JsonKey(name: 'locked')
  bool locked;

  /// nsfw -> Not Safe For Work
  @JsonKey(name: 'nsfw')
  bool nsfw;

  /// constructor
  Subject({
    required this.id,
    required this.type,
    required this.platform,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.date,
    required this.images,
    required this.eps,
    required this.volumes,
    required this.tags,
    required this.infobox,
    required this.rating,
    required this.totalEpisodes,
    required this.collection,
    required this.locked,
    required this.nsfw,
  });

  /// from json
  factory Subject.fromJson(Map<String, dynamic> json) =>
      _$SubjectFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$SubjectToJson(this);
}

/// 标签
@JsonSerializable()
class SubjectTag {
  /// name
  @JsonKey(name: 'name')
  String name;

  /// count
  @JsonKey(name: 'count')
  int count;

  /// constructor
  SubjectTag({
    required this.name,
    required this.count,
  });

  /// from json
  factory SubjectTag.fromJson(Map<String, dynamic> json) =>
      _$SubjectTagFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$SubjectTagToJson(this);
}

/// 信息
@JsonSerializable()
class SubjectInfoBox {
  /// key
  @JsonKey(name: 'key')
  String key;

  /// value
  /// string | Array<{v:string}>
  @JsonKey(name: 'value')
  dynamic value;

  /// constructor
  SubjectInfoBox({
    required this.key,
    required this.value,
  });

  /// from json
  factory SubjectInfoBox.fromJson(Map<String, dynamic> json) =>
      _$SubjectInfoBoxFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$SubjectInfoBoxToJson(this);
}

/// 评分
@JsonSerializable()
class SubjectRating extends BangumiRating {
  /// rank
  @JsonKey(name: 'rank')
  int? rank;

  /// constructor
  SubjectRating({
    required super.total,
    required super.count,
    required super.score,
    required this.rank,
  });

  /// from json
  factory SubjectRating.fromJson(Map<String, dynamic> json) =>
      _$SubjectRatingFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$SubjectRatingToJson(this);
}
