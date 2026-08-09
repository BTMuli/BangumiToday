// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import 'bangumi_enum.dart';
import 'bangumi_model_person.dart';

part 'bangumi_model_character.g.dart';

/// CharacterDetail
@JsonSerializable(explicitToJson: true)
class BangumiCharacterDetail {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// type
  @JsonKey(name: 'type')
  BangumiCharacterType type;

  /// images
  @JsonKey(name: 'images')
  BangumiPersonImages images;

  /// summary
  @JsonKey(name: 'summary')
  String summary;

  /// locked
  @JsonKey(name: 'locked')
  bool locked;

  /// infobox
  /// todo 这部分文档定义不明确
  @JsonKey(name: 'infobox')
  dynamic infobox;

  /// gender
  @JsonKey(name: 'gender')
  String gender;

  /// blood_type
  @JsonKey(name: 'blood_type')
  BangumiBloodType bloodType;

  /// birth_year
  @JsonKey(name: 'birth_year')
  int birthYear;

  /// birth_mon
  @JsonKey(name: 'birth_mon')
  int birthMon;

  /// birth_day
  @JsonKey(name: 'birth_day')
  int birthDay;

  /// stat
  @JsonKey(name: 'stat')
  BangumiStat stat;

  /// constructor
  BangumiCharacterDetail({
    required this.id,
    required this.name,
    required this.type,
    required this.images,
    required this.summary,
    required this.locked,
    required this.infobox,
    required this.gender,
    required this.bloodType,
    required this.birthYear,
    required this.birthMon,
    required this.birthDay,
    required this.stat,
  });

  /// from json
  factory BangumiCharacterDetail.fromJson(Map<String, dynamic> json) =>
      _$BangumiCharacterDetailFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiCharacterDetailToJson(this);
}

/// CharacterPerson
@JsonSerializable(explicitToJson: true)
class BangumiCharacterPerson {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// type
  @JsonKey(name: 'type')
  BangumiCharacterType type;

  /// images
  @JsonKey(name: 'images')
  BangumiPersonImages images;

  /// subject_id
  @JsonKey(name: 'subject_id')
  int subjectId;

  /// subject_name
  @JsonKey(name: 'subject_name')
  String subjectName;

  /// subject_name_cn
  @JsonKey(name: 'subject_name_cn')
  String subjectNameCn;

  /// staff
  @JsonKey(name: 'staff')
  String staff;

  /// constructor
  BangumiCharacterPerson({
    required this.id,
    required this.name,
    required this.type,
    required this.images,
    required this.subjectId,
    required this.subjectName,
    required this.subjectNameCn,
    required this.staff,
  });

  /// from json
  factory BangumiCharacterPerson.fromJson(Map<String, dynamic> json) =>
      _$BangumiCharacterPersonFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiCharacterPersonToJson(this);
}
