// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import 'bangumi_enum.dart';
import 'bangumi_model_patch.dart';

/// 从Bangumi API获取的数据模型，按照Bangumi API文档排列顺序排序
/// 详细文档参考 https://bangumi.github.io/api/
/// 枚举类型定义在 bangumi_enum.dart 中
/// todo 里面的数据默认非空，需要根据实际情况修改

part 'bangumi_model.g.dart';

/// Legacy_SubjectSmall
@JsonSerializable(explicitToJson: true)
class BangumiLegacySubjectSmall {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// url
  @JsonKey(name: 'url')
  String url;

  /// type
  @JsonKey(name: 'type')
  BangumiLegacySubjectType type;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// summary
  @JsonKey(name: 'summary')
  String summary;

  /// air_date
  /// 格式 2002-04-02
  @JsonKey(name: 'air_date')
  String airDate;

  /// air_weekday
  @JsonKey(name: 'air_weekday')
  int airWeekday;

  /// images
  @JsonKey(name: 'images')
  BangumiPersonImages? images;

  /// eps
  @JsonKey(name: 'eps')
  int? eps;

  /// eps_count
  @JsonKey(name: 'eps_count')
  int? epsCount;

  /// rating
  @JsonKey(name: 'rating')
  BangumiPatchRating? rating;

  /// rank
  @JsonKey(name: 'rank')
  int? rank;

  /// collection
  @JsonKey(name: 'collection')
  BangumiPatchCollection? collection;

  /// constructor
  BangumiLegacySubjectSmall({
    required this.id,
    required this.url,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.airDate,
    required this.airWeekday,
    required this.images,
    required this.eps,
    required this.epsCount,
    required this.rating,
    required this.rank,
    required this.collection,
  });

  /// from json
  factory BangumiLegacySubjectSmall.fromJson(Map<String, dynamic> json) =>
      _$BangumiLegacySubjectSmallFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiLegacySubjectSmallToJson(this);
}

/// Legacy_SubjectMedium的角色信息
@JsonSerializable(explicitToJson: true)
class BangumiLegacySubjectCharacter {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// url
  @JsonKey(name: 'url')
  String url;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// images
  @JsonKey(name: 'images')
  BangumiPersonImages images;

  /// comment 回复数量
  @JsonKey(name: 'comment')
  int comment;

  /// collects 收藏数量
  @JsonKey(name: 'collects')
  int collects;

  /// info 任务信息
  @JsonKey(name: 'info')
  BangumiLegacyMonoInfo info;

  /// actors 声优列表
  @JsonKey(name: 'actors')
  List<BangumiLegacyMonoBase> actors;

  /// role_name 主角
  @JsonKey(name: 'role_name')
  String roleName;

  /// constructor
  BangumiLegacySubjectCharacter({
    required this.id,
    required this.url,
    required this.name,
    required this.nameCn,
    required this.images,
    required this.comment,
    required this.collects,
    required this.info,
    required this.actors,
    required this.roleName,
  });

  /// from json
  factory BangumiLegacySubjectCharacter.fromJson(Map<String, dynamic> json) =>
      _$BangumiLegacySubjectCharacterFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiLegacySubjectCharacterToJson(this);
}

/// Legacy_SubjectMedium的制作信息
@JsonSerializable(explicitToJson: true)
class BangumiLegacySubjectStaff {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// url
  @JsonKey(name: 'url')
  String url;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// images
  @JsonKey(name: 'images')
  BangumiPersonImages images;

  /// comment
  @JsonKey(name: 'comment')
  int comment;

  /// collects
  @JsonKey(name: 'collects')
  int collects;

  /// info
  @JsonKey(name: 'info')
  BangumiLegacyMonoInfo info;

  /// role_name
  @JsonKey(name: 'role_name')
  String roleName;

  /// jobs
  @JsonKey(name: 'jobs')
  List<String> jobs;

  /// constructor
  BangumiLegacySubjectStaff({
    required this.id,
    required this.url,
    required this.name,
    required this.nameCn,
    required this.images,
    required this.comment,
    required this.collects,
    required this.info,
    required this.roleName,
    required this.jobs,
  });

