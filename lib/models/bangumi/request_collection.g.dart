// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_collection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiCollectionListResp _$BangumiCollectionListRespFromJson(
        Map<String, dynamic> json) =>
    BangumiCollectionListResp(
      code: json['code'] as int,
      message: json['message'] as String,
      data: BangumiPageT<BangumiUserSubjectCollection>.fromJson(
          json['data'] as Map<String, dynamic>,
          (value) => BangumiUserSubjectCollection.fromJson(
              value as Map<String, dynamic>)),
    );

BangumiCollectionItemResp _$BangumiCollectionItemRespFromJson(
        Map<String, dynamic> json) =>
    BangumiCollectionItemResp(
      code: json['code'] as int,
      message: json['message'] as String,
      data: BangumiUserSubjectCollection.fromJson(
          json['data'] as Map<String, dynamic>),
    );
