// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiUserInfoResp _$BangumiUserInfoRespFromJson(Map<String, dynamic> json) =>
    BangumiUserInfoResp(
      code: json['code'] as int,
      message: json['message'] as String,
      data: BangumiUser.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BangumiUserInfoRespToJson(
        BangumiUserInfoResp instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'data': instance.data,
    };
