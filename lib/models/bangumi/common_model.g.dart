// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'common_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiImage _$BangumiImageFromJson(Map<String, dynamic> json) => BangumiImage(
      large: json['large'] as String,
      common: json['common'] as String,
      medium: json['medium'] as String,
      small: json['small'] as String,
      grid: json['grid'] as String,
    );

Map<String, dynamic> _$BangumiImageToJson(BangumiImage instance) =>
    <String, dynamic>{
      'large': instance.large,
      'common': instance.common,
      'medium': instance.medium,
      'small': instance.small,
      'grid': instance.grid,
    };

BangumiRating _$BangumiRatingFromJson(Map<String, dynamic> json) =>
    BangumiRating(
      total: json['total'] as int,
      count: Map<String, int>.from(json['count'] as Map),
      score: (json['score'] as num).toDouble(),
    );

Map<String, dynamic> _$BangumiRatingToJson(BangumiRating instance) =>
    <String, dynamic>{
      'total': instance.total,
      'count': instance.count,
      'score': instance.score,
    };

BangumiCollection _$BangumiCollectionFromJson(Map<String, dynamic> json) =>
    BangumiCollection(
      wish: json['wish'] as int?,
      collect: json['collect'] as int?,
      doing: json['doing'] as int?,
      onHold: json['on_hold'] as int?,
      dropped: json['dropped'] as int?,
    );

Map<String, dynamic> _$BangumiCollectionToJson(BangumiCollection instance) =>
    <String, dynamic>{
      'wish': instance.wish,
      'collect': instance.collect,
      'doing': instance.doing,
      'on_hold': instance.onHold,
      'dropped': instance.dropped,
    };
