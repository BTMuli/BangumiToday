// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_model_person.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiCreator _$BangumiCreatorFromJson(Map<String, dynamic> json) =>
    BangumiCreator(
      username: json['username'] as String,
      nickname: json['nickname'] as String,
    );

Map<String, dynamic> _$BangumiCreatorToJson(BangumiCreator instance) =>
    <String, dynamic>{
      'username': instance.username,
      'nickname': instance.nickname,
    };

BangumiImages _$BangumiImagesFromJson(Map<String, dynamic> json) =>
    BangumiImages(
      large: json['large'] as String,
      common: json['common'] as String,
      medium: json['medium'] as String,
      small: json['small'] as String,
      grid: json['grid'] as String,
    );

Map<String, dynamic> _$BangumiImagesToJson(BangumiImages instance) =>
    <String, dynamic>{
      'large': instance.large,
      'common': instance.common,
      'medium': instance.medium,
      'small': instance.small,
      'grid': instance.grid,
    };

BangumiPerson _$BangumiPersonFromJson(Map<String, dynamic> json) =>
    BangumiPerson(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: $enumDecode(_$BangumiPersonTypeEnumMap, json['type']),
      career: $enumDecode(_$BangumiPersonCareerTypeEnumMap, json['career']),
      images: BangumiPersonImages.fromJson(
        json['images'] as Map<String, dynamic>,
      ),
      shortSummary: json['short_summary'] as String,
      locked: json['locked'] as bool,
    );

Map<String, dynamic> _$BangumiPersonToJson(BangumiPerson instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': _$BangumiPersonTypeEnumMap[instance.type]!,
      'career': _$BangumiPersonCareerTypeEnumMap[instance.career]!,
      'images': instance.images.toJson(),
      'short_summary': instance.shortSummary,
      'locked': instance.locked,
    };

const _$BangumiPersonTypeEnumMap = {
  BangumiPersonType.person: 1,
  BangumiPersonType.company: 2,
  BangumiPersonType.group: 3,
};

const _$BangumiPersonCareerTypeEnumMap = {
  BangumiPersonCareerType.producer: 'producer',
  BangumiPersonCareerType.mangaka: 'mangaka',
  BangumiPersonCareerType.artist: 'artist',
  BangumiPersonCareerType.seiyu: 'seiyu',
  BangumiPersonCareerType.writer: 'writer',
  BangumiPersonCareerType.illustrator: 'illustrator',
  BangumiPersonCareerType.actor: 'actor',
};

BangumiPersonCharacter _$BangumiPersonCharacterFromJson(
  Map<String, dynamic> json,
) => BangumiPersonCharacter(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  type: $enumDecode(_$BangumiCharacterTypeEnumMap, json['type']),
  images: BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
  subjectId: (json['subject_id'] as num).toInt(),
  subjectName: json['subject_name'] as String,
  subjectNameCn: json['subject_name_cn'] as String,
  staff: json['staff'] as String,
);

Map<String, dynamic> _$BangumiPersonCharacterToJson(
  BangumiPersonCharacter instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$BangumiCharacterTypeEnumMap[instance.type]!,
  'images': instance.images.toJson(),
  'subject_id': instance.subjectId,
  'subject_name': instance.subjectName,
  'subject_name_cn': instance.subjectNameCn,
  'staff': instance.staff,
};

