// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import 'bangumi_enum.dart';
import 'bangumi_model_index.dart';

part 'bangumi_model_person.g.dart';

/// Creator
@JsonSerializable()
class BangumiCreator {
  /// username
  @JsonKey(name: 'username')
  String username;

  /// nickname
  @JsonKey(name: 'nickname')
  String nickname;

  /// constructor
  BangumiCreator({required this.username, required this.nickname});

  /// from json
  factory BangumiCreator.fromJson(Map<String, dynamic> json) =>
      _$BangumiCreatorFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiCreatorToJson(this);
}

/// Images
@JsonSerializable()
class BangumiImages {
  /// large
  @JsonKey(name: 'large')
  String large;

  /// common
  @JsonKey(name: 'common')
  String common;

  /// medium
  @JsonKey(name: 'medium')
  String medium;

  /// small
  @JsonKey(name: 'small')
  String small;

  /// grid
  @JsonKey(name: 'grid')
  String grid;

  /// constructor
  BangumiImages({
    required this.large,
    required this.common,
    required this.medium,
    required this.small,
    required this.grid,
  });

  /// from json
  factory BangumiImages.fromJson(Map<String, dynamic> json) =>
      _$BangumiImagesFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiImagesToJson(this);
}

/// Person
@JsonSerializable(explicitToJson: true)
class BangumiPerson {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// type
  @JsonKey(name: 'type')
  BangumiPersonType type;

  /// career
  @JsonKey(name: 'career')
  BangumiPersonCareerType career;

  /// images
  @JsonKey(name: 'images')
  BangumiPersonImages images;

  /// short_summary
  @JsonKey(name: 'short_summary')
  String shortSummary;

  /// locked
  @JsonKey(name: 'locked')
  bool locked;

  /// constructor
  BangumiPerson({
    required this.id,
    required this.name,
    required this.type,
    required this.career,
    required this.images,
    required this.shortSummary,
    required this.locked,
  });

  /// from json
  factory BangumiPerson.fromJson(Map<String, dynamic> json) =>
      _$BangumiPersonFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiPersonToJson(this);
}

/// PersonCharacter
@JsonSerializable(explicitToJson: true)
class BangumiPersonCharacter {
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
  BangumiPersonCharacter({
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
  factory BangumiPersonCharacter.fromJson(Map<String, dynamic> json) =>
      _$BangumiPersonCharacterFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiPersonCharacterToJson(this);
}

/// PersonDetail
@JsonSerializable(explicitToJson: true)
class BangumiPersonDetail {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// type
  @JsonKey(name: 'type')
  BangumiPersonType type;

  /// career
  @JsonKey(name: 'career')
  BangumiPersonCareerType career;

  /// images
  @JsonKey(name: 'images')
  BangumiPersonImages images;

  /// summary
  @JsonKey(name: 'summary')
  String summary;

  /// locked
  @JsonKey(name: 'locked')
  bool locked;

  /// last_modified
  @JsonKey(name: 'last_modified')
  String lastModified;

  /// infobox
  @JsonKey(name: 'infobox')
  List<BangumiInfoBoxItem> infobox;

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
  BangumiPersonDetail({
    required this.id,
    required this.name,
    required this.type,
    required this.career,
    required this.images,
    required this.summary,
    required this.locked,
    required this.lastModified,
    required this.infobox,
    required this.gender,
    required this.bloodType,
    required this.birthYear,
    required this.birthMon,
    required this.birthDay,
    required this.stat,
  });

  /// from json
  factory BangumiPersonDetail.fromJson(Map<String, dynamic> json) =>
      _$BangumiPersonDetailFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiPersonDetailToJson(this);
}

/// PersonImages
@JsonSerializable()
class BangumiPersonImages {
  /// large
  @JsonKey(name: 'large')
  String large;

  /// medium
  @JsonKey(name: 'medium')
  String medium;

  /// small
  @JsonKey(name: 'small')
  String small;

  /// grid
  @JsonKey(name: 'grid')
  String grid;

  /// constructor
  BangumiPersonImages({
    required this.large,
    required this.medium,
    required this.small,
    required this.grid,
  });

  /// from json
  factory BangumiPersonImages.fromJson(Map<String, dynamic> json) =>
      _$BangumiPersonImagesFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiPersonImagesToJson(this);
}

/// RelatedCharacter
@JsonSerializable(explicitToJson: true)
class BangumiRelatedCharacter {
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

  /// relation
  @JsonKey(name: 'relation')
  String relation;

  /// actors
  @JsonKey(name: 'actors')
  List<BangumiPerson> actors;

  /// constructor
  BangumiRelatedCharacter({
    required this.id,
    required this.name,
    required this.type,
    required this.images,
    required this.relation,
    required this.actors,
  });

  /// from json
  factory BangumiRelatedCharacter.fromJson(Map<String, dynamic> json) =>
      _$BangumiRelatedCharacterFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiRelatedCharacterToJson(this);
}

/// RelatedPerson
@JsonSerializable(explicitToJson: true)
class BangumiRelatedPerson {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// type
  @JsonKey(name: 'type')
  BangumiPersonType type;

  /// career
  @JsonKey(name: 'career')
  BangumiPersonCareerType career;

  /// images
  @JsonKey(name: 'images')
  BangumiPersonImages images;

  /// relation
  @JsonKey(name: 'relation')
  String relation;

  /// constructor
  BangumiRelatedPerson({
    required this.id,
    required this.name,
    required this.type,
    required this.career,
    required this.images,
    required this.relation,
  });

  /// from json
  factory BangumiRelatedPerson.fromJson(Map<String, dynamic> json) =>
      _$BangumiRelatedPersonFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiRelatedPersonToJson(this);
}

/// Stat
@JsonSerializable(explicitToJson: true)
class BangumiStat {
  /// comments
  @JsonKey(name: 'comments')
  int comments;

  /// collects
  @JsonKey(name: 'collects')
  int collects;

  /// constructor
  BangumiStat({required this.comments, required this.collects});

  /// from json
  factory BangumiStat.fromJson(Map<String, dynamic> json) =>
      _$BangumiStatFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiStatToJson(this);
}
