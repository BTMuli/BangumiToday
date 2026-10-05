// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_rss_cache_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppRssCacheModel _$AppRssCacheModelFromJson(Map<String, dynamic> json) =>
    AppRssCacheModel(
      feedKey: json['feedKey'] as String,
      requestUrl: json['requestUrl'] as String,
      data: json['data'] as String?,
      ttlMinutes: (json['ttlMinutes'] as num?)?.toInt() ?? 0,
      lastSuccessAt: (json['lastSuccessAt'] as num?)?.toInt() ?? 0,
      lastAttemptAt: (json['lastAttemptAt'] as num?)?.toInt() ?? 0,
      lastFailedAt: (json['lastFailedAt'] as num?)?.toInt() ?? 0,
      cacheVersion: (json['cacheVersion'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$AppRssCacheModelToJson(AppRssCacheModel instance) =>
    <String, dynamic>{
      'feedKey': instance.feedKey,
      'requestUrl': instance.requestUrl,
      'data': instance.data,
      'ttlMinutes': instance.ttlMinutes,
      'lastSuccessAt': instance.lastSuccessAt,
      'lastAttemptAt': instance.lastAttemptAt,
      'lastFailedAt': instance.lastFailedAt,
      'cacheVersion': instance.cacheVersion,
    };
