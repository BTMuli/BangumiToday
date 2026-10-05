// Package imports:
import 'package:json_annotation/json_annotation.dart';

part 'app_rss_cache_model.g.dart';

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
