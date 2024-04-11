// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oauth.dart';

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

BangumiTokenGParams _$BangumiTokenGParamsFromJson(Map<String, dynamic> json) =>
    BangumiTokenGParams(
      appId: json['client_id'] as String,
      appSecret: json['client_secret'] as String,
      code: json['code'] as String,
      state: json['state'] as String?,
    )
      ..grantType = json['grant_type'] as String
      ..redirectUri = json['redirect_uri'] as String;

Map<String, dynamic> _$BangumiTokenGParamsToJson(
        BangumiTokenGParams instance) =>
    <String, dynamic>{
      'grant_type': instance.grantType,
      'client_id': instance.appId,
      'client_secret': instance.appSecret,
      'code': instance.code,
      'redirect_uri': instance.redirectUri,
      'state': instance.state,
    };

BangumiTokenRParams _$BangumiTokenRParamsFromJson(Map<String, dynamic> json) =>
    BangumiTokenRParams(
      appId: json['client_id'] as String,
      appSecret: json['client_secret'] as String,
      refreshToken: json['refresh_token'] as String,
    )..grantType = json['grant_type'] as String;

Map<String, dynamic> _$BangumiTokenRParamsToJson(
        BangumiTokenRParams instance) =>
    <String, dynamic>{
      'grant_type': instance.grantType,
      'client_id': instance.appId,
      'client_secret': instance.appSecret,
      'refresh_token': instance.refreshToken,
    };

BangumiTatResponse _$BangumiTatResponseFromJson(Map<String, dynamic> json) =>
    BangumiTatResponse(
      code: json['code'] as int,
      message: json['message'] as String,
      data: json['data'] == null
          ? null
          : BangumiTatRespData.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BangumiTatResponseToJson(BangumiTatResponse instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'data': instance.data,
    };

BangumiTatRespData _$BangumiTatRespDataFromJson(Map<String, dynamic> json) =>
    BangumiTatRespData(
      accessToken: json['access_token'] as String,
      expiresIn: json['expires_in'] as int,
      tokenType: json['token_type'] as String,
      scope: json['scope'] as String?,
      refreshToken: json['refresh_token'] as String,
      userId: json['user_id'] as int,
    );

Map<String, dynamic> _$BangumiTatRespDataToJson(BangumiTatRespData instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'expires_in': instance.expiresIn,
      'token_type': instance.tokenType,
      'scope': instance.scope,
      'refresh_token': instance.refreshToken,
      'user_id': instance.userId,
    };

BangumiRtResponse _$BangumiRtResponseFromJson(Map<String, dynamic> json) =>
    BangumiRtResponse(
      code: json['code'] as int,
      message: json['message'] as String,
      data: json['data'] == null
          ? null
          : BangumiRtRespData.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BangumiRtResponseToJson(BangumiRtResponse instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'data': instance.data,
    };

BangumiRtRespData _$BangumiRtRespDataFromJson(Map<String, dynamic> json) =>
    BangumiRtRespData(
      accessToken: json['access_token'] as String,
      expiresIn: json['expires_in'] as int,
      tokenType: json['token_type'] as String,
      scope: json['scope'] as String?,
      refreshToken: json['refresh_token'] as String,
    );

Map<String, dynamic> _$BangumiRtRespDataToJson(BangumiRtRespData instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'expires_in': instance.expiresIn,
      'token_type': instance.tokenType,
      'scope': instance.scope,
      'refresh_token': instance.refreshToken,
    };

BangumiTstResponse _$BangumiTstResponseFromJson(Map<String, dynamic> json) =>
    BangumiTstResponse(
      code: json['code'] as int,
      message: json['message'] as String,
      data: json['data'] == null
          ? null
          : BangumiTstrData.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BangumiTstResponseToJson(BangumiTstResponse instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'data': instance.data,
    };

BangumiTstrData _$BangumiTstrDataFromJson(Map<String, dynamic> json) =>
    BangumiTstrData(
      accessToken: json['access_token'] as String,
      clientId: json['client_id'] as String,
      expires: json['expires'] as int,
      scope: json['scope'] as String?,
      userId: json['user_id'] as int,
    );

Map<String, dynamic> _$BangumiTstrDataToJson(BangumiTstrData instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'client_id': instance.clientId,
      'expires': instance.expires,
      'scope': instance.scope,
      'user_id': instance.userId,
    };
