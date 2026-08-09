// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import 'bangumi_model_person.dart';

part 'bangumi_model_revision.g.dart';

/// DetailedRevision
@JsonSerializable(explicitToJson: true)
class BangumiDetailedRevision {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  /// todo 这边的类型定义不明确
  @JsonKey(name: 'type')
  int type;

  /// creator
  @JsonKey(name: 'creator')
  BangumiCreator creator;

  /// summary
  @JsonKey(name: 'summary')
  String summary;

  /// created_at
  @JsonKey(name: 'created_at')
  String createdAt;

  /// data
  /// todo 这边内容是动态的
  @JsonKey(name: 'data')
  dynamic data;

  /// constructor
  BangumiDetailedRevision({
    required this.id,
    required this.type,
    required this.creator,
    required this.summary,
    required this.createdAt,
    required this.data,
  });

  /// from json
  factory BangumiDetailedRevision.fromJson(Map<String, dynamic> json) =>
      _$BangumiDetailedRevisionFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiDetailedRevisionToJson(this);
}

/// PersonRevision
@JsonSerializable(explicitToJson: true)
class BangumiPersonRevision {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  /// todo 文档没有列出具体值说明
  @JsonKey(name: 'type')
  int type;

  /// creator
  @JsonKey(name: 'creator')
  BangumiCreator creator;

  /// summary
  @JsonKey(name: 'summary')
  String summary;

  /// created_at
  @JsonKey(name: 'created_at')
  String createdAt;

  /// data
  /// todo 文档类型是 <*>: PersonRevisionDataItem
  @JsonKey(name: 'data')
  Map<dynamic, BangumiPersonRevisionDataItem> data;

  /// constructor
  BangumiPersonRevision({
    required this.id,
    required this.type,
    required this.creator,
    required this.summary,
    required this.createdAt,
    required this.data,
  });

  /// from json
  factory BangumiPersonRevision.fromJson(Map<String, dynamic> json) =>
      _$BangumiPersonRevisionFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiPersonRevisionToJson(this);
}

/// PersonRevisionDataItem
@JsonSerializable(explicitToJson: true)
class BangumiPersonRevisionDataItem {
  /// prsn_infobox
  @JsonKey(name: 'prsn_infobox')
  String personInfoBox;

  /// prsn_summary
  @JsonKey(name: 'prsn_summary')
  String personSummary;

  /// profession
  @JsonKey(name: 'profession')
  BangumiPersonRevisionProfession profession;

  /// extra
  @JsonKey(name: 'extra')
  BangumiRevisionExtra extra;

  /// prsn_name
  @JsonKey(name: 'prsn_name')
  String personName;

  /// constructor
  BangumiPersonRevisionDataItem({
    required this.personInfoBox,
    required this.personSummary,
    required this.profession,
    required this.extra,
    required this.personName,
  });

  /// from json
  factory BangumiPersonRevisionDataItem.fromJson(Map<String, dynamic> json) =>
      _$BangumiPersonRevisionDataItemFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiPersonRevisionDataItemToJson(this);
}

/// PersonRevisionProfession
@JsonSerializable()
class BangumiPersonRevisionProfession {
  /// producer
  @JsonKey(name: 'producer')
  String producer;

  /// mangaka
  @JsonKey(name: 'mangaka')
  String mangaka;

  /// artist
  @JsonKey(name: 'artist')
  String artist;

  /// seiyu
  @JsonKey(name: 'seiyu')
  String seiyu;

  /// writer
  @JsonKey(name: 'writer')
  String writer;

  /// illustrator
  @JsonKey(name: 'illustrator')
  String illustrator;

  /// actor
  @JsonKey(name: 'actor')
  String actor;

  /// constructor
  BangumiPersonRevisionProfession({
    required this.producer,
    required this.mangaka,
    required this.artist,
    required this.seiyu,
    required this.writer,
    required this.illustrator,
    required this.actor,
  });

  /// from json
  factory BangumiPersonRevisionProfession.fromJson(Map<String, dynamic> json) =>
      _$BangumiPersonRevisionProfessionFromJson(json);

  /// to json
  Map<String, dynamic> toJson() =>
      _$BangumiPersonRevisionProfessionToJson(this);
}

/// RevisionExtra
@JsonSerializable()
class BangumiRevisionExtra {
  /// img
  @JsonKey(name: 'img')
  String img;

  /// constructor
  BangumiRevisionExtra({required this.img});

  /// from json
  factory BangumiRevisionExtra.fromJson(Map<String, dynamic> json) =>
      _$BangumiRevisionExtraFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiRevisionExtraToJson(this);
}

