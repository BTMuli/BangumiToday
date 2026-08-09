// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import 'bangumi_enum.dart';
import 'bangumi_model_patch.dart';
import 'bangumi_model_person.dart';
import 'bangumi_model_user.dart';

part 'bangumi_model_legacy.g.dart';

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
