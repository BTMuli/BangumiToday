// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_model_character.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiCharacterDetail _$BangumiCharacterDetailFromJson(
  Map<String, dynamic> json,
) => BangumiCharacterDetail(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  type: $enumDecode(_$BangumiCharacterTypeEnumMap, json['type']),
  images: BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
  summary: json['summary'] as String,
  locked: json['locked'] as bool,
  infobox: json['infobox'],
  gender: json['gender'] as String,
  bloodType: $enumDecode(_$BangumiBloodTypeEnumMap, json['blood_type']),
  birthYear: (json['birth_year'] as num).toInt(),
  birthMon: (json['birth_mon'] as num).toInt(),
  birthDay: (json['birth_day'] as num).toInt(),
  stat: BangumiStat.fromJson(json['stat'] as Map<String, dynamic>),
);

Map<String, dynamic> _$BangumiCharacterDetailToJson(
  BangumiCharacterDetail instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$BangumiCharacterTypeEnumMap[instance.type]!,
  'images': instance.images.toJson(),
  'summary': instance.summary,
  'locked': instance.locked,
  'infobox': instance.infobox,
  'gender': instance.gender,
  'blood_type': _$BangumiBloodTypeEnumMap[instance.bloodType]!,
  'birth_year': instance.birthYear,
  'birth_mon': instance.birthMon,
  'birth_day': instance.birthDay,
  'stat': instance.stat.toJson(),
};

const _$BangumiCharacterTypeEnumMap = {
  BangumiCharacterType.character: 1,
  BangumiCharacterType.machine: 2,
  BangumiCharacterType.ship: 3,
  BangumiCharacterType.group: 4,
};

const _$BangumiBloodTypeEnumMap = {
  BangumiBloodType.a: 1,
  BangumiBloodType.b: 2,
  BangumiBloodType.ab: 3,
  BangumiBloodType.o: 4,
};

BangumiCharacterPerson _$BangumiCharacterPersonFromJson(
  Map<String, dynamic> json,
) => BangumiCharacterPerson(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  type: $enumDecode(_$BangumiCharacterTypeEnumMap, json['type']),
  images: BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
  subjectId: (json['subject_id'] as num).toInt(),
  subjectName: json['subject_name'] as String,
  subjectNameCn: json['subject_name_cn'] as String,
  staff: json['staff'] as String,
);

Map<String, dynamic> _$BangumiCharacterPersonToJson(
  BangumiCharacterPerson instance,
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