  /// from json
  factory BangumiLegacySubjectStaff.fromJson(Map<String, dynamic> json) =>
      _$BangumiLegacySubjectStaffFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiLegacySubjectStaffToJson(this);
}

/// Legacy_SubjectMedium
/// 与 Legacy_SubjectSmall 的区别是增加了 crt 和 staff 两个字段
@JsonSerializable(explicitToJson: true)
class BangumiLegacySubjectMedium {
  /// crt 角色信息
  @JsonKey(name: 'crt')
  List<BangumiLegacySubjectCharacter> crt;

  /// staff 制作信息
  @JsonKey(name: 'staff')
  List<BangumiLegacySubjectStaff> staff;

  /// 下面的字段与 Legacy_SubjectSmall 一致
  /// id
  @JsonKey(name: 'id')
  int id;

  /// url
  @JsonKey(name: 'url')
  String url;

  /// type
  @JsonKey(name: 'type')
  BangumiLegacySubjectType type;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// summary
  @JsonKey(name: 'summary')
  String summary;

  /// air_date
  /// 格式 2002-04-02
  @JsonKey(name: 'air_date')
  String airDate;

  /// air_weekday
  @JsonKey(name: 'air_weekday')
  int airWeekday;

  /// images
  @JsonKey(name: 'images')
  BangumiPersonImages? images;

  /// eps
  @JsonKey(name: 'eps')
  int? eps;

  /// eps_count
  @JsonKey(name: 'eps_count')
  int? epsCount;

  /// rating
  @JsonKey(name: 'rating')
  BangumiPatchRating? rating;

  /// rank
  @JsonKey(name: 'rank')
  int? rank;

  /// collection
  @JsonKey(name: 'collection')
  BangumiPatchCollection? collection;

  /// constructor
  BangumiLegacySubjectMedium({
    required this.crt,
    required this.staff,
    required this.id,
    required this.url,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.airDate,
    required this.airWeekday,
    required this.images,
    required this.eps,
    required this.epsCount,
    required this.rating,
    required this.rank,
    required this.collection,
  });

  /// from json
  factory BangumiLegacySubjectMedium.fromJson(Map<String, dynamic> json) =>
      _$BangumiLegacySubjectMediumFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiLegacySubjectMediumToJson(this);
}

/// Legacy_SubjectLarge
/// 与 Legacy_SubjectMedium 的区别是增加了 topic 和 blog 两个字段
@JsonSerializable(explicitToJson: true)
class BangumiLegacySubjectLarge {
  /// topic
  @JsonKey(name: 'topic')
  List<BangumiLegacyTopic> topic;

  /// blog
  @JsonKey(name: 'blog')
  List<BangumiLegacyBlog> blog;

  /// 下面的字段与 Legacy_SubjectMedium 一致

  /// id
  @JsonKey(name: 'id')
  int id;

  /// url
  @JsonKey(name: 'url')
  String url;

  /// type
  @JsonKey(name: 'type')
  BangumiLegacySubjectType type;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// summary
  @JsonKey(name: 'summary')
  String summary;

  /// air_date
  /// 格式 2002-04-02
  @JsonKey(name: 'air_date')
  String airDate;

  /// air_weekday
  @JsonKey(name: 'air_weekday')
  int airWeekday;

  /// images
  @JsonKey(name: 'images')
  BangumiPersonImages? images;

  /// eps
  @JsonKey(name: 'eps')
  int? eps;

  /// eps_count
  @JsonKey(name: 'eps_count')
  int? epsCount;

  /// rating
  @JsonKey(name: 'rating')
  BangumiPatchRating? rating;

  /// rank
  @JsonKey(name: 'rank')
  int? rank;

  /// collection
  @JsonKey(name: 'collection')
  BangumiPatchCollection? collection;

  /// crt 角色信息
  @JsonKey(name: 'crt')
  List<BangumiLegacySubjectCharacter> crt;

  /// staff 制作信息
  @JsonKey(name: 'staff')
  List<BangumiLegacySubjectStaff> staff;

