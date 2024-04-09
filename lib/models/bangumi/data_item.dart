import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'data_item.g.dart';

/// bangumi-data条目
@JsonSerializable()
class BangumiDataItem {
  /// title 日文标题
  @JsonKey(name: 'title')
  String title;

  /// titleTranslate 翻译后的标题
  @JsonKey(name: 'titleTranslate')
  BangumiDataItemTitleTranslate titleTranslate;

  /// type 类型
  @JsonKey(name: 'type')
  String type;

  /// lang 语言
  @JsonKey(name: 'lang')
  String lang;

  /// officialSite 官方网站
  @JsonKey(name: 'officialSite')
  String officialSite;

  /// begin 开始时间
  /// 格式 yyyy-MM-ddTHH:mm:ss.SSSZ
  @JsonKey(name: 'begin')
  String begin;

  /// broadcast 周期
  @JsonKey(name: 'broadcast')
  String? broadcast;

  /// end 结束时间
  /// 格式 yyyy-MM-ddTHH:mm:ss.SSSZ
  @JsonKey(name: 'end')
  String end;

  /// comment 评论
  @JsonKey(name: 'comment')
  String? comment;

  /// sites 站点
  /// 需要搭配 BangumiDataMeta 使用
  @JsonKey(name: 'sites')
  List<BangumiDataItemSite> sites;

  /// constructor
  BangumiDataItem({
    required this.title,
    required this.titleTranslate,
    required this.type,
    required this.lang,
    required this.officialSite,
    required this.begin,
    required this.broadcast,
    required this.end,
    required this.comment,
    required this.sites,
  });

  /// from json
  factory BangumiDataItem.fromJson(Map<String, dynamic> json) =>
      _$BangumiDataItemFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiDataItemToJson(this);

  /// toSqlJson
  Map<String, dynamic> toSqlJson() => {
        'title': title,
        'titleTranslate': jsonEncode(titleTranslate.toJson()),
        'type': type,
        'lang': lang,
        'officialSite': officialSite,
        'begin': begin,
        'broadcast': broadcast,
        'end': end,
        'comment': comment,
        'sites': jsonEncode(sites.map((e) => e.toJson()).toList()),
      };

  /// fromSqlJson
  factory BangumiDataItem.fromSqlJson(Map<String, dynamic> json) {
    var titleTranslate = BangumiDataItemTitleTranslate.fromJson(
        jsonDecode(json['titleTranslate']) as Map<String, dynamic>);
    var sites = (jsonDecode(json['sites']) as List<dynamic>)
        .map((e) => BangumiDataItemSite.fromJson(e as Map<String, dynamic>))
        .toList();
    return BangumiDataItem(
      title: json['title'],
      titleTranslate: titleTranslate,
      type: json['type'],
      lang: json['lang'],
      officialSite: json['officialSite'],
      begin: json['begin'],
      broadcast: json['broadcast'],
      end: json['end'],
      comment: json['comment'],
      sites: sites,
    );
  }
}

/// bangumi-data条目标题翻译
@JsonSerializable()
class BangumiDataItemTitleTranslate {
  /// zh 中文
  @JsonKey(name: 'zh-Hans')
  List<String>? zh;

  /// constructor
  BangumiDataItemTitleTranslate({
    required this.zh,
  });

  /// from json
  factory BangumiDataItemTitleTranslate.fromJson(Map<String, dynamic> json) =>
      _$BangumiDataItemTitleTranslateFromJson(json);

  /// from sql json
  factory BangumiDataItemTitleTranslate.fromSqlJson(String json) {
    var map = jsonDecode(json);
    return BangumiDataItemTitleTranslate.fromJson(map);
  }

  /// to json
  Map<String, dynamic> toJson() => _$BangumiDataItemTitleTranslateToJson(this);
}

/// bangumi-data条目站点
@JsonSerializable()
class BangumiDataItemSite {
  /// name 站点名称
  @JsonKey(name: 'site')
  String site;

  /// id 站点ID
  @JsonKey(name: 'id')
  String? id;

  /// begin 开始时间
  /// 格式 yyyy-MM-ddTHH:mm:ss.SSSZ
  @JsonKey(name: 'begin')
  String? begin;

  /// broadcast 周期
  @JsonKey(name: 'broadcast')
  String? broadcast;

  /// constructor
  BangumiDataItemSite({
    required this.site,
    required this.id,
    required this.begin,
    required this.broadcast,
  });

  /// from json
  factory BangumiDataItemSite.fromJson(Map<String, dynamic> json) =>
      _$BangumiDataItemSiteFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiDataItemSiteToJson(this);
}
