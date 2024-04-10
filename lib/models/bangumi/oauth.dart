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

/// access token 返回
@JsonSerializable()
class BangumiTokenGResponse {
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
  BangumiTokenGResponse({
    required this.accessToken,
    required this.expiresIn,
    required this.tokenType,
    required this.scope,
    required this.refreshToken,
    required this.userId,
  });

  /// from json
  factory BangumiTokenGResponse.fromJson(Map<String, dynamic> json) =>
      _$BangumiTokenGResponseFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiTokenGResponseToJson(this);
}

/// refresh token 返回
@JsonSerializable()
class BangumiTokenRResponse {
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
  BangumiTokenRResponse({
    required this.accessToken,
    required this.expiresIn,
    required this.tokenType,
    required this.scope,
    required this.refreshToken,
  });

  /// from json
  factory BangumiTokenRResponse.fromJson(Map<String, dynamic> json) =>
      _$BangumiTokenRResponseFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiTokenRResponseToJson(this);
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
