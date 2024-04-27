// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import '../app/response.dart';
import 'bangumi_model.dart';

/// bangumi.tv 请求-搜索模块的相关数据结构
/// 见：https://bangumi.github.io/api/#/搜索
/// 由于返回内容无限制，应用实际使用的是另一个接口，这里仅作为参考
part 'request_search.g.dart';

/// 获取搜索结果请求返回
@JsonSerializable(createToJson: false)
class BangumiSearchListResp extends BTResponse<BangumiSearchListData> {
  /// constructor
  BangumiSearchListResp({
    required super.code,
    required super.message,
    required BangumiSearchListData super.data,
  });

  /// success
  static BangumiSearchListResp success({required BangumiSearchListData data}) =>
      BangumiSearchListResp(code: 0, message: 'success', data: data);

  /// from json
  factory BangumiSearchListResp.fromJson(Map<String, dynamic> json) =>
      _$BangumiSearchListRespFromJson(json);
}

/// 搜索结果数据
/// 返回总条数 [results] 及结果 [list]
/// 结果列表数据结构可能是 [BangumiLegacySubject(Small|Medium|Large)]
/// 为了方便处理，这里使用 [BangumiLegacySubjectSmall]
@JsonSerializable()
class BangumiSearchListData {
  /// 总条数
  final int results;

  /// 结果列表
  final List<BangumiLegacySubjectSmall> list;

  /// constructor
  BangumiSearchListData({required this.results, required this.list});

  /// from json
  factory BangumiSearchListData.fromJson(Map<String, dynamic> json) =>
      _$BangumiSearchListDataFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiSearchListDataToJson(this);
}
