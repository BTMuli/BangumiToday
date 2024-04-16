import 'package:json_annotation/json_annotation.dart';

import '../app/response.dart';
import 'bangumi_enum.dart';
import 'bangumi_model.dart';

/// bangumi.tv请求-条目模块的相关数据结构
/// 见：https://bangumi.github.io/api/#/条目
part 'request_subject.g.dart';

/// 获取每日放送的请求返回
@JsonSerializable(createToJson: false)
class BangumiCalendarResp extends BTResponse<List<BangumiCalendarRespData>> {
  /// constructor
  BangumiCalendarResp({
    required int code,
    required String message,
    required List<BangumiCalendarRespData> data,
  }) : super(code: code, message: message, data: data);

  /// success
  static BangumiCalendarResp success(
          {required List<BangumiCalendarRespData> data}) =>
      BangumiCalendarResp(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiCalendarResp.fromJson(Map<String, dynamic> json) =>
      _$BangumiCalendarRespFromJson(json);
}

/// 获取搜索结果的请求返回
@JsonSerializable(createToJson: false)
class BangumiSubjectSearchResp
    extends BTResponse<BangumiPageT<BangumiSubjectSearchData>> {
  /// constructor
  BangumiSubjectSearchResp({
    required int code,
    required String message,
    required BangumiPageT<BangumiSubjectSearchData> data,
  }) : super(code: code, message: message, data: data);

  /// success
  static BangumiSubjectSearchResp success(
          {required BangumiPageT<BangumiSubjectSearchData> data}) =>
      BangumiSubjectSearchResp(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiSubjectSearchResp.fromJson(Map<String, dynamic> json) =>
      _$BangumiSubjectSearchRespFromJson(json);
}

/// 获取单个条目的请求返回
@JsonSerializable(createToJson: false)
class BangumiSubjectResp extends BTResponse<BangumiSubject> {
  /// constructor
  BangumiSubjectResp({
    required int code,
    required String message,
    required BangumiSubject data,
  }) : super(code: code, message: message, data: data);

  /// success
  static BangumiSubjectResp success({required BangumiSubject data}) =>
      BangumiSubjectResp(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiSubjectResp.fromJson(Map<String, dynamic> json) =>
      _$BangumiSubjectRespFromJson(json);
}

/// 获取条目关联条目的请求返回
@JsonSerializable(createToJson: false)
class BangumiSubjectRelationsResp
    extends BTResponse<List<BangumiSubjectRelation>> {
  /// constructor
  BangumiSubjectRelationsResp({
    required int code,
    required String message,
    required List<BangumiSubjectRelation> data,
  }) : super(code: code, message: message, data: data);

  /// success
  static BangumiSubjectRelationsResp success(
          {required List<BangumiSubjectRelation> data}) =>
      BangumiSubjectRelationsResp(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiSubjectRelationsResp.fromJson(Map<String, dynamic> json) =>
      _$BangumiSubjectRelationsRespFromJson(json);
}

/// 获取每日放送返回数据
@JsonSerializable(explicitToJson: true)
class BangumiCalendarRespData {
  /// weekday
  @JsonKey(name: 'weekday')
  BangumiCalendarRespWeek weekday;

  /// items
  @JsonKey(name: 'items')
  List<BangumiLegacySubjectSmall> items;

  /// constructor
  BangumiCalendarRespData({
    required this.weekday,
    required this.items,
  });

  /// from json
  factory BangumiCalendarRespData.fromJson(Map<String, dynamic> json) =>
      _$BangumiCalendarRespDataFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiCalendarRespDataToJson(this);
}

/// 星期
@JsonSerializable()
class BangumiCalendarRespWeek {
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
  BangumiCalendarRespWeek({
    required this.en,
    required this.cn,
    required this.ja,
    required this.id,
  });

  /// from json
  factory BangumiCalendarRespWeek.fromJson(Map<String, dynamic> json) =>
      _$BangumiCalendarRespWeekFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiCalendarRespWeekToJson(this);
}

/// 获取搜索结果返回数据
@JsonSerializable(explicitToJson: true)
class BangumiSubjectSearchData {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  @JsonKey(name: 'type')
  BangumiSubjectType? type;

  /// date
  @JsonKey(name: 'date')
  String date;

  /// image
  @JsonKey(name: 'image')
  String image;

  /// summary
  @JsonKey(name: 'summary')
  String summary;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// tags
  @JsonKey(name: 'tags')
  List<BangumiTag> tags;

  /// score
  @JsonKey(name: 'score')
  double score;

  /// rank，该数据不具有实时性
  @JsonKey(name: 'rank')
  int rank;

  /// constructor
  BangumiSubjectSearchData({
    required this.id,
    required this.type,
    required this.date,
    required this.image,
    required this.summary,
    required this.name,
    required this.nameCn,
    required this.tags,
    required this.score,
    required this.rank,
  });

  /// from json
  factory BangumiSubjectSearchData.fromJson(Map<String, dynamic> json) =>
      _$BangumiSubjectSearchDataFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiSubjectSearchDataToJson(this);
}
