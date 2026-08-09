// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import 'bangumi_enum.dart';
import 'bangumi_model_person.dart';

part 'bangumi_model_index.g.dart';

/// Index
@JsonSerializable(explicitToJson: true)
class BangumiIndex {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// title
  @JsonKey(name: 'title')
  String title;

  /// desc
  @JsonKey(name: 'desc')
  String desc;

  /// total
  @JsonKey(name: 'total')
  int total;

  /// stat
  @JsonKey(name: 'stat')
  BangumiStat stat;

  /// created_at
  @JsonKey(name: 'created_at')
  String createdAt;

  /// updated_at
  @JsonKey(name: 'updated_at')
  String updatedAt;

  /// creator
  @JsonKey(name: 'creator')
  BangumiCreator creator;

  /// nsfw
  @JsonKey(name: 'nsfw')
  bool nsfw;

  /// constructor
  BangumiIndex({
    required this.id,
    required this.title,
    required this.desc,
    required this.total,
    required this.stat,
    required this.createdAt,
    required this.updatedAt,
    required this.creator,
    required this.nsfw,
  });

  /// from json
  factory BangumiIndex.fromJson(Map<String, dynamic> json) =>
      _$BangumiIndexFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiIndexToJson(this);
}

/// IndexSubject
@JsonSerializable(explicitToJson: true)
class BangumiIndexSubject {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  @JsonKey(name: 'type')
  BangumiSubjectType type;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// images
  @JsonKey(name: 'images')
  BangumiImages images;

  /// infobox
  @JsonKey(name: 'infobox')
  List<BangumiInfoBoxItem> infobox;

  /// date
  @JsonKey(name: 'date')
  String date;

  /// comment
  @JsonKey(name: 'comment')
  String comment;

  /// added_at
  @JsonKey(name: 'added_at')
  String addedAt;

  /// constructor
  BangumiIndexSubject({
    required this.id,
    required this.type,
    required this.name,
    required this.images,
    required this.infobox,
    required this.date,
    required this.comment,
    required this.addedAt,
  });

  /// from json
  factory BangumiIndexSubject.fromJson(Map<String, dynamic> json) =>
      _$BangumiIndexSubjectFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiIndexSubjectToJson(this);
}

/// IndexBasicInfo
/// 新增或修改条目的内容
@JsonSerializable()
class BangumiIndexBasicInfo1 {
  /// title
  @JsonKey(name: 'title')
  String title;

  /// description
  @JsonKey(name: 'description')
  String description;

  /// constructor
  BangumiIndexBasicInfo1({required this.title, required this.description});

  /// from json
  factory BangumiIndexBasicInfo1.fromJson(Map<String, dynamic> json) =>
      _$BangumiIndexBasicInfo1FromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiIndexBasicInfo1ToJson(this);
}

/// IndexBasicInfo
/// 新增某条目到目录的请求信息
@JsonSerializable()
class BangumiIndexBasicInfo2 {
  /// subject_id
  @JsonKey(name: 'subject_id')
  int subjectId;

  /// sort
  @JsonKey(name: 'sort')
  int sort;

  /// comment
  @JsonKey(name: 'comment')
  String comment;

  /// constructor
  BangumiIndexBasicInfo2({
    required this.subjectId,
    required this.sort,
    required this.comment,
  });

  /// from json
  factory BangumiIndexBasicInfo2.fromJson(Map<String, dynamic> json) =>
      _$BangumiIndexBasicInfo2FromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiIndexBasicInfo2ToJson(this);
}

/// IndexBasicInfo
/// 修改条目中条目的信息
@JsonSerializable()
class BangumiIndexBasicInfo3 {
  /// sort
  @JsonKey(name: 'sort')
  int sort;

  /// comment
  @JsonKey(name: 'comment')
  String comment;

  /// constructor
  BangumiIndexBasicInfo3({required this.sort, required this.comment});

  /// from json
  factory BangumiIndexBasicInfo3.fromJson(Map<String, dynamic> json) =>
      _$BangumiIndexBasicInfo3FromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiIndexBasicInfo3ToJson(this);
}

/// Infobox
/// 因为本身是个列表，所以定义列表的内容
@JsonSerializable()
class BangumiInfoBoxItem {
  /// key
  @JsonKey(name: 'key')
  String key;

  /// value
  /// string | {v:string, k?:string}
  @JsonKey(name: 'value')
  dynamic value;

  /// constructor
  BangumiInfoBoxItem({required this.key, required this.value});

  /// from json
  factory BangumiInfoBoxItem.fromJson(Map<String, dynamic> json) =>
      _$BangumiInfoBoxItemFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiInfoBoxItemToJson(this);
}

/// Page
@JsonSerializable()
class BangumiPage {
  /// total
  @JsonKey(name: 'total')
  int total;

  /// limit
  @JsonKey(name: 'limit')
  int limit;

  /// offset
  @JsonKey(name: 'offset')
  int offset;

  /// constructor
  BangumiPage({required this.total, required this.limit, required this.offset});

  /// from json
  factory BangumiPage.fromJson(Map<String, dynamic> json) =>
      _$BangumiPageFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiPageToJson(this);
}

/// Paged[Episode]、Paged[IndexSubject]、Paged[Revision]、Paged[UserCollection]
/// 采用泛型，分别对应的数据为：
/// Episode、IndexSubject、Revision、UserSubjectCollection
@JsonSerializable(genericArgumentFactories: true, explicitToJson: true)
class BangumiPageT<T> {
  /// total
  @JsonKey(name: 'total')
  int total;

  /// limit
  @JsonKey(name: 'limit')
  int limit;

  /// offset
  @JsonKey(name: 'offset')
  int offset;

  /// data
  @JsonKey(name: 'data')
  List<T> data;

  /// constructor
  BangumiPageT({
    required this.total,
    required this.limit,
    required this.offset,
    required this.data,
  });

  /// from json
  factory BangumiPageT.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) => _$BangumiPageTFromJson(json, fromJsonT);

  /// to json
  Map<String, dynamic> toJson(dynamic Function(T value) toJsonT) =>
      _$BangumiPageTToJson(this, toJsonT);
}