  /// constructor
  BangumiLegacySubjectLarge({
    required this.topic,
    required this.blog,
    required this.id,
    required this.url,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.airDate,
    required this.airWeekday,
    required this.images,
    required this.eps,
    required this.epsCount,
    required this.rating,
    required this.rank,
    required this.collection,
    required this.crt,
    required this.staff,
  });

  /// from json
  factory BangumiLegacySubjectLarge.fromJson(Map<String, dynamic> json) =>
      _$BangumiLegacySubjectLargeFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiLegacySubjectLargeToJson(this);
}

/// Legacy_Episode
@JsonSerializable()
class BangumiLegacyEpisode {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// url
  @JsonKey(name: 'url')
  String url;

  /// type
  @JsonKey(name: 'type')
  BangumiLegacyEpisodeType type;

  /// sort
  @JsonKey(name: 'sort')
  int sort;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// duration
  @JsonKey(name: 'duration')
  String duration;

  /// airdate
  @JsonKey(name: 'airdate')
  String airDate;

  /// comment
  @JsonKey(name: 'comment')
  int comment;

  /// desc
  @JsonKey(name: 'desc')
  String desc;

  /// status
  @JsonKey(name: 'status')
  BangumiLegacyEpisodeStatusType status;

  /// constructor
  BangumiLegacyEpisode({
    required this.id,
    required this.url,
    required this.type,
    required this.sort,
    required this.name,
    required this.nameCn,
    required this.duration,
    required this.airDate,
    required this.comment,
    required this.desc,
    required this.status,
  });

  /// from json
  factory BangumiLegacyEpisode.fromJson(Map<String, dynamic> json) =>
      _$BangumiLegacyEpisodeFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiLegacyEpisodeToJson(this);
}

/// Legacy_Topic
@JsonSerializable(explicitToJson: true)
class BangumiLegacyTopic {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// url
  @JsonKey(name: 'url')
  String url;

  /// title
  @JsonKey(name: 'title')
  String title;

  /// main_id
  @JsonKey(name: 'main_id')
  int mainId;

  /// timestamp
  @JsonKey(name: 'timestamp')
  int timestamp;

  /// lastpost
  @JsonKey(name: 'lastpost')
  int lastPost;

  /// replies
  @JsonKey(name: 'replies')
  int replies;

  /// user
  @JsonKey(name: 'user')
  BangumiLegacyUser user;

  /// constructor
  BangumiLegacyTopic({
    required this.id,
    required this.url,
    required this.title,
    required this.mainId,
    required this.timestamp,
    required this.lastPost,
    required this.replies,
    required this.user,
  });

  /// from json
  factory BangumiLegacyTopic.fromJson(Map<String, dynamic> json) =>
      _$BangumiLegacyTopicFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiLegacyTopicToJson(this);
}

/// Legacy_Blog
@JsonSerializable(explicitToJson: true)
class BangumiLegacyBlog {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// url
  @JsonKey(name: 'url')
  String url;

  /// title
  @JsonKey(name: 'title')
  String title;

  /// summary
  @JsonKey(name: 'summary')
  String summary;

  /// image
  @JsonKey(name: 'image')
  String image;

  /// replies
  @JsonKey(name: 'replies')
  int replies;

  /// timestamp
  @JsonKey(name: 'timestamp')
  int timestamp;

  /// dateline
  /// 格式：2013-1-2 16:41
  @JsonKey(name: 'dateline')
  String dateline;

  /// user
  @JsonKey(name: 'user')
  BangumiLegacyUser user;

  /// constructor
  BangumiLegacyBlog({
    required this.id,
    required this.url,
    required this.title,
    required this.summary,
    required this.image,
    required this.replies,
    required this.timestamp,
    required this.dateline,
    required this.user,
  });

  /// from json
  factory BangumiLegacyBlog.fromJson(Map<String, dynamic> json) =>
      _$BangumiLegacyBlogFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiLegacyBlogToJson(this);
}

/// Legacy_User
@JsonSerializable(explicitToJson: true)
class BangumiLegacyUser {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// url
  @JsonKey(name: 'url')
  String url;

  /// username
  @JsonKey(name: 'username')
  String username;

