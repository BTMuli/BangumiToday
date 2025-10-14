// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import '../app/response.dart';
import 'bangumi_model.dart';

/// bangumi.tv请求-章节模块的相关数据结构
/// 见：https://bangumi.github.io/api/#/章节
part 'request_episode.g.dart';

/// 获取subject的章节请求返回
@JsonSerializable(createToJson: false)
class BangumiEpisodeListResp extends BTResponse<BangumiPageT<BangumiEpisode>> {
  /// constructor
  BangumiEpisodeListResp({
    required super.code,
    required super.message,
    required BangumiPageT<BangumiEpisode> super.data,
  });

  /// success
  static BangumiEpisodeListResp success({
    required BangumiPageT<BangumiEpisode> data,
  }) => BangumiEpisodeListResp(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiEpisodeListResp.fromJson(Map<String, dynamic> json) =>
      _$BangumiEpisodeListRespFromJson(json);
}
