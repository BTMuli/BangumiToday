import 'package:json_annotation/json_annotation.dart';

import '../app/response.dart';
import 'bangumi_model.dart';

/// 条目相关请求的数据结构
part 'request_subject.g.dart';

/// 获取每日放送的请求返回
@JsonSerializable()
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

/// 获取单个条目的请求返回
@JsonSerializable()
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

/// 获取每日放送返回数据
@JsonSerializable()
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