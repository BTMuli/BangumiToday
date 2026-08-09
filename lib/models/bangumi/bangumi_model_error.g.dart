// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_model_error.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiErrorDetail _$BangumiErrorDetailFromJson(Map<String, dynamic> json) =>
    BangumiErrorDetail(
      title: json['title'] as String,
      description: json['description'] as String,
      details: json['details'],
      requestId: json['request_id'] as String,
    );

Map<String, dynamic> _$BangumiErrorDetailToJson(BangumiErrorDetail instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'details': instance.details,
      'request_id': instance.requestId,
    };

BangumiErrorOauth _$BangumiErrorOauthFromJson(Map<String, dynamic> json) =>
    BangumiErrorOauth(
      error: json['error'] as String,
      errorDescription: json['error_description'] as String,
    );

Map<String, dynamic> _$BangumiErrorOauthToJson(BangumiErrorOauth instance) =>
    <String, dynamic>{
      'error': instance.error,
      'error_description': instance.errorDescription,
    };