  /// nickname
  @JsonKey(name: 'nickname')
  String nickname;

  /// avatar
  @JsonKey(name: 'avatar')
  BangumiAvatar avatar;

  /// sign
  @JsonKey(name: 'sign')
  String sign;

  /// usergroup
  @JsonKey(name: 'usergroup')
  BangumiLegacyUserGroupType userGroup;

  /// constructor
  BangumiLegacyUser({
    required this.id,
    required this.url,
    required this.username,
    required this.nickname,
    required this.avatar,
    required this.sign,
    required this.userGroup,
  });

  /// from json
  factory BangumiLegacyUser.fromJson(Map<String, dynamic> json) =>
      _$BangumiLegacyUserFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiLegacyUserToJson(this);
}

/// Legacy_Person
@JsonSerializable(explicitToJson: true)
class BangumiLegacyPerson {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// url
  @JsonKey(name: 'url')
  String url;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// images
  @JsonKey(name: 'images')
  BangumiPersonImages images;

  /// comment
  @JsonKey(name: 'comment')
  int comment;

  /// collects
  @JsonKey(name: 'collects')
  int collects;

  /// info
  @JsonKey(name: 'info')
  BangumiLegacyMonoInfo info;

  /// constructor
  BangumiLegacyPerson({
    required this.id,
    required this.url,
    required this.name,
    required this.nameCn,
    required this.images,
    required this.comment,
    required this.collects,
    required this.info,
  });

  /// from json
  factory BangumiLegacyPerson.fromJson(Map<String, dynamic> json) =>
      _$BangumiLegacyPersonFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiLegacyPersonToJson(this);
}

/// Legacy_Character
@JsonSerializable(explicitToJson: true)
class BangumiLegacyCharacter {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// url
  @JsonKey(name: 'url')
  String url;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// images
  @JsonKey(name: 'images')
  BangumiPersonImages images;

  /// comment
  @JsonKey(name: 'comment')
  int comment;

  /// collects
  @JsonKey(name: 'collects')
  int collects;

  /// info
  @JsonKey(name: 'info')
  BangumiLegacyMonoInfo info;

  /// actors
  @JsonKey(name: 'actors')
  List<BangumiLegacyMonoBase> actors;

  /// constructor
  BangumiLegacyCharacter({
    required this.id,
    required this.url,
    required this.name,
    required this.nameCn,
    required this.images,
    required this.comment,
    required this.collects,
    required this.info,
    required this.actors,
  });

  /// from json
  factory BangumiLegacyCharacter.fromJson(Map<String, dynamic> json) =>
      _$BangumiLegacyCharacterFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiLegacyCharacterToJson(this);
}

/// Legacy_MonoBase
@JsonSerializable(explicitToJson: true)
class BangumiLegacyMonoBase {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// url
  @JsonKey(name: 'url')
  String url;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// images
  @JsonKey(name: 'images')
  BangumiPersonImages images;

  /// constructor
  BangumiLegacyMonoBase({
    required this.id,
    required this.url,
    required this.name,
    required this.images,
  });

  /// from json
  factory BangumiLegacyMonoBase.fromJson(Map<String, dynamic> json) =>
      _$BangumiLegacyMonoBaseFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiLegacyMonoBaseToJson(this);
}

/// LegacyMono
@JsonSerializable(explicitToJson: true)
class BangumiLegacyMono {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// url
  @JsonKey(name: 'url')
  String url;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// images
  @JsonKey(name: 'images')
  BangumiPersonImages images;

  /// comment
  @JsonKey(name: 'comment')
  int comment;

  /// collects
  @JsonKey(name: 'collects')
  int collects;

  /// constructor
  BangumiLegacyMono({
    required this.id,
    required this.url,
    required this.name,
    required this.nameCn,
    required this.images,
    required this.comment,
    required this.collects,
  });

  /// from json
  factory BangumiLegacyMono.fromJson(Map<String, dynamic> json) =>
      _$BangumiLegacyMonoFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiLegacyMonoToJson(this);
}

/// Legacy_MonoInfo
@JsonSerializable()
class BangumiLegacyMonoInfo {
  /// birth 4月13日
  @JsonKey(name: 'birth')
  String birth;

