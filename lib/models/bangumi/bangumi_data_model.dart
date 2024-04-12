import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

import '../app/response.dart';

/// bangumi_data 相关的数据结构
part 'bangumi_data_model.g.dart';

/// bangumi-data JSON
@JsonSerializable(explicitToJson: true)
class BangumiDataJson {
  /// siteMeta 站点元数据
  @JsonKey(name: 'siteMeta')
  Map<String, BangumiDataSite> siteMeta;

  /// items 条目
  @JsonKey(name: 'items')
  List<BangumiDataItem> items;

  /// constructor
  BangumiDataJson({
    required this.siteMeta,
    required this.items,
  });

  /// from json
  factory BangumiDataJson.fromJson(Map<String, dynamic> json) =>
      _$BangumiDataJsonFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiDataJsonToJson(this);
}

/// bangumi-data站点元数据
@JsonSerializable()
class BangumiDataSite {
  /// title 站点标题
  @JsonKey(name: 'title')
  String title;

  /// urlTemplate 站点 URL 模板
  /// 诸如 https://bgm.tv/subject/{id}
  @JsonKey(name: 'urlTemplate')
  String urlTemplate;

  /// type 站点类型
  /// info 表示咨讯站，onair 表示放送站
  @JsonKey(name: 'type')
  String type;

  /// regions 地区
  @JsonKey(name: 'regions')
  List<String>? regions;

  /// constructor
  BangumiDataSite({
    required this.title,
    required this.urlTemplate,
    required this.type,
    required this.regions,
  });

  /// fromJson
  factory BangumiDataSite.fromJson(Map<String, dynamic> json) =>
      _$BangumiDataSiteFromJson(json);

  /// toJson
  Map<String, dynamic> toJson() => _$BangumiDataSiteToJson(this);
}

/// bangumi-data条目
@JsonSerializable(explicitToJson: true)
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

/// 补充：站点元数据，用于存到数据库
@JsonSerializable()
class BangumiDataSiteFull extends BangumiDataSite {
  /// key 站点键
  @JsonKey(name: 'key')
  String key;

  /// constructor
  BangumiDataSiteFull({
    required this.key,
    required String title,
    required String urlTemplate,
    required String type,
    required List<String>? regions,
  }) : super(
          title: title,
          urlTemplate: urlTemplate,
          type: type,
          regions: regions,
        );

  /// from json
  factory BangumiDataSiteFull.fromJson(Map<String, dynamic> json) =>
      _$BangumiDataSiteFullFromJson(json);

  /// from site
  factory BangumiDataSiteFull.fromSite(String key, BangumiDataSite site) =>
      BangumiDataSiteFull(
        key: key,
        title: site.title,
        urlTemplate: site.urlTemplate,
        type: site.type,
        regions: site.regions,
      );

  /// to json
  Map<String, dynamic> toJson() => _$BangumiDataSiteFullToJson(this);

  /// to sql json
  Map<String, dynamic> toSqlJson() => {
        'key': key,
        'title': title,
        'urlTemplate': urlTemplate,
        'type': type,
        'regions': regions.toString(),
      };
}

/// 补充：返回数据，用于处理返回数据
@JsonSerializable(createToJson: false)
class BangumiDataResp extends BTResponse<BangumiDataJson> {
  /// constructor
  BangumiDataResp({
    required int code,
    required String message,
    required BangumiDataJson data,
  }) : super(code: code, message: message, data: data);

  /// success
  static BangumiDataResp success({required BangumiDataJson data}) =>
      BangumiDataResp(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiDataResp.fromJson(Map<String, dynamic> json) =>
      _$BangumiDataRespFromJson(json);
}
