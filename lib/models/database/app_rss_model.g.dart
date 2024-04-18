// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_rss_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppRssModel _$AppRssModelFromJson(Map<String, dynamic> json) => AppRssModel(
      rss: json['rss'] as String,
      data: (json['data'] as List<dynamic>)
          .map((e) => AppRssItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      ttl: json['ttl'] as int,
      updated: json['updated'] as int? ?? 0,
    );

Map<String, dynamic> _$AppRssModelToJson(AppRssModel instance) =>
    <String, dynamic>{
      'rss': instance.rss,
      'data': instance.data.map((e) => e.toJson()).toList(),
      'ttl': instance.ttl,
      'updated': instance.updated,
    };

AppRssItemModel _$AppRssItemModelFromJson(Map<String, dynamic> json) =>
    AppRssItemModel(
      site: json['site'] as String,
      link: json['link'] as String,
      title: json['title'] as String,
      pubDate: json['pubDate'] as String,
    );

Map<String, dynamic> _$AppRssItemModelToJson(AppRssItemModel instance) =>
    <String, dynamic>{
      'site': instance.site,
      'link': instance.link,
      'title': instance.title,
      'pubDate': instance.pubDate,
    };