  /// height 152cm
  @JsonKey(name: 'height')
  String height;

  /// gender 女
  @JsonKey(name: 'gender')
  String gender;

  /// alias
  /// todo 文档说明比较模糊，需要根据实际情况修改
  @JsonKey(name: 'alias')
  Map<String, dynamic> alias;

  /// source
  /// 可能是 string，也可能是 string[]
  @JsonKey(name: 'source')
  dynamic source;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// cv
  @JsonKey(name: 'cv')
  String cv;

  /// constructor
  BangumiLegacyMonoInfo({
    required this.birth,
    required this.height,
    required this.gender,
    required this.alias,
    required this.source,
    required this.nameCn,
    required this.cv,
  });

  /// from json
  factory BangumiLegacyMonoInfo.fromJson(Map<String, dynamic> json) =>
      _$BangumiLegacyMonoInfoFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiLegacyMonoInfoToJson(this);
}

/// User
@JsonSerializable(explicitToJson: true)
class BangumiUser {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// username
  @JsonKey(name: 'username')
  String username;

  /// nickname
  @JsonKey(name: 'nickname')
  String nickname;

  /// user_group
  @JsonKey(name: 'user_group')
  BangumiLegacyUserGroupType userGroup;

  /// avatar
  @JsonKey(name: 'avatar')
  BangumiAvatar avatar;

  /// sign
  @JsonKey(name: 'sign')
  String sign;

  /// constructor
  BangumiUser({
    required this.id,
    required this.username,
    required this.nickname,
    required this.userGroup,
    required this.avatar,
    required this.sign,
  });

  /// from json
  factory BangumiUser.fromJson(Map<String, dynamic> json) =>
      _$BangumiUserFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiUserToJson(this);
}

/// 通用模型-图片-用于用户
@JsonSerializable()
class BangumiAvatar {
  /// large
  @JsonKey(name: 'large')
  String large;

  /// medium
  @JsonKey(name: 'medium')
  String medium;

  /// small
  @JsonKey(name: 'small')
  String small;

  /// constructor
  BangumiAvatar({
    required this.large,
    required this.medium,
    required this.small,
  });

  /// from json
  factory BangumiAvatar.fromJson(Map<String, dynamic> json) =>
      _$BangumiAvatarFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiAvatarToJson(this);
}

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
  BangumiCreator({
    required this.username,
    required this.nickname,
  });

  /// from json
  factory BangumiCreator.fromJson(Map<String, dynamic> json) =>
      _$BangumiCreatorFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiCreatorToJson(this);
}

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
  BangumiRevisionExtra({
    required this.img,
  });

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
          Map<String, dynamic> json) =>
      _$BangumiCharacterRevisionDataItemFromJson(json);

  /// to json
  Map<String, dynamic> toJson() =>
      _$BangumiCharacterRevisionDataItemToJson(this);
}

/// Episode
@JsonSerializable()
class BangumiEpisode {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  @JsonKey(name: 'type')
  BangumiEpType type;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// sort
  @JsonKey(name: 'sort')
  double sort;

  /// ep
  @JsonKey(name: 'ep')
  double ep;

  /// airdate
  @JsonKey(name: 'airdate')
  String airDate;

  /// comment
  @JsonKey(name: 'comment')
  int comment;

  /// duration
  @JsonKey(name: 'duration')
  String duration;

  /// desc
  @JsonKey(name: 'desc')
  String desc;

  /// disc
  @JsonKey(name: 'disc')
  int disc;

  /// duration_seconds
  @JsonKey(name: 'duration_seconds')
  int durationSeconds;

  /// constructor
  BangumiEpisode({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.sort,
    required this.ep,
    required this.airDate,
    required this.comment,
    required this.duration,
    required this.desc,
    required this.disc,
    required this.durationSeconds,
  });

  /// from json
  factory BangumiEpisode.fromJson(Map<String, dynamic> json) =>
      _$BangumiEpisodeFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiEpisodeToJson(this);
}

