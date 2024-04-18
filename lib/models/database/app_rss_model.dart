import 'dart:convert';

import 'package:dart_rss/dart_rss.dart';
import 'package:json_annotation/json_annotation.dart';

/// AppRss 表的数据模型
/// 该表在 lib/database/app/app_rss.dart 中定义
part 'app_rss_model.g.dart';

/// AppRss 表的数据模型
@JsonSerializable(explicitToJson: true)
class AppRssModel {
  /// RSS URL
  final String rss;

  /// RSS 数据
  List<AppRssItemModel> data;

  /// ttl
  int ttl;

  /// updated
  late int updated;

  /// 构造函数
  AppRssModel({
    required this.rss,
    required this.data,
    required this.ttl,
    this.updated = 0,
  });

  /// JSON 序列化
  factory AppRssModel.fromJson(Map<String, dynamic> json) =>
      _$AppRssModelFromJson(json);

  /// fromRssList
  factory AppRssModel.fromRssFeed(String rss, RssFeed feed) {
    var data = feed.items
        .map(
          (e) => AppRssItemModel.fromRssItem(rss, e),
        )
        .toList();
    return AppRssModel(
      rss: rss,
      data: data,
      ttl: feed.ttl,
    );
  }

  /// fromSqlJson 用于从数据库读取
  factory AppRssModel.fromSqlJson(Map<String, dynamic> json) {
    var list = (jsonDecode(json['data']) as List<dynamic>)
        .map((e) => AppRssItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return AppRssModel(
      rss: json['rss'],
      data: list,
      ttl: json['ttl'],
      updated: json['updated'],
    );
  }

  /// JSON 反序列化
  Map<String, dynamic> toJson() => _$AppRssModelToJson(this);

  /// toSqlJson 用于存储到数据库
  Map<String, dynamic> toSqlJson() {
    return {
      'rss': rss,
      'data': jsonEncode(data.map((e) => e.toJson()).toList()),
      'ttl': ttl,
      'updated': updated,
    };
  }
}

/// AppRssItem
/// 由于 rss 数据的不确定性，这里只存储站点链接、资源链接、标题、发布时间
/// 数据比较通过资源链接来判断
@JsonSerializable()
class AppRssItemModel {
  /// 站点链接
  final String site;

  /// 资源链接
  final String link;

  /// 标题
  final String title;

  /// 发布时间
  final String pubDate;

  /// 构造函数
  AppRssItemModel({
    required this.site,
    required this.link,
    required this.title,
    required this.pubDate,
  });

  /// JSON 序列化
  factory AppRssItemModel.fromJson(Map<String, dynamic> json) =>
      _$AppRssItemModelFromJson(json);

  /// from RssItem
  factory AppRssItemModel.fromRssItem(String site, RssItem item) {
    return AppRssItemModel(
      site: item.link!,
      link: item.enclosure!.url!,
      title: item.title!,
      pubDate: item.pubDate!,
    );
  }

  /// JSON 反序列化
  Map<String, dynamic> toJson() => _$AppRssItemModelToJson(this);
}
