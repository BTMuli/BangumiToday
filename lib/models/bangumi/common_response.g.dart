// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'common_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiErrResponse _$BangumiErrResponseFromJson(Map<String, dynamic> json) =>
    BangumiErrResponse(
      title: json['title'] as String,
      description: json['description'] as String,
      details: json['details'] as String,
    );

Map<String, dynamic> _$BangumiErrResponseToJson(BangumiErrResponse instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'details': instance.details,
    };
