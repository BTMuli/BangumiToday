// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_search.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiSearchListResp _$BangumiSearchListRespFromJson(
  Map<String, dynamic> json,
) => BangumiSearchListResp(
  code: (json['code'] as num).toInt(),
  message: json['message'] as String,
  data: BangumiSearchListData.fromJson(json['data'] as Map<String, dynamic>),
);

BangumiSearchListData _$BangumiSearchListDataFromJson(
  Map<String, dynamic> json,
) => BangumiSearchListData(
  results: (json['results'] as num).toInt(),
  list: (json['list'] as List<dynamic>)
      .map((e) => BangumiLegacySubjectSmall.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$BangumiSearchListDataToJson(
  BangumiSearchListData instance,
) => <String, dynamic>{'results': instance.results, 'list': instance.list};
