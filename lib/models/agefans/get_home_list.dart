import 'package:json_annotation/json_annotation.dart';

import 'age_base.dart';

part 'get_home_list.g.dart';

/// 获取首页列表
/// 参考：https://github.com/ihan123/AGE/blob/master/app/src/main/kotlin/cn/xihan/age/util/Api.kt
@JsonSerializable()
class HomeListResponse {
  /// 最新
  @JsonKey(name: 'latest')
  List<BaseBangumi> latest;

  /// 推荐
  @JsonKey(name: 'recommend')
  List<BaseBangumi> recommend;

  /// 周列表
  @JsonKey(name: 'week_list')
  Map<String, List<HomeItem>> weekList;

  /// constructor
  HomeListResponse({
    required this.latest,
    required this.recommend,
    required this.weekList,
  });

  /// from json
  factory HomeListResponse.fromJson(Map<String, dynamic> json) =>
      _$HomeListResponseFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$HomeListResponseToJson(this);
}

/// 首页列表项
@JsonSerializable()
class HomeItem {
  /// 是否是最新
  /// 0: 不是, 1: 是
  @JsonKey(name: 'isnew')
  int isNew;

  /// anime id
  @JsonKey(name: 'id')
  int id;

  /// week day
  @JsonKey(name: 'wd')
  int wd;

  /// anime title
  @JsonKey(name: 'name')
  String name;

  /// anime play time
  /// yyyy-MM-dd HH:mm:ss
  @JsonKey(name: 'mtime')
  String mTime;

  /// name for new
  @JsonKey(name: 'namefornew')
  String nameForNew;

  /// constructor
  HomeItem({
    required this.isNew,
    required this.id,
    required this.wd,
    required this.name,
    required this.mTime,
    required this.nameForNew,
  });

  /// from json
  factory HomeItem.fromJson(Map<String, dynamic> json) =>
      _$HomeItemFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$HomeItemToJson(this);
}
