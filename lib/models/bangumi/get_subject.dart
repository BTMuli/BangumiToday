import 'package:json_annotation/json_annotation.dart';

import 'common_model.dart';

part 'get_subject.g.dart';

/// 获取番剧详情
/// 详细文档请参考 https://bangumi.github.io/api/
/// get => https://api.bgm.tv/v0/subject/:id
@JsonSerializable()
class BangumiSubject {
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
  List<BangumiSubjectTag> tags;

  /// infobox
  @JsonKey(name: 'infobox')
  List<BangumiSubjectInfoBox> infobox;

  /// rating
  @JsonKey(name: 'rating')
  BangumiSubjectRating rating;

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
  BangumiSubject({
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
  factory BangumiSubject.fromJson(Map<String, dynamic> json) =>
      _$BangumiSubjectFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiSubjectToJson(this);
}

/// 标签
@JsonSerializable()
class BangumiSubjectTag {
  /// name
  @JsonKey(name: 'name')
  String name;

  /// count
  @JsonKey(name: 'count')
  int count;

  /// constructor
  BangumiSubjectTag({
    required this.name,
    required this.count,
  });

  /// from json
  factory BangumiSubjectTag.fromJson(Map<String, dynamic> json) =>
      _$BangumiSubjectTagFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiSubjectTagToJson(this);
}

/// 信息
@JsonSerializable()
class BangumiSubjectInfoBox {
  /// key
  @JsonKey(name: 'key')
  String key;

  /// value
  /// string | Array<{v:string,k?:string}>
  @JsonKey(name: 'value')
  dynamic value;

  /// constructor
  BangumiSubjectInfoBox({
    required this.key,
    required this.value,
  });

  /// from json
  factory BangumiSubjectInfoBox.fromJson(Map<String, dynamic> json) =>
      _$BangumiSubjectInfoBoxFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiSubjectInfoBoxToJson(this);
}

/// 评分
@JsonSerializable()
class BangumiSubjectRating extends BangumiRating {
  /// rank
  @JsonKey(name: 'rank')
  int? rank;

  /// constructor
  BangumiSubjectRating({
    required super.total,
    required super.count,
    required super.score,
    required this.rank,
  });

  /// from json
  factory BangumiSubjectRating.fromJson(Map<String, dynamic> json) =>
      _$BangumiSubjectRatingFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiSubjectRatingToJson(this);
}
