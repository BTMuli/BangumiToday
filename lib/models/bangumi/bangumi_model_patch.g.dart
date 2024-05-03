// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_model_patch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiPatchRating _$BangumiPatchRatingFromJson(Map<String, dynamic> json) =>
    BangumiPatchRating(
      total: (json['total'] as num).toInt(),
      count: Map<String, int>.from(json['count'] as Map),
      score: (json['score'] as num).toDouble(),
      rank: (json['rank'] as num?)?.toInt(),
    );

Map<String, dynamic> _$BangumiPatchRatingToJson(BangumiPatchRating instance) =>
    <String, dynamic>{
      'total': instance.total,
      'count': instance.count,
      'score': instance.score,
      'rank': instance.rank,
    };

BangumiPatchCollection _$BangumiPatchCollectionFromJson(
        Map<String, dynamic> json) =>
    BangumiPatchCollection(
      wish: (json['wish'] as num?)?.toInt(),
      collect: (json['collect'] as num?)?.toInt(),
      doing: (json['doing'] as num?)?.toInt(),
      onHold: (json['on_hold'] as num?)?.toInt(),
      dropped: (json['dropped'] as num?)?.toInt(),
    );

Map<String, dynamic> _$BangumiPatchCollectionToJson(
        BangumiPatchCollection instance) =>
    <String, dynamic>{
      'wish': instance.wish,
      'collect': instance.collect,
      'doing': instance.doing,
      'on_hold': instance.onHold,
      'dropped': instance.dropped,
    };
