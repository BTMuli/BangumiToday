import 'package:json_annotation/json_annotation.dart';

import '../app/response.dart';

part 'user_request.g.dart';

/// 获取用户信息成功响应
@JsonSerializable()
class BangumiUserInfoResponse extends BTResponse<BangumiUserInfo> {
  /// constructor
  @override
  BangumiUserInfoResponse({
    required int code,
    required String message,
    required BangumiUserInfo? data,
  }) : super(code: code, message: message, data: data);

  /// success
  static BangumiUserInfoResponse success({required BangumiUserInfo data}) =>
      BangumiUserInfoResponse(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiUserInfoResponse.fromJson(Map<String, dynamic> json) =>
      _$BangumiUserInfoResponseFromJson(json);
}

/// 用户信息
@JsonSerializable()
class BangumiUserInfo {
  /// avatar
  @JsonKey(name: 'avatar')
  BangumiUserAvatar avatar;

  /// sign
  @JsonKey(name: 'sign')
  String sign;

  /// username
  @JsonKey(name: 'username')
  String username;

  /// nickname
  @JsonKey(name: 'nickname')
  String nickname;

  /// id
  @JsonKey(name: 'id')
  int id;

  /// user_group
  @JsonKey(name: 'user_group')
  int userGroup;

  /// constructor
  BangumiUserInfo({
    required this.avatar,
    required this.sign,
    required this.username,
    required this.nickname,
    required this.id,
    required this.userGroup,
  });

  /// from json
  factory BangumiUserInfo.fromJson(Map<String, dynamic> json) =>
      _$BangumiUserInfoFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiUserInfoToJson(this);
}

/// 用户头像
@JsonSerializable()
class BangumiUserAvatar {
  /// large
  @JsonKey(name: 'large')
  String large;

  /// medium
  @JsonKey(name: 'medium')
  String medium;

  /// small
  @JsonKey(name: 'small')
  String small;

  /// constructor
  BangumiUserAvatar({
    required this.large,
    required this.medium,
    required this.small,
  });

  /// from json
  factory BangumiUserAvatar.fromJson(Map<String, dynamic> json) =>
      _$BangumiUserAvatarFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiUserAvatarToJson(this);
}
