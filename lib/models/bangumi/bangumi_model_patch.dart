import 'package:json_annotation/json_annotation.dart';

/// 基于Bangumi API的数据模型，从中抽离了一些公共的字段
/// 详细文档参考 https://bangumi.github.io/api/
/// 模型定义在 bangumi_model.dart 中
part 'bangumi_model_patch.g.dart';

/// 通用模型-评分
@JsonSerializable()
class BangumiPatchRating {
  /// total
  @JsonKey(name: 'total')
  int total;

  /// count
  @JsonKey(name: 'count')
  Map<String, int> count;

  /// score
  @JsonKey(name: 'score')
  double score;

  /// rank
  @JsonKey(name: 'rank')
  int? rank;

  /// constructor
  BangumiPatchRating({
    required this.total,
    required this.count,
    required this.score,
    required this.rank,
  });

  /// from json
  factory BangumiPatchRating.fromJson(Map<String, dynamic> json) =>
      _$BangumiPatchRatingFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiPatchRatingToJson(this);
}

/// 通用模型-收藏
@JsonSerializable()
class BangumiPatchCollection {
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
  BangumiPatchCollection({
    required this.wish,
    required this.collect,
    required this.doing,
    required this.onHold,
    required this.dropped,
  });

  /// from json
  factory BangumiPatchCollection.fromJson(Map<String, dynamic> json) =>
      _$BangumiPatchCollectionFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiPatchCollectionToJson(this);
}
