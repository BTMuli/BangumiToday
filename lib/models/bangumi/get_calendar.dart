import 'package:json_annotation/json_annotation.dart';

import 'common_model.dart';

part 'get_calendar.g.dart';

/// 获取每日放送
/// 详细文档请参考 https://bangumi.github.io/api/
/// get => https://api.bgm.tv/calendar
@JsonSerializable()
class CalendarItem {
  /// weekday
  @JsonKey(name: 'weekday')
  CalendarItemWeekday weekday;

  /// items
  @JsonKey(name: 'items')
  List<CalendarItemBangumi> items;

  /// constructor
  CalendarItem({
    required this.weekday,
    required this.items,
  });

  /// from json
  factory CalendarItem.fromJson(Map<String, dynamic> json) =>
      _$CalendarItemFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$CalendarItemToJson(this);
}

/// 星期
@JsonSerializable()
class CalendarItemWeekday {
  /// en
  @JsonKey(name: 'en')
  String en;

  /// cn
  @JsonKey(name: 'cn')
  String cn;

  /// ja
  @JsonKey(name: 'ja')
  String ja;

  /// id
  @JsonKey(name: 'id')
  int id;

  /// constructor
  CalendarItemWeekday({
    required this.en,
    required this.cn,
    required this.ja,
    required this.id,
  });

  /// from json
  factory CalendarItemWeekday.fromJson(Map<String, dynamic> json) =>
      _$CalendarItemWeekdayFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$CalendarItemWeekdayToJson(this);
}

/// 番剧信息
@JsonSerializable()
class CalendarItemBangumi {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// url
  @JsonKey(name: 'url')
  String url;

  /// type
  /// 1为书籍，2为动画，3为音乐
  /// 4为游戏，6为三次元
  @JsonKey(name: 'type')
  int type;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// summary
  @JsonKey(name: 'summary')
  String summary;

  /// air_date
  @JsonKey(name: 'air_date')
  String airDate;

  /// air_weekday
  @JsonKey(name: 'air_weekday')
  int airWeekday;

  /// images
  @JsonKey(name: 'images')
  BangumiImage? images;

  /// eps
  @JsonKey(name: 'eps')
  int? eps;

  /// eps_count
  @JsonKey(name: 'eps_count')
  int? epsCount;

  /// rating
  @JsonKey(name: 'rating')
  BangumiRating? rating;

  /// rank
  @JsonKey(name: 'rank')
  int? rank;

  /// collection，可能为null
  @JsonKey(name: 'collection')
  BangumiCollection? collection;

  /// constructor
  CalendarItemBangumi({
    required this.id,
    required this.url,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.airDate,
    required this.airWeekday,
    required this.images,
    required this.eps,
    required this.epsCount,
    required this.rating,
    required this.rank,
    required this.collection,
  });

  /// from json
  factory CalendarItemBangumi.fromJson(Map<String, dynamic> json) =>
      _$CalendarItemBangumiFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$CalendarItemBangumiToJson(this);
}