/// EpisodeDetail
@JsonSerializable()
class BangumiEpisodeDetail {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  @JsonKey(name: 'type')
  BangumiEpType type;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// sort
  @JsonKey(name: 'sort')
  int sort;

  /// ep
  @JsonKey(name: 'ep')
  int ep;

  /// airdate
  @JsonKey(name: 'airdate')
  String airDate;

  /// comment
  @JsonKey(name: 'comment')
  int comment;

  /// duration
  @JsonKey(name: 'duration')
  String duration;

  /// desc
  @JsonKey(name: 'desc')
  String desc;

  /// disc
  @JsonKey(name: 'disc')
  int disc;

  /// subject_id
  @JsonKey(name: 'subject_id')
  int subjectId;

  /// constructor
  BangumiEpisodeDetail({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.sort,
    required this.ep,
    required this.airDate,
    required this.comment,
    required this.duration,
    required this.desc,
    required this.disc,
    required this.subjectId,
  });

  /// from json
  factory BangumiEpisodeDetail.fromJson(Map<String, dynamic> json) =>
      _$BangumiEpisodeDetailFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiEpisodeDetailToJson(this);
}

/// ErrorDetail
@JsonSerializable()
class BangumiErrorDetail {
  /// title
  @JsonKey(name: 'title')
  String title;

  /// description
  @JsonKey(name: 'description')
  String description;

  /// details
  /// 可能是 string，也可能是 {error:string, path:string}
  @JsonKey(name: 'details')
  dynamic details;

  /// constructor
  BangumiErrorDetail({
    required this.title,
    required this.description,
    required this.details,
  });

  /// from json
  factory BangumiErrorDetail.fromJson(Map<String, dynamic> json) =>
      _$BangumiErrorDetailFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiErrorDetailToJson(this);
}

/// oauthError
@JsonSerializable()
class BangumiErrorOauth {
  /// error
  @JsonKey(name: 'error')
  String error;

  /// error_description
  @JsonKey(name: 'error_description')
  String errorDescription;

  /// constructor
  BangumiErrorOauth({
    required this.error,
    required this.errorDescription,
  });

  /// from json
  factory BangumiErrorOauth.fromJson(Map<String, dynamic> json) =>
      _$BangumiErrorOauthFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiErrorOauthToJson(this);
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
  BangumiIndexBasicInfo1({
    required this.title,
    required this.description,
  });

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
  BangumiIndexBasicInfo3({
    required this.sort,
    required this.comment,
  });

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
  BangumiInfoBoxItem({
    required this.key,
    required this.value,
  });

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
  BangumiPage({
    required this.total,
    required this.limit,
    required this.offset,
  });

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
  ) =>
      _$BangumiPageTFromJson(json, fromJsonT);

  /// to json
  Map<String, dynamic> toJson(dynamic Function(T value) toJsonT) =>
      _$BangumiPageTToJson(this, toJsonT);
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
  BangumiStat({
    required this.comments,
    required this.collects,
  });

  /// from json
  factory BangumiStat.fromJson(Map<String, dynamic> json) =>
      _$BangumiStatFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiStatToJson(this);
}

/// Subject
@JsonSerializable(explicitToJson: true)
class BangumiSubject {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  @JsonKey(name: 'type')
  BangumiSubjectType type;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// summary
  @JsonKey(name: 'summary')
  String summary;

  /// nsfw
  @JsonKey(name: 'nsfw')
  bool nsfw;

  /// locked
  @JsonKey(name: 'locked')
  bool locked;

  /// date
  @JsonKey(name: 'date')
  String? date;

  /// platform
  @JsonKey(name: 'platform')
  String platform;

  /// images
  @JsonKey(name: 'images')
  BangumiImages images;

  /// infobox
  @JsonKey(name: 'infobox')
  List<BangumiInfoBoxItem> infobox;

  /// volumes
  @JsonKey(name: 'volumes')
  int volumes;

  /// eps
  @JsonKey(name: 'eps')
  int eps;

  /// total_episodes
  @JsonKey(name: 'total_episodes')
  int totalEpisodes;

  /// rating
  @JsonKey(name: 'rating')
  BangumiPatchRating rating;

