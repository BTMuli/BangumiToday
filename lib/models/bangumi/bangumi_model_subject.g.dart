// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_model_subject.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiSubject _$BangumiSubjectFromJson(Map<String, dynamic> json) =>
    BangumiSubject(
      id: (json['id'] as num).toInt(),
      type: $enumDecode(_$BangumiSubjectTypeEnumMap, json['type']),
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      summary: json['summary'] as String,
      nsfw: json['nsfw'] as bool,
      locked: json['locked'] as bool,
      date: json['date'] as String?,
      platform: json['platform'] as String,
      images: BangumiImages.fromJson(json['images'] as Map<String, dynamic>),
      infobox: (json['infobox'] as List<dynamic>)
          .map((e) => BangumiInfoBoxItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      volumes: (json['volumes'] as num).toInt(),
      eps: (json['eps'] as num).toInt(),
      totalEpisodes: (json['total_episodes'] as num).toInt(),
      rating: BangumiPatchRating.fromJson(
        json['rating'] as Map<String, dynamic>,
      ),
      collection: BangumiPatchCollection.fromJson(
        json['collection'] as Map<String, dynamic>,
      ),
      tags: (json['tags'] as List<dynamic>)
          .map((e) => BangumiTag.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BangumiSubjectToJson(BangumiSubject instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$BangumiSubjectTypeEnumMap[instance.type]!,
      'name': instance.name,
      'name_cn': instance.nameCn,
      'summary': instance.summary,
      'nsfw': instance.nsfw,
      'locked': instance.locked,
      'date': instance.date,
      'platform': instance.platform,
      'images': instance.images.toJson(),
      'infobox': instance.infobox.map((e) => e.toJson()).toList(),
      'volumes': instance.volumes,
      'eps': instance.eps,
      'total_episodes': instance.totalEpisodes,
      'rating': instance.rating.toJson(),
      'collection': instance.collection.toJson(),
      'tags': instance.tags.map((e) => e.toJson()).toList(),
    };

BangumiSlimSubject _$BangumiSlimSubjectFromJson(Map<String, dynamic> json) =>
    BangumiSlimSubject(
      id: (json['id'] as num).toInt(),
      type: $enumDecode(_$BangumiSubjectTypeEnumMap, json['type']),
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      shortSummary: json['short_summary'] as String,
      date: json['date'] as String?,
      images: BangumiImages.fromJson(json['images'] as Map<String, dynamic>),
      volumes: (json['volumes'] as num).toInt(),
      eps: (json['eps'] as num).toInt(),
      collectionTotal: (json['collection_total'] as num).toInt(),
      score: (json['score'] as num).toDouble(),
      tags: (json['tags'] as List<dynamic>)
          .map((e) => BangumiTag.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BangumiSlimSubjectToJson(BangumiSlimSubject instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$BangumiSubjectTypeEnumMap[instance.type]!,
      'name': instance.name,
      'name_cn': instance.nameCn,
      'short_summary': instance.shortSummary,
      'date': instance.date,
      'images': instance.images.toJson(),
      'volumes': instance.volumes,
      'eps': instance.eps,
      'collection_total': instance.collectionTotal,
      'score': instance.score,
      'tags': instance.tags.map((e) => e.toJson()).toList(),
    };

BangumiTag _$BangumiTagFromJson(Map<String, dynamic> json) => BangumiTag(
  name: json['name'] as String,
  count: (json['count'] as num).toInt(),
);

Map<String, dynamic> _$BangumiTagToJson(BangumiTag instance) =>
    <String, dynamic>{'name': instance.name, 'count': instance.count};

BangumiRelatedSubject _$BangumiRelatedSubjectFromJson(
  Map<String, dynamic> json,
) => BangumiRelatedSubject(
  id: (json['id'] as num).toInt(),
  staff: json['staff'] as String,
  name: json['name'] as String,
  nameCn: json['name_cn'] as String,
  image: json['image'] as String,
);

Map<String, dynamic> _$BangumiRelatedSubjectToJson(
  BangumiRelatedSubject instance,
) => <String, dynamic>{
  'id': instance.id,
  'staff': instance.staff,
  'name': instance.name,
  'name_cn': instance.nameCn,
  'image': instance.image,
};

BangumiSubjectRelation _$BangumiSubjectRelationFromJson(
  Map<String, dynamic> json,
) => BangumiSubjectRelation(
  id: (json['id'] as num).toInt(),
  type: $enumDecode(_$BangumiSubjectTypeEnumMap, json['type']),
  name: json['name'] as String,
  nameCn: json['name_cn'] as String,
  images: BangumiImages.fromJson(json['images'] as Map<String, dynamic>),
  relation: json['relation'] as String,
);

Map<String, dynamic> _$BangumiSubjectRelationToJson(
  BangumiSubjectRelation instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': _$BangumiSubjectTypeEnumMap[instance.type]!,
  'name': instance.name,
  'name_cn': instance.nameCn,
  'images': instance.images.toJson(),
  'relation': instance.relation,
};

const _$BangumiSubjectTypeEnumMap = {
  BangumiSubjectType.book: 1,
  BangumiSubjectType.anime: 2,
  BangumiSubjectType.music: 3,
  BangumiSubjectType.game: 4,
  BangumiSubjectType.real: 6,
};
