import 'package:json_annotation/json_annotation.dart';

import '../app/response.dart';

part 'oauth.g.dart';

/// 配置文件中的 bangumi oauth 数据
@JsonSerializable()
class BangumiOauthConfig {
  /// client_id
  @JsonKey(name: 'client_id')
  String appId;

  /// client_secret
  @JsonKey(name: 'user_id')
  int userId;

  /// access_token
  @JsonKey(name: 'access_token')
  String accessToken;

  /// refresh_token
  @JsonKey(name: 'refresh_token')
  String refreshToken;

  /// expires_in
  @JsonKey(name: 'expires_in')
  int expiresIn;

  /// constructor
  BangumiOauthConfig({
    required this.appId,
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  /// from json
  factory BangumiOauthConfig.fromJson(Map<String, dynamic> json) =>
      _$BangumiOauthConfigFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiOauthConfigToJson(this);
}

/// oauth 的请求参数
@JsonSerializable()
class BangumiOauthParams {
  /// client_id
  @JsonKey(name: 'client_id')
  String appId;

  /// response_type
  @JsonKey(name: 'response_type')
  String responseType = 'code';

  /// redirect_uri
  @JsonKey(name: 'redirect_uri')
  String redirectUri = 'BangumiToday://oauth/bangumi/callback';

  /// constructor
  BangumiOauthParams({
    required this.appId,
  });

  /// from json
  factory BangumiOauthParams.fromJson(Map<String, dynamic> json) =>
      _$BangumiOauthParamsFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiOauthParamsToJson(this);
}

/// 获取 token 的请求参数
@JsonSerializable()
class BangumiTokenGParams {
  /// grant_type
  @JsonKey(name: 'grant_type')
  String grantType = 'authorization_code';

  /// client_id
  @JsonKey(name: 'client_id')
  String appId;

  /// client_secret
  @JsonKey(name: 'client_secret')
  String appSecret;

  /// code
  @JsonKey(name: 'code')
  String code;

  /// redirect_uri
  @JsonKey(name: 'redirect_uri')
  String redirectUri = 'BangumiToday://oauth/bangumi/callback';

  /// state
  @JsonKey(name: 'state')
  String? state;

  /// constructor
  BangumiTokenGParams({
    required this.appId,
    required this.appSecret,
    required this.code,
    required this.state,
  });

  /// from json
  factory BangumiTokenGParams.fromJson(Map<String, dynamic> json) =>
      _$BangumiTokenGParamsFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiTokenGParamsToJson(this);
}

/// 刷新 token 的请求参数
@JsonSerializable()
class BangumiTokenRParams {
  /// grant_type
  @JsonKey(name: 'grant_type')
  String grantType = 'refresh_token';

  /// client_id
  @JsonKey(name: 'client_id')
  String appId;

  /// client_secret
  @JsonKey(name: 'client_secret')
  String appSecret;

  /// refresh_token
  @JsonKey(name: 'refresh_token')
  String refreshToken;

  /// constructor
  BangumiTokenRParams({
    required this.appId,
    required this.appSecret,
    required this.refreshToken,
  });

  /// from json
  factory BangumiTokenRParams.fromJson(Map<String, dynamic> json) =>
      _$BangumiTokenRParamsFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiTokenRParamsToJson(this);
}

/// access token 请求返回
@JsonSerializable()
class BangumiTatResponse extends BTResponse<BangumiTatRespData> {
  /// constructor
  @override
  BangumiTatResponse({
    required int code,
    required String message,
    required BangumiTatRespData? data,
  }) : super(code: code, message: message, data: data);

  /// success
  static BangumiTatResponse success({required BangumiTatRespData data}) =>
      BangumiTatResponse(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiTatResponse.fromJson(Map<String, dynamic> json) =>
      _$BangumiTatResponseFromJson(json);
}

/// access token 返回
@JsonSerializable()
class BangumiTatRespData {
  /// access_token
  @JsonKey(name: 'access_token')
  String accessToken;

  /// expires_in
  @JsonKey(name: 'expires_in')
  int expiresIn;

  /// token_type
  @JsonKey(name: 'token_type')
  String tokenType;

  /// scope 可能是 null
  @JsonKey(name: 'scope')
  String? scope;

  /// refresh_token
  @JsonKey(name: 'refresh_token')
  String refreshToken;

  /// user_id
  @JsonKey(name: 'user_id')
  int userId;

  /// constructor
  BangumiTatRespData({
    required this.accessToken,
    required this.expiresIn,
    required this.tokenType,
    required this.scope,
    required this.refreshToken,
    required this.userId,
  });

  /// from json
  factory BangumiTatRespData.fromJson(Map<String, dynamic> json) =>
      _$BangumiTatRespDataFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiTatRespDataToJson(this);
}

/// refresh token 返回
@JsonSerializable()
class BangumiRtResponse extends BTResponse<BangumiRtRespData> {
  /// constructor
  @override
  BangumiRtResponse({
    required int code,
    required String message,
    required BangumiRtRespData? data,
  }) : super(code: code, message: message, data: data);

  /// success
  static BangumiRtResponse success({required BangumiRtRespData data}) =>
      BangumiRtResponse(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiRtResponse.fromJson(Map<String, dynamic> json) =>
      _$BangumiRtResponseFromJson(json);
}

/// refresh token 返回
@JsonSerializable()
class BangumiRtRespData {
  /// access_token
  @JsonKey(name: 'access_token')
  String accessToken;

  /// expires_in
  @JsonKey(name: 'expires_in')
  int expiresIn;

  /// token_type
  @JsonKey(name: 'token_type')
  String tokenType;

  /// scope 可能是 null
  @JsonKey(name: 'scope')
  String? scope;

  /// refresh_token
  @JsonKey(name: 'refresh_token')
  String refreshToken;

  /// constructor
  BangumiRtRespData({
    required this.accessToken,
    required this.expiresIn,
    required this.tokenType,
    required this.scope,
    required this.refreshToken,
  });

  /// from json
  factory BangumiRtRespData.fromJson(Map<String, dynamic> json) =>
      _$BangumiRtRespDataFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiRtRespDataToJson(this);
}

/// token status 请求返回
@JsonSerializable()
class BangumiTstResponse extends BTResponse<BangumiTstrData> {
  /// constructor
  @override
  BangumiTstResponse({
    required int code,
    required String message,
    required BangumiTstrData? data,
  }) : super(code: code, message: message, data: data);

  /// success
  static BangumiTstResponse success({required BangumiTstrData data}) =>
      BangumiTstResponse(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiTstResponse.fromJson(Map<String, dynamic> json) =>
      _$BangumiTstResponseFromJson(json);
}

/// 获取 token status 返回
@JsonSerializable()
class BangumiTstrData {
  /// access_token
  @JsonKey(name: 'access_token')
  String accessToken;

  /// client_id
  @JsonKey(name: 'client_id')
  String clientId;

  /// expires
  @JsonKey(name: 'expires')
  int expires;

  /// scope 可能是 null
  @JsonKey(name: 'scope')
  String? scope;

  /// user_id
  @JsonKey(name: 'user_id')
  int userId;

  /// constructor
  BangumiTstrData({
    required this.accessToken,
    required this.clientId,
    required this.expires,
    required this.scope,
    required this.userId,
  });

  /// from json
  factory BangumiTstrData.fromJson(Map<String, dynamic> json) =>
      _$BangumiTstrDataFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiTstrDataToJson(this);
}
