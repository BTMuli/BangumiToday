import 'package:json_annotation/json_annotation.dart';

import '../app/response.dart';

/// Bangumi.tv 的 OAuth 相关数据结构
/// 参考: https://github.com/bangumi/api/blob/master/docs-raw/How-to-Auth.md
part 'bangumi_oauth_model.g.dart';

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
class BangumiOauthTokenGetParams {
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
  BangumiOauthTokenGetParams({
    required this.appId,
    required this.appSecret,
    required this.code,
    required this.state,
  });

  /// from json
  factory BangumiOauthTokenGetParams.fromJson(Map<String, dynamic> json) =>
      _$BangumiOauthTokenGetParamsFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiOauthTokenGetParamsToJson(this);
}

/// access token 请求返回
@JsonSerializable(createToJson: false)
class BangumiOauthTokenGetResp extends BTResponse<BangumiOauthTokenGetData> {
  /// constructor
  @override
  BangumiOauthTokenGetResp({
    required super.code,
    required super.message,
    required super.data,
  });

  /// success
  static BangumiOauthTokenGetResp success(
          {required BangumiOauthTokenGetData data}) =>
      BangumiOauthTokenGetResp(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiOauthTokenGetResp.fromJson(Map<String, dynamic> json) =>
      _$BangumiOauthTokenGetRespFromJson(json);
}

/// access token 返回数据
@JsonSerializable()
class BangumiOauthTokenGetData {
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
  BangumiOauthTokenGetData({
    required this.accessToken,
    required this.expiresIn,
    required this.tokenType,
    required this.scope,
    required this.refreshToken,
    required this.userId,
  });

  /// from json
  factory BangumiOauthTokenGetData.fromJson(Map<String, dynamic> json) =>
      _$BangumiOauthTokenGetDataFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiOauthTokenGetDataToJson(this);
}

/// 刷新 token 的请求参数
@JsonSerializable()
class BangumiOauthTokenRefreshParams {
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
  BangumiOauthTokenRefreshParams({
    required this.appId,
    required this.appSecret,
    required this.refreshToken,
  });

  /// from json
  factory BangumiOauthTokenRefreshParams.fromJson(Map<String, dynamic> json) =>
      _$BangumiOauthTokenRefreshParamsFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiOauthTokenRefreshParamsToJson(this);
}

/// refresh token 返回
@JsonSerializable(createToJson: false)
class BangumiOauthTokenRefreshResp
    extends BTResponse<BangumiOauthTokenRefreshData> {
  /// constructor
  @override
  BangumiOauthTokenRefreshResp({
    required super.code,
    required super.message,
    required super.data,
  });

  /// success
  static BangumiOauthTokenRefreshResp success(
          {required BangumiOauthTokenRefreshData data}) =>
      BangumiOauthTokenRefreshResp(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiOauthTokenRefreshResp.fromJson(Map<String, dynamic> json) =>
      _$BangumiOauthTokenRefreshRespFromJson(json);
}

/// refresh token 返回
@JsonSerializable()
class BangumiOauthTokenRefreshData {
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
  BangumiOauthTokenRefreshData({
    required this.accessToken,
    required this.expiresIn,
    required this.tokenType,
    required this.scope,
    required this.refreshToken,
  });

  /// from json
  factory BangumiOauthTokenRefreshData.fromJson(Map<String, dynamic> json) =>
      _$BangumiOauthTokenRefreshDataFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiOauthTokenRefreshDataToJson(this);
}

/// token status 请求返回
@JsonSerializable(createToJson: false)
class BangumiOauthTokenStatusResp
    extends BTResponse<BangumiOauthTokenStatusData> {
  /// constructor
  @override
  BangumiOauthTokenStatusResp({
    required super.code,
    required super.message,
    required super.data,
  });

  /// success
  static BangumiOauthTokenStatusResp success(
          {required BangumiOauthTokenStatusData data}) =>
      BangumiOauthTokenStatusResp(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiOauthTokenStatusResp.fromJson(Map<String, dynamic> json) =>
      _$BangumiOauthTokenStatusRespFromJson(json);
}

/// 获取 token status 返回
@JsonSerializable()
class BangumiOauthTokenStatusData {
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
  BangumiOauthTokenStatusData({
    required this.accessToken,
    required this.clientId,
    required this.expires,
    required this.scope,
    required this.userId,
  });

  /// from json
  factory BangumiOauthTokenStatusData.fromJson(Map<String, dynamic> json) =>
      _$BangumiOauthTokenStatusDataFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiOauthTokenStatusDataToJson(this);
}
