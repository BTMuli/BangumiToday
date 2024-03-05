import 'package:json_annotation/json_annotation.dart';

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

/// 番剧图片
@JsonSerializable()
class CalendarItemBangumiImages {
  /// large
  @JsonKey(name: 'large')
  String large;

  /// common
  @JsonKey(name: 'common')
  String common;

  /// medium
  @JsonKey(name: 'medium')
  String medium;

  /// small
  @JsonKey(name: 'small')
  String small;

  /// grid
  @JsonKey(name: 'grid')
  String grid;

  /// constructor
  CalendarItemBangumiImages({
    required this.large,
    required this.common,
    required this.medium,
    required this.small,
    required this.grid,
  });

  /// from json
  factory CalendarItemBangumiImages.fromJson(Map<String, dynamic> json) =>
      _$CalendarItemBangumiImagesFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$CalendarItemBangumiImagesToJson(this);
}

/// 番剧评分
@JsonSerializable()
class CalendarItemBangumiRating {
  /// total
  @JsonKey(name: 'total')
  int total;

  /// count
  @JsonKey(name: 'count')
  Map<String, int> count;

  /// score
  @JsonKey(name: 'score')
  double score;

  /// constructor
  CalendarItemBangumiRating({
    required this.total,
    required this.count,
    required this.score,
  });

  /// from json
  factory CalendarItemBangumiRating.fromJson(Map<String, dynamic> json) =>
      _$CalendarItemBangumiRatingFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$CalendarItemBangumiRatingToJson(this);
}

/// 番剧收藏
@JsonSerializable()
class CalendarItemBangumiCollection {
  /// wish
  @JsonKey(name: 'wish')
  int? wish;

  /// collect
  @JsonKey(name: 'collect')
  int? collect;

  /// doing
  @JsonKey(name: 'doing')
  int? doing;

  /// on_hold
  @JsonKey(name: 'on_hold')
  int? onHold;

  /// dropped
  @JsonKey(name: 'dropped')
  int? dropped;

  /// constructor
  CalendarItemBangumiCollection({
    required this.wish,
    required this.collect,
    required this.doing,
    required this.onHold,
    required this.dropped,
  });

  /// from json
  factory CalendarItemBangumiCollection.fromJson(Map<String, dynamic> json) =>
      _$CalendarItemBangumiCollectionFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$CalendarItemBangumiCollectionToJson(this);
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
  CalendarItemBangumiImages? images;

  /// eps
  @JsonKey(name: 'eps')
  int? eps;

  /// eps_count
  @JsonKey(name: 'eps_count')
  int? epsCount;

  /// rating
  @JsonKey(name: 'rating')
  CalendarItemBangumiRating? rating;

  /// rank
  @JsonKey(name: 'rank')
  int? rank;

  /// collection，可能为null
  @JsonKey(name: 'collection')
  CalendarItemBangumiCollection? collection;

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
