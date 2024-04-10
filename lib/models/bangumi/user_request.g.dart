// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiUserInfoResponse _$BangumiUserInfoResponseFromJson(
        Map<String, dynamic> json) =>
    BangumiUserInfoResponse(
      code: json['code'] as int,
      message: json['message'] as String,
      data: json['data'] == null
          ? null
          : BangumiUserInfo.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BangumiUserInfoResponseToJson(
        BangumiUserInfoResponse instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'data': instance.data,
    };

BangumiUserInfo _$BangumiUserInfoFromJson(Map<String, dynamic> json) =>
    BangumiUserInfo(
      avatar:
          BangumiUserAvatar.fromJson(json['avatar'] as Map<String, dynamic>),
      sign: json['sign'] as String,
      username: json['username'] as String,
      nickname: json['nickname'] as String,
      id: json['id'] as int,
      userGroup: json['user_group'] as int,
    );

Map<String, dynamic> _$BangumiUserInfoToJson(BangumiUserInfo instance) =>
    <String, dynamic>{
      'avatar': instance.avatar,
      'sign': instance.sign,
      'username': instance.username,
      'nickname': instance.nickname,
      'id': instance.id,
      'user_group': instance.userGroup,
    };

BangumiUserAvatar _$BangumiUserAvatarFromJson(Map<String, dynamic> json) =>
    BangumiUserAvatar(
      large: json['large'] as String,
      medium: json['medium'] as String,
      small: json['small'] as String,
    );

Map<String, dynamic> _$BangumiUserAvatarToJson(BangumiUserAvatar instance) =>
    <String, dynamic>{
      'large': instance.large,
      'medium': instance.medium,
      'small': instance.small,
    };
