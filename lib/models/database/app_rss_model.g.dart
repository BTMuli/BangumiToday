// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_rss_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppRssModel _$AppRssModelFromJson(Map<String, dynamic> json) => AppRssModel(
  rss: json['rss'] as String,
  data: json['data'] as String,
  ttl: (json['ttl'] as num).toInt(),
  updated: (json['updated'] as num?)?.toInt() ?? 0,
  mkBgmId: json['mkBgmId'] as String?,
  mkGroupId: json['mkGroupId'] as String?,
);

Map<String, dynamic> _$AppRssModelToJson(AppRssModel instance) =>
    <String, dynamic>{
      'rss': instance.rss,
      'mkBgmId': instance.mkBgmId,
      'mkGroupId': instance.mkGroupId,
      'data': instance.data,
      'ttl': instance.ttl,
      'updated': instance.updated,
    };