/// SubjectRevision
@JsonSerializable(explicitToJson: true)
class BangumiSubjectRevision {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  /// todo 文档没有列出具体值说明
  @JsonKey(name: 'type')
  int type;

  /// creator
  @JsonKey(name: 'creator')
  BangumiCreator creator;

  /// summary
  @JsonKey(name: 'summary')
  String summary;

  /// created_at
  @JsonKey(name: 'created_at')
  String createdAt;

  /// data
  @JsonKey(name: 'data')
  BangumiSubjectRevisionData data;

  /// constructor
  BangumiSubjectRevision({
    required this.id,
    required this.type,
    required this.creator,
    required this.summary,
    required this.createdAt,
    required this.data,
  });

  /// from json
  factory BangumiSubjectRevision.fromJson(Map<String, dynamic> json) =>
      _$BangumiSubjectRevisionFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiSubjectRevisionToJson(this);
}

/// SubjectRevisionData
@JsonSerializable()
class BangumiSubjectRevisionData {
  /// field_eps
  @JsonKey(name: 'field_eps')
  int fieldEps;

  /// field_infobox
  @JsonKey(name: 'field_infobox')
  String fieldInfoBox;

  /// field_summary
  @JsonKey(name: 'field_summary')
  String fieldSummary;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// platform
  /// todo 文档没有列出具体值说明
  @JsonKey(name: 'platform')
  int platform;

  /// subject_id
  @JsonKey(name: 'subject_id')
  int subjectId;

  /// type
  /// todo 文档没有列出具体值说明
  @JsonKey(name: 'type')
  int type;

  /// type_id
  @JsonKey(name: 'type_id')
  int typeId;

  /// vote_id
  @JsonKey(name: 'vote_id')
  int voteId;

  /// constructor
  BangumiSubjectRevisionData({
    required this.fieldEps,
    required this.fieldInfoBox,
    required this.fieldSummary,
    required this.name,
    required this.nameCn,
    required this.platform,
    required this.subjectId,
    required this.type,
    required this.typeId,
    required this.voteId,
  });

  /// from json
  factory BangumiSubjectRevisionData.fromJson(Map<String, dynamic> json) =>
      _$BangumiSubjectRevisionDataFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiSubjectRevisionDataToJson(this);
}

/// CharacterRevision
@JsonSerializable(explicitToJson: true)
class BangumiCharacterRevision {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  /// todo 文档没有列出具体值说明
  @JsonKey(name: 'type')
  int type;

  /// creator
  @JsonKey(name: 'creator')
  BangumiCreator creator;

  /// summary
  @JsonKey(name: 'summary')
  String summary;

  /// created_at
  @JsonKey(name: 'created_at')
  String createdAt;

  /// data
  @JsonKey(name: 'data')
  Map<dynamic, BangumiCharacterRevisionDataItem> data;

  /// constructor
  BangumiCharacterRevision({
    required this.id,
    required this.type,
    required this.creator,
    required this.summary,
    required this.createdAt,
    required this.data,
  });

  /// from json
  factory BangumiCharacterRevision.fromJson(Map<String, dynamic> json) =>
      _$BangumiCharacterRevisionFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiCharacterRevisionToJson(this);
}

/// CharacterRevisionDataItem
@JsonSerializable(explicitToJson: true)
class BangumiCharacterRevisionDataItem {
  /// infobox
  @JsonKey(name: 'infobox')
  String infoBox;

  /// summary
  @JsonKey(name: 'summary')
  String summary;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// extra
  @JsonKey(name: 'extra')
  BangumiRevisionExtra extra;

  /// constructor
  BangumiCharacterRevisionDataItem({
    required this.infoBox,
    required this.summary,
    required this.name,
    required this.extra,
  });

  /// from json
  factory BangumiCharacterRevisionDataItem.fromJson(
    Map<String, dynamic> json,
  ) => _$BangumiCharacterRevisionDataItemFromJson(json);

  /// to json
  Map<String, dynamic> toJson() =>
      _$BangumiCharacterRevisionDataItemToJson(this);
}

/// Revision
@JsonSerializable(explicitToJson: true)
class BangumiRevision {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  /// todo 文档没有列出具体值说明
  @JsonKey(name: 'type')
  int type;

  /// creator
  @JsonKey(name: 'creator')
  BangumiCreator creator;

  /// summary
  @JsonKey(name: 'summary')
  String summary;

  /// created_at
  @JsonKey(name: 'created_at')
  String createdAt;

  /// constructor
  BangumiRevision({
    required this.id,
    required this.type,
    required this.creator,
    required this.summary,
    required this.createdAt,
  });

  /// from json
  factory BangumiRevision.fromJson(Map<String, dynamic> json) =>
      _$BangumiRevisionFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiRevisionToJson(this);
}
