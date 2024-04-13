import 'package:json_annotation/json_annotation.dart';

import '../app/response.dart';
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
