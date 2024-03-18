import 'package:json_annotation/json_annotation.dart';

part 'common_model.g.dart';

/// 通用模型-图片
@JsonSerializable()
class BangumiImage {
  /// large
  @JsonKey(name: 'large')
  String large;

  /// common
  @JsonKey(name: 'common')
  String common;

  /// medium
  @JsonKey(name: 'medium')
  String medium;

  /// small
  @JsonKey(name: 'small')
  String small;

  /// grid
  @JsonKey(name: 'grid')
  String grid;

  /// constructor
  BangumiImage({
    required this.large,
    required this.common,
    required this.medium,
    required this.small,
    required this.grid,
  });

  /// from json
  factory BangumiImage.fromJson(Map<String, dynamic> json) =>
      _$BangumiImageFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiImageToJson(this);
}

/// 通用模型-评分
@JsonSerializable()
class BangumiRating {
  /// total
  @JsonKey(name: 'total')
  int total;

  /// count
  @JsonKey(name: 'count')
  Map<String, int> count;

  /// score
  @JsonKey(name: 'score')
  double score;

  /// constructor
  BangumiRating({
    required this.total,
    required this.count,
    required this.score,
  });

  /// from json
  factory BangumiRating.fromJson(Map<String, dynamic> json) =>
      _$BangumiRatingFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiRatingToJson(this);
}

/// 通用模型-收藏
@JsonSerializable()
class BangumiCollection {
  /// wish
  @JsonKey(name: 'wish')
  int? wish;

  /// collect
  @JsonKey(name: 'collect')
  int? collect;

  /// doing
  @JsonKey(name: 'doing')
  int? doing;

  /// on_hold
  @JsonKey(name: 'on_hold')
  int? onHold;

  /// dropped
  @JsonKey(name: 'dropped')
  int? dropped;

  /// constructor
  BangumiCollection({
    required this.wish,
    required this.collect,
    required this.doing,
    required this.onHold,
    required this.dropped,
  });

  /// from json
  factory BangumiCollection.fromJson(Map<String, dynamic> json) =>
      _$BangumiCollectionFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiCollectionToJson(this);
}
