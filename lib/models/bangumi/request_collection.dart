import 'package:json_annotation/json_annotation.dart';

import '../app/response.dart';
import 'bangumi_model.dart';

/// bangumi.tv请求-收藏模块的相关数据结构
/// 见：https://bangumi.github.io/api/#/收藏
part 'request_collection.g.dart';

/// 获取用户收藏的请求返回
@JsonSerializable(createToJson: false)
class BangumiCollectionSubjectListResp
    extends BTResponse<BangumiPageT<BangumiUserSubjectCollection>> {
  /// constructor
  BangumiCollectionSubjectListResp({
    required super.code,
    required super.message,
    required BangumiPageT<BangumiUserSubjectCollection> super.data,
  });

  /// success
  static BangumiCollectionSubjectListResp success(
          {required BangumiPageT<BangumiUserSubjectCollection> data}) =>
      BangumiCollectionSubjectListResp(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiCollectionSubjectListResp.fromJson(
          Map<String, dynamic> json) =>
      _$BangumiCollectionSubjectListRespFromJson(json);
}

/// 获取用户单个收藏的请求返回
@JsonSerializable(createToJson: false)
class BangumiCollectionSubjectItemResp
    extends BTResponse<BangumiUserSubjectCollection> {
  /// constructor
  BangumiCollectionSubjectItemResp({
    required super.code,
    required super.message,
    required BangumiUserSubjectCollection super.data,
  });

  /// success
  static BangumiCollectionSubjectItemResp success(
          {required BangumiUserSubjectCollection data}) =>
      BangumiCollectionSubjectItemResp(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiCollectionSubjectItemResp.fromJson(
          Map<String, dynamic> json) =>
      _$BangumiCollectionSubjectItemRespFromJson(json);
}

/// 获取用户章节收藏的请求返回
@JsonSerializable(createToJson: false)
class BangumiCollectionEpisodeListResp
    extends BTResponse<BangumiPageT<BangumiUserEpisodeCollection>> {
  /// constructor
  BangumiCollectionEpisodeListResp({
    required super.code,
    required super.message,
    required BangumiPageT<BangumiUserEpisodeCollection> super.data,
  });

  /// success
  static BangumiCollectionEpisodeListResp success(
          {required BangumiPageT<BangumiUserEpisodeCollection> data}) =>
      BangumiCollectionEpisodeListResp(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiCollectionEpisodeListResp.fromJson(
          Map<String, dynamic> json) =>
      _$BangumiCollectionEpisodeListRespFromJson(json);
}

/// 获取用户单个章节收藏的请求返回
@JsonSerializable(createToJson: false)
class BangumiCollectionEpisodeItemResp
    extends BTResponse<BangumiUserEpisodeCollection> {
  /// constructor
  BangumiCollectionEpisodeItemResp({
    required super.code,
    required super.message,
    required BangumiUserEpisodeCollection super.data,
  });

  /// success
  static BangumiCollectionEpisodeItemResp success(
          {required BangumiUserEpisodeCollection data}) =>
      BangumiCollectionEpisodeItemResp(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiCollectionEpisodeItemResp.fromJson(
          Map<String, dynamic> json) =>
      _$BangumiCollectionEpisodeItemRespFromJson(json);
}
