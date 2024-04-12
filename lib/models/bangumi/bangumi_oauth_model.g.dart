// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_oauth_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiOauthConfig _$BangumiOauthConfigFromJson(Map<String, dynamic> json) =>
    BangumiOauthConfig(
      appId: json['client_id'] as String,
      userId: json['user_id'] as int,
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
    );

Map<String, dynamic> _$BangumiOauthConfigToJson(BangumiOauthConfig instance) =>
    <String, dynamic>{
      'client_id': instance.appId,
      'user_id': instance.userId,
      'access_token': instance.accessToken,
      'refresh_token': instance.refreshToken,
      'expires_in': instance.expiresIn,
    };

BangumiOauthParams _$BangumiOauthParamsFromJson(Map<String, dynamic> json) =>
    BangumiOauthParams(
      appId: json['client_id'] as String,
    )
      ..responseType = json['response_type'] as String
      ..redirectUri = json['redirect_uri'] as String;

Map<String, dynamic> _$BangumiOauthParamsToJson(BangumiOauthParams instance) =>
    <String, dynamic>{
      'client_id': instance.appId,
      'response_type': instance.responseType,
      'redirect_uri': instance.redirectUri,
    };

BangumiOauthTokenGetParams _$BangumiOauthTokenGetParamsFromJson(
        Map<String, dynamic> json) =>
    BangumiOauthTokenGetParams(
      appId: json['client_id'] as String,
      appSecret: json['client_secret'] as String,
      code: json['code'] as String,
      state: json['state'] as String?,
    )
      ..grantType = json['grant_type'] as String
      ..redirectUri = json['redirect_uri'] as String;

Map<String, dynamic> _$BangumiOauthTokenGetParamsToJson(
        BangumiOauthTokenGetParams instance) =>
    <String, dynamic>{
      'grant_type': instance.grantType,
      'client_id': instance.appId,
      'client_secret': instance.appSecret,
      'code': instance.code,
      'redirect_uri': instance.redirectUri,
      'state': instance.state,
    };

BangumiOauthTokenGetResp _$BangumiOauthTokenGetRespFromJson(
        Map<String, dynamic> json) =>
    BangumiOauthTokenGetResp(
      code: json['code'] as int,
      message: json['message'] as String,
      data: json['data'] == null
          ? null
          : BangumiOauthTokenGetData.fromJson(
              json['data'] as Map<String, dynamic>),
    );

BangumiOauthTokenGetData _$BangumiOauthTokenGetDataFromJson(
        Map<String, dynamic> json) =>
    BangumiOauthTokenGetData(
      accessToken: json['access_token'] as String,
      expiresIn: json['expires_in'] as int,
      tokenType: json['token_type'] as String,
      scope: json['scope'] as String?,
      refreshToken: json['refresh_token'] as String,
      userId: json['user_id'] as int,
    );

Map<String, dynamic> _$BangumiOauthTokenGetDataToJson(
        BangumiOauthTokenGetData instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'expires_in': instance.expiresIn,
      'token_type': instance.tokenType,
      'scope': instance.scope,
      'refresh_token': instance.refreshToken,
      'user_id': instance.userId,
    };

BangumiOauthTokenRefreshParams _$BangumiOauthTokenRefreshParamsFromJson(
        Map<String, dynamic> json) =>
    BangumiOauthTokenRefreshParams(
      appId: json['client_id'] as String,
      appSecret: json['client_secret'] as String,
      refreshToken: json['refresh_token'] as String,
    )..grantType = json['grant_type'] as String;

Map<String, dynamic> _$BangumiOauthTokenRefreshParamsToJson(
        BangumiOauthTokenRefreshParams instance) =>
    <String, dynamic>{
      'grant_type': instance.grantType,
      'client_id': instance.appId,
      'client_secret': instance.appSecret,
      'refresh_token': instance.refreshToken,
    };

BangumiOauthTokenRefreshResp _$BangumiOauthTokenRefreshRespFromJson(
        Map<String, dynamic> json) =>
    BangumiOauthTokenRefreshResp(
      code: json['code'] as int,
      message: json['message'] as String,
      data: json['data'] == null
          ? null
          : BangumiOauthTokenRefreshData.fromJson(
              json['data'] as Map<String, dynamic>),
    );

BangumiOauthTokenRefreshData _$BangumiOauthTokenRefreshDataFromJson(
        Map<String, dynamic> json) =>
    BangumiOauthTokenRefreshData(
      accessToken: json['access_token'] as String,
      expiresIn: json['expires_in'] as int,
      tokenType: json['token_type'] as String,
      scope: json['scope'] as String?,
      refreshToken: json['refresh_token'] as String,
    );

Map<String, dynamic> _$BangumiOauthTokenRefreshDataToJson(
        BangumiOauthTokenRefreshData instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'expires_in': instance.expiresIn,
      'token_type': instance.tokenType,
      'scope': instance.scope,
      'refresh_token': instance.refreshToken,
    };

BangumiOauthTokenStatusResp _$BangumiOauthTokenStatusRespFromJson(
        Map<String, dynamic> json) =>
    BangumiOauthTokenStatusResp(
      code: json['code'] as int,
      message: json['message'] as String,
      data: json['data'] == null
          ? null
          : BangumiOauthTokenStatusData.fromJson(
              json['data'] as Map<String, dynamic>),
    );

BangumiOauthTokenStatusData _$BangumiOauthTokenStatusDataFromJson(
        Map<String, dynamic> json) =>
    BangumiOauthTokenStatusData(
      accessToken: json['access_token'] as String,
      clientId: json['client_id'] as String,
      expires: json['expires'] as int,
      scope: json['scope'] as String?,
      userId: json['user_id'] as int,
    );

Map<String, dynamic> _$BangumiOauthTokenStatusDataToJson(
        BangumiOauthTokenStatusData instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'client_id': instance.clientId,
      'expires': instance.expires,
      'scope': instance.scope,
      'user_id': instance.userId,
    };