  /// collection
  @JsonKey(name: 'collection')
  BangumiPatchCollection collection;

  /// tags
  @JsonKey(name: 'tags')
  List<BangumiTag> tags;

  /// constructor
  BangumiSubject({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.nsfw,
    required this.locked,
    required this.date,
    required this.platform,
    required this.images,
    required this.infobox,
    required this.volumes,
    required this.eps,
    required this.totalEpisodes,
    required this.rating,
    required this.collection,
    required this.tags,
  });

  /// from json
  factory BangumiSubject.fromJson(Map<String, dynamic> json) =>
      _$BangumiSubjectFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiSubjectToJson(this);
}

/// SlimSubject
@JsonSerializable(explicitToJson: true)
class BangumiSlimSubject {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  @JsonKey(name: 'type')
  BangumiSubjectType type;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// short_summary
  @JsonKey(name: 'short_summary')
  String shortSummary;

  /// date
  @JsonKey(name: 'date')
  String? date;

  /// images
  @JsonKey(name: 'images')
  BangumiImages images;

  /// volumes
  @JsonKey(name: 'volumes')
  int volumes;

  /// eps
  @JsonKey(name: 'eps')
  int eps;

  /// collection_total
  @JsonKey(name: 'collection_total')
  int collectionTotal;

  /// score
  @JsonKey(name: 'score')
  double score;

  /// tags
  @JsonKey(name: 'tags')
  List<BangumiTag> tags;

  /// constructor
  BangumiSlimSubject({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.shortSummary,
    required this.date,
    required this.images,
    required this.volumes,
    required this.eps,
    required this.collectionTotal,
    required this.score,
    required this.tags,
  });

  /// from json
  factory BangumiSlimSubject.fromJson(Map<String, dynamic> json) =>
      _$BangumiSlimSubjectFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiSlimSubjectToJson(this);
}

/// Tags
/// 因为本身是个列表，所以定义列表的内容
@JsonSerializable()
class BangumiTag {
  /// name
  @JsonKey(name: 'name')
  String name;

  /// count
  @JsonKey(name: 'count')
  int count;

  /// constructor
  BangumiTag({
    required this.name,
    required this.count,
  });

  /// from json
  factory BangumiTag.fromJson(Map<String, dynamic> json) =>
      _$BangumiTagFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiTagToJson(this);
}

/// UserSubjectCollection
@JsonSerializable(explicitToJson: true)
class BangumiUserSubjectCollection {
  /// subject_id
  @JsonKey(name: 'subject_id')
  int subjectId;

  /// subject_type
  @JsonKey(name: 'subject_type')
  BangumiSubjectType subjectType;

  /// rate
  @JsonKey(name: 'rate')
  int rate;

  /// type
  @JsonKey(name: 'type')
  BangumiCollectionType type;

  /// comment
  @JsonKey(name: 'comment')
  String? comment;

  /// tags
  @JsonKey(name: 'tags')
  List<String> tags;

  /// ep_status
  @JsonKey(name: 'ep_status')
  int epStatus;

  /// vol_status
  @JsonKey(name: 'vol_status')
  int volStatus;

  /// updated_at
  @JsonKey(name: 'updated_at')
  String updatedAt;

  /// private
  @JsonKey(name: 'private')
  bool private;

  /// subject
  @JsonKey(name: 'subject')
  BangumiSlimSubject subject;

  /// constructor
  BangumiUserSubjectCollection({
    required this.subjectId,
    required this.subjectType,
    required this.rate,
    required this.type,
    required this.comment,
    required this.tags,
    required this.epStatus,
    required this.volStatus,
    required this.updatedAt,
    required this.private,
    required this.subject,
  });

  /// from json
  factory BangumiUserSubjectCollection.fromJson(Map<String, dynamic> json) =>
      _$BangumiUserSubjectCollectionFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiUserSubjectCollectionToJson(this);

  /// toSqlJson
  /// 参照：libs/database/bangumi/bangumi_collection.dart的表格定义
  Map<String, dynamic> toSqlJson() {
    return {
      'subjectId': subjectId,
      'subjectType': subjectType.value,
      'rate': rate,
      'collectionType': type.value,
      'comment': comment,
      'tags': jsonEncode(tags),
      'epStat': epStatus,
      'volStat': volStatus,
      'updatedAt': updatedAt,
      'private': private ? 1 : 0,
      'subject': jsonEncode(subject.toJson()),
    };
  }

