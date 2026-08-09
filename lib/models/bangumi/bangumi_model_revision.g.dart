// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_model_revision.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiDetailedRevision _$BangumiDetailedRevisionFromJson(
  Map<String, dynamic> json,
) => BangumiDetailedRevision(
  id: (json['id'] as num).toInt(),
  type: (json['type'] as num).toInt(),
  creator: BangumiCreator.fromJson(json['creator'] as Map<String, dynamic>),
  summary: json['summary'] as String,
  createdAt: json['created_at'] as String,
  data: json['data'],
);

Map<String, dynamic> _$BangumiDetailedRevisionToJson(
  BangumiDetailedRevision instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'creator': instance.creator.toJson(),
  'summary': instance.summary,
  'created_at': instance.createdAt,
  'data': instance.data,
};

BangumiPersonRevision _$BangumiPersonRevisionFromJson(
  Map<String, dynamic> json,
) => BangumiPersonRevision(
  id: (json['id'] as num).toInt(),
  type: (json['type'] as num).toInt(),
  creator: BangumiCreator.fromJson(json['creator'] as Map<String, dynamic>),
  summary: json['summary'] as String,
  createdAt: json['created_at'] as String,
  data: (json['data'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(
      k,
      BangumiPersonRevisionDataItem.fromJson(e as Map<String, dynamic>),
    ),
  ),
);

Map<String, dynamic> _$BangumiPersonRevisionToJson(
  BangumiPersonRevision instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'creator': instance.creator.toJson(),
  'summary': instance.summary,
  'created_at': instance.createdAt,
  'data': instance.data.map((k, e) => MapEntry(k, e.toJson())),
};

BangumiPersonRevisionDataItem _$BangumiPersonRevisionDataItemFromJson(
  Map<String, dynamic> json,
) => BangumiPersonRevisionDataItem(
  personInfoBox: json['prsn_infobox'] as String,
  personSummary: json['prsn_summary'] as String,
  profession: BangumiPersonRevisionProfession.fromJson(
    json['profession'] as Map<String, dynamic>,
  ),
  extra: BangumiRevisionExtra.fromJson(json['extra'] as Map<String, dynamic>),
  personName: json['prsn_name'] as String,
);

Map<String, dynamic> _$BangumiPersonRevisionDataItemToJson(
  BangumiPersonRevisionDataItem instance,
) => <String, dynamic>{
  'prsn_infobox': instance.personInfoBox,
  'prsn_summary': instance.personSummary,
  'profession': instance.profession.toJson(),
  'extra': instance.extra.toJson(),
  'prsn_name': instance.personName,
};

BangumiPersonRevisionProfession _$BangumiPersonRevisionProfessionFromJson(
  Map<String, dynamic> json,
) => BangumiPersonRevisionProfession(
  producer: json['producer'] as String,
  mangaka: json['mangaka'] as String,
  artist: json['artist'] as String,
  seiyu: json['seiyu'] as String,
  writer: json['writer'] as String,
  illustrator: json['illustrator'] as String,
  actor: json['actor'] as String,
);

Map<String, dynamic> _$BangumiPersonRevisionProfessionToJson(
  BangumiPersonRevisionProfession instance,
) => <String, dynamic>{
  'producer': instance.producer,
  'mangaka': instance.mangaka,
  'artist': instance.artist,
  'seiyu': instance.seiyu,
  'writer': instance.writer,
  'illustrator': instance.illustrator,
  'actor': instance.actor,
};

BangumiRevisionExtra _$BangumiRevisionExtraFromJson(
  Map<String, dynamic> json,
) => BangumiRevisionExtra(img: json['img'] as String);

Map<String, dynamic> _$BangumiRevisionExtraToJson(
  BangumiRevisionExtra instance,
) => <String, dynamic>{'img': instance.img};

BangumiSubjectRevision _$BangumiSubjectRevisionFromJson(
  Map<String, dynamic> json,
) => BangumiSubjectRevision(
  id: (json['id'] as num).toInt(),
  type: (json['type'] as num).toInt(),
  creator: BangumiCreator.fromJson(json['creator'] as Map<String, dynamic>),
  summary: json['summary'] as String,
  createdAt: json['created_at'] as String,
  data: BangumiSubjectRevisionData.fromJson(
    json['data'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$BangumiSubjectRevisionToJson(
  BangumiSubjectRevision instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'creator': instance.creator.toJson(),
  'summary': instance.summary,
  'created_at': instance.createdAt,
  'data': instance.data.toJson(),
};

BangumiSubjectRevisionData _$BangumiSubjectRevisionDataFromJson(
  Map<String, dynamic> json,
) => BangumiSubjectRevisionData(
  fieldEps: (json['field_eps'] as num).toInt(),
  fieldInfoBox: json['field_infobox'] as String,
  fieldSummary: json['field_summary'] as String,
  name: json['name'] as String,
  nameCn: json['name_cn'] as String,
  platform: (json['platform'] as num).toInt(),
  subjectId: (json['subject_id'] as num).toInt(),
  type: (json['type'] as num).toInt(),
  typeId: (json['type_id'] as num).toInt(),
  voteId: (json['vote_id'] as num).toInt(),
);

Map<String, dynamic> _$BangumiSubjectRevisionDataToJson(
  BangumiSubjectRevisionData instance,
) => <String, dynamic>{
  'field_eps': instance.fieldEps,
  'field_infobox': instance.fieldInfoBox,
  'field_summary': instance.fieldSummary,
  'name': instance.name,
  'name_cn': instance.nameCn,
  'platform': instance.platform,
  'subject_id': instance.subjectId,
  'type': instance.type,
  'type_id': instance.typeId,
  'vote_id': instance.voteId,
};

BangumiCharacterRevision _$BangumiCharacterRevisionFromJson(
  Map<String, dynamic> json,
) => BangumiCharacterRevision(
  id: (json['id'] as num).toInt(),
  type: (json['type'] as num).toInt(),
  creator: BangumiCreator.fromJson(json['creator'] as Map<String, dynamic>),
  summary: json['summary'] as String,
  createdAt: json['created_at'] as String,
  data: (json['data'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(
      k,
      BangumiCharacterRevisionDataItem.fromJson(e as Map<String, dynamic>),
    ),
  ),
);

Map<String, dynamic> _$BangumiCharacterRevisionToJson(
  BangumiCharacterRevision instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'creator': instance.creator.toJson(),
  'summary': instance.summary,
  'created_at': instance.createdAt,
  'data': instance.data.map((k, e) => MapEntry(k, e.toJson())),
};

BangumiCharacterRevisionDataItem _$BangumiCharacterRevisionDataItemFromJson(
  Map<String, dynamic> json,
) => BangumiCharacterRevisionDataItem(
  infoBox: json['infobox'] as String,
  summary: json['summary'] as String,
  name: json['name'] as String,
  extra: BangumiRevisionExtra.fromJson(json['extra'] as Map<String, dynamic>),
);

Map<String, dynamic> _$BangumiCharacterRevisionDataItemToJson(
  BangumiCharacterRevisionDataItem instance,
) => <String, dynamic>{
  'infobox': instance.infoBox,
  'summary': instance.summary,
  'name': instance.name,
  'extra': instance.extra.toJson(),
};

BangumiRevision _$BangumiRevisionFromJson(Map<String, dynamic> json) =>
    BangumiRevision(
      id: (json['id'] as num).toInt(),
      type: (json['type'] as num).toInt(),
      creator: BangumiCreator.fromJson(json['creator'] as Map<String, dynamic>),
      summary: json['summary'] as String,
      createdAt: json['created_at'] as String,
    );

Map<String, dynamic> _$BangumiRevisionToJson(BangumiRevision instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'creator': instance.creator.toJson(),
      'summary': instance.summary,
      'created_at': instance.createdAt,
    };
