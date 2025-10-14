// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_collection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiCollectionSubjectListResp _$BangumiCollectionSubjectListRespFromJson(
  Map<String, dynamic> json,
) => BangumiCollectionSubjectListResp(
  code: (json['code'] as num).toInt(),
  message: json['message'] as String,
  data: BangumiPageT<BangumiUserSubjectCollection>.fromJson(
    json['data'] as Map<String, dynamic>,
    (value) =>
        BangumiUserSubjectCollection.fromJson(value as Map<String, dynamic>),
  ),
);

BangumiCollectionSubjectItemResp _$BangumiCollectionSubjectItemRespFromJson(
  Map<String, dynamic> json,
) => BangumiCollectionSubjectItemResp(
  code: (json['code'] as num).toInt(),
  message: json['message'] as String,
  data: BangumiUserSubjectCollection.fromJson(
    json['data'] as Map<String, dynamic>,
  ),
);

BangumiCollectionEpisodeListResp _$BangumiCollectionEpisodeListRespFromJson(
  Map<String, dynamic> json,
) => BangumiCollectionEpisodeListResp(
  code: (json['code'] as num).toInt(),
  message: json['message'] as String,
  data: BangumiPageT<BangumiUserEpisodeCollection>.fromJson(
    json['data'] as Map<String, dynamic>,
    (value) =>
        BangumiUserEpisodeCollection.fromJson(value as Map<String, dynamic>),
  ),
);

BangumiCollectionEpisodeItemResp _$BangumiCollectionEpisodeItemRespFromJson(
  Map<String, dynamic> json,
) => BangumiCollectionEpisodeItemResp(
  code: (json['code'] as num).toInt(),
  message: json['message'] as String,
  data: BangumiUserEpisodeCollection.fromJson(
    json['data'] as Map<String, dynamic>,
  ),
);