BangumiPersonDetail _$BangumiPersonDetailFromJson(Map<String, dynamic> json) =>
    BangumiPersonDetail(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: $enumDecode(_$BangumiPersonTypeEnumMap, json['type']),
      career: $enumDecode(_$BangumiPersonCareerTypeEnumMap, json['career']),
      images: BangumiPersonImages.fromJson(
        json['images'] as Map<String, dynamic>,
      ),
      summary: json['summary'] as String,
      locked: json['locked'] as bool,
      lastModified: json['last_modified'] as String,
      infobox: (json['infobox'] as List<dynamic>)
          .map((e) => BangumiInfoBoxItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      gender: json['gender'] as String,
      bloodType: $enumDecode(_$BangumiBloodTypeEnumMap, json['blood_type']),
      birthYear: (json['birth_year'] as num).toInt(),
      birthMon: (json['birth_mon'] as num).toInt(),
      birthDay: (json['birth_day'] as num).toInt(),
      stat: BangumiStat.fromJson(json['stat'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BangumiPersonDetailToJson(
  BangumiPersonDetail instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$BangumiPersonTypeEnumMap[instance.type]!,
  'career': _$BangumiPersonCareerTypeEnumMap[instance.career]!,
  'images': instance.images.toJson(),
  'summary': instance.summary,
  'locked': instance.locked,
  'last_modified': instance.lastModified,
  'infobox': instance.infobox.map((e) => e.toJson()).toList(),
  'gender': instance.gender,
  'blood_type': _$BangumiBloodTypeEnumMap[instance.bloodType]!,
  'birth_year': instance.birthYear,
  'birth_mon': instance.birthMon,
  'birth_day': instance.birthDay,
  'stat': instance.stat.toJson(),
};

BangumiPersonImages _$BangumiPersonImagesFromJson(Map<String, dynamic> json) =>
    BangumiPersonImages(
      large: json['large'] as String,
      medium: json['medium'] as String,
      small: json['small'] as String,
      grid: json['grid'] as String,
    );

Map<String, dynamic> _$BangumiPersonImagesToJson(
  BangumiPersonImages instance,
) => <String, dynamic>{
  'large': instance.large,
  'medium': instance.medium,
  'small': instance.small,
  'grid': instance.grid,
};

BangumiRelatedCharacter _$BangumiRelatedCharacterFromJson(
  Map<String, dynamic> json,
) => BangumiRelatedCharacter(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  type: $enumDecode(_$BangumiCharacterTypeEnumMap, json['type']),
  images: BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
  relation: json['relation'] as String,
  actors: (json['actors'] as List<dynamic>)
      .map((e) => BangumiPerson.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$BangumiRelatedCharacterToJson(
  BangumiRelatedCharacter instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$BangumiCharacterTypeEnumMap[instance.type]!,
  'images': instance.images.toJson(),
  'relation': instance.relation,
  'actors': instance.actors.map((e) => e.toJson()).toList(),
};

BangumiRelatedPerson _$BangumiRelatedPersonFromJson(
  Map<String, dynamic> json,
) => BangumiRelatedPerson(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  type: $enumDecode(_$BangumiPersonTypeEnumMap, json['type']),
  career: $enumDecode(_$BangumiPersonCareerTypeEnumMap, json['career']),
  images: BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
  relation: json['relation'] as String,
);

Map<String, dynamic> _$BangumiRelatedPersonToJson(
  BangumiRelatedPerson instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$BangumiPersonTypeEnumMap[instance.type]!,
  'career': _$BangumiPersonCareerTypeEnumMap[instance.career]!,
  'images': instance.images.toJson(),
  'relation': instance.relation,
};

BangumiStat _$BangumiStatFromJson(Map<String, dynamic> json) => BangumiStat(
  comments: (json['comments'] as num).toInt(),
  collects: (json['collects'] as num).toInt(),
);

Map<String, dynamic> _$BangumiStatToJson(BangumiStat instance) =>
    <String, dynamic>{
      'comments': instance.comments,
      'collects': instance.collects,
    };

const _$BangumiBloodTypeEnumMap = {
  BangumiBloodType.a: 1,
  BangumiBloodType.b: 2,
  BangumiBloodType.ab: 3,
  BangumiBloodType.o: 4,
};

const _$BangumiCharacterTypeEnumMap = {
  BangumiCharacterType.character: 1,
  BangumiCharacterType.machine: 2,
  BangumiCharacterType.ship: 3,
  BangumiCharacterType.group: 4,
};
