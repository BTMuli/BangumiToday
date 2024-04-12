import 'package:json_annotation/json_annotation.dart';

import '../app/response.dart';
import 'bangumi_model.dart';

/// bangumi.tv请求-用户模块的相关数据结构
/// 见：https://bangumi.github.io/api/#/用户
part 'request_user.g.dart';

/// 获取用户信息的请求返回
@JsonSerializable()
class BangumiUserInfoResp extends BTResponse<BangumiUser> {
  /// constructor
  BangumiUserInfoResp({
    required int code,
    required String message,
    required BangumiUser data,
  }) : super(code: code, message: message, data: data);

  /// success
  static BangumiUserInfoResp success({required BangumiUser data}) =>
      BangumiUserInfoResp(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiUserInfoResp.fromJson(Map<String, dynamic> json) =>
      _$BangumiUserInfoRespFromJson(json);
}