  /// fromSqlJson
  /// 参照：libs/database/bangumi/bangumi_collection.dart的表格定义
  factory BangumiUserSubjectCollection.fromSqlJson(Map<String, dynamic> json) {
    return BangumiUserSubjectCollection.fromJson({
      'subject_id': json['subjectId'],
      'subject_type': json['subjectType'],
      'rate': json['rate'],
      'type': json['collectionType'],
      'comment': json['comment'],
      'tags': jsonDecode(json['tags']),
      'ep_status': json['epStat'],
      'vol_status': json['volStat'],
      'updated_at': json['updatedAt'],
      'private': json['private'] == 1,
      'subject': jsonDecode(json['subject']),
    });
  }
}

/// UserSubjectCollectionModifyPayload
@JsonSerializable()
class BangumiUserSubjectCollectionModifyPayload {
  /// type
  @JsonKey(name: 'type')
  BangumiCollectionType type;

  /// rate
  @JsonKey(name: 'rate')
  int rate;

  /// ep_status
  @JsonKey(name: 'ep_status')
  int epStatus;

  /// vol_status
  @JsonKey(name: 'vol_status')
  int volStatus;

  /// comment
  @JsonKey(name: 'comment')
  String comment;

  /// private
  @JsonKey(name: 'private')
  bool private;

  /// tags
  @JsonKey(name: 'tags')
  List<String> tags;

  /// constructor
  BangumiUserSubjectCollectionModifyPayload({
    required this.type,
    required this.rate,
    required this.epStatus,
    required this.volStatus,
    required this.comment,
    required this.private,
    required this.tags,
  });

  /// from json
  factory BangumiUserSubjectCollectionModifyPayload.fromJson(
          Map<String, dynamic> json) =>
      _$BangumiUserSubjectCollectionModifyPayloadFromJson(json);

  /// to json
  Map<String, dynamic> toJson() =>
      _$BangumiUserSubjectCollectionModifyPayloadToJson(this);
}

/// UserEpisodeCollection
@JsonSerializable(explicitToJson: true)
class BangumiUserEpisodeCollection {
  /// episode
  @JsonKey(name: 'episode')
  BangumiEpisode episode;

  /// type
  @JsonKey(name: 'type')
  BangumiEpisodeCollectionType type;

  /// constructor
  BangumiUserEpisodeCollection({
    required this.episode,
    required this.type,
  });

  /// from json
  factory BangumiUserEpisodeCollection.fromJson(Map<String, dynamic> json) =>
      _$BangumiUserEpisodeCollectionFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiUserEpisodeCollectionToJson(this);
}

/// RelatedSubject
@JsonSerializable()
class BangumiRelatedSubject {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// staff
  @JsonKey(name: 'staff')
  String staff;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// image
  @JsonKey(name: 'image')
  String image;

  /// constructor
  BangumiRelatedSubject({
    required this.id,
    required this.staff,
    required this.name,
    required this.nameCn,
    required this.image,
  });

  /// from json
  factory BangumiRelatedSubject.fromJson(Map<String, dynamic> json) =>
      _$BangumiRelatedSubjectFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiRelatedSubjectToJson(this);
}

/// SubjectRelation
@JsonSerializable(explicitToJson: true)
class BangumiSubjectRelation {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// type
  @JsonKey(name: 'type')
  BangumiSubjectType type;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// name_cn
  @JsonKey(name: 'name_cn')
  String nameCn;

  /// images
  @JsonKey(name: 'images')
  BangumiImages images;

  /// relation
  @JsonKey(name: 'relation')
  String relation;

  /// constructor
  BangumiSubjectRelation({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.images,
    required this.relation,
  });

  /// from json
  factory BangumiSubjectRelation.fromJson(Map<String, dynamic> json) =>
      _$BangumiSubjectRelationFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiSubjectRelationToJson(this);
}
