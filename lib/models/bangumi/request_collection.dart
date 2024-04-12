import 'package:json_annotation/json_annotation.dart';

import '../app/response.dart';
import 'bangumi_model.dart';

/// bangumi.tv请求-收藏模块的相关数据结构
/// 见：https://bangumi.github.io/api/#/收藏
part 'request_collection.g.dart';

/// 获取用户收藏的请求返回
@JsonSerializable(createToJson: false)
class BangumiCollectionListResp
    extends BTResponse<BangumiPageT<BangumiUserSubjectCollection>> {
  /// constructor
  BangumiCollectionListResp({
    required int code,
    required String message,
    required BangumiPageT<BangumiUserSubjectCollection> data,
  }) : super(code: code, message: message, data: data);

  /// success
  static BangumiCollectionListResp success(
          {required BangumiPageT<BangumiUserSubjectCollection> data}) =>
      BangumiCollectionListResp(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiCollectionListResp.fromJson(Map<String, dynamic> json) =>
      _$BangumiCollectionListRespFromJson(json);
}

/// 获取用户单个收藏的请求返回
@JsonSerializable(createToJson: false)
class BangumiCollectionItemResp
    extends BTResponse<BangumiUserSubjectCollection> {
  /// constructor
  BangumiCollectionItemResp({
    required int code,
    required String message,
    required BangumiUserSubjectCollection data,
  }) : super(code: code, message: message, data: data);

  /// success
  static BangumiCollectionItemResp success(
          {required BangumiUserSubjectCollection data}) =>
      BangumiCollectionItemResp(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiCollectionItemResp.fromJson(Map<String, dynamic> json) =>
      _$BangumiCollectionItemRespFromJson(json);
}
