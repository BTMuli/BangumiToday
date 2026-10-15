// Package imports:
import 'package:json_annotation/json_annotation.dart';

part 'app_rss_cache_model.g.dart';

/// 刷新调度只读取时间与缓存可用性，避免每分钟传输全部 XML。
class AppRssCacheMetadata {
  const AppRssCacheMetadata({
    required this.hasData,
    required this.lastSuccessAt,
    required this.lastFailedAt,
    required this.cacheVersion,
  });

  final bool hasData;
  final int lastSuccessAt;
  final int lastFailedAt;
  final int cacheVersion;
}

@JsonSerializable()
class AppRssCacheModel {
  const AppRssCacheModel({
    required this.feedKey,
    required this.requestUrl,
    this.data,
    this.ttlMinutes = 0,
    this.lastSuccessAt = 0,
    this.lastAttemptAt = 0,
    this.lastFailedAt = 0,
    this.cacheVersion = 1,
  });

  static const currentCacheVersion = 1;
  final String feedKey;
  final String requestUrl;
  final String? data;
  final int ttlMinutes;
  final int lastSuccessAt;
  final int lastAttemptAt;
  final int lastFailedAt;
  final int cacheVersion;

  factory AppRssCacheModel.fromJson(Map<String, dynamic> json) =>
      _$AppRssCacheModelFromJson(json);
  Map<String, dynamic> toJson() => _$AppRssCacheModelToJson(this);
}
