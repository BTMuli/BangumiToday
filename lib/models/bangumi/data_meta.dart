import 'package:json_annotation/json_annotation.dart';

import 'data_item.dart';

part 'data_meta.g.dart';

/// bangumi-data获取到的 JSON 数据
@JsonSerializable()
class BangumiData {
  /// siteMeta 站点元数据
  @JsonKey(name: 'siteMeta')
  Map<String, BangumiDataSite> siteMeta;

  /// items 条目
  @JsonKey(name: 'items')
  List<BangumiDataItem> items;

  /// constructor
  BangumiData({
    required this.siteMeta,
    required this.items,
  });

  /// fromJson
  factory BangumiData.fromJson(Map<String, dynamic> json) =>
      _$BangumiDataFromJson(json);

  /// toJson
  Map<String, dynamic> toJson() => _$BangumiDataToJson(this);
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

/// bangumi-data站点元数据（完整）
@JsonSerializable()
class BangumiDataSiteFull {
  /// key 站点键
  @JsonKey(name: 'key')
  String key;

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
  BangumiDataSiteFull({
    required this.key,
    required this.title,
    required this.urlTemplate,
    required this.type,
    required this.regions,
  });

  /// fromJson
  factory BangumiDataSiteFull.fromJson(Map<String, dynamic> json) =>
      _$BangumiDataSiteFullFromJson(json);

  /// fromSite
  factory BangumiDataSiteFull.fromSite(String key, BangumiDataSite site) =>
      BangumiDataSiteFull(
        key: key,
        title: site.title,
        urlTemplate: site.urlTemplate,
        type: site.type,
        regions: site.regions,
      );

  /// toJson
  Map<String, dynamic> toJson() => _$BangumiDataSiteFullToJson(this);

  /// toSqlJson
  Map<String, dynamic> toSqlJson() => {
        'key': key,
        'title': title,
        'urlTemplate': urlTemplate,
        'type': type,
        'regions': regions.toString(),
      };
}
