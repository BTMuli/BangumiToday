// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_model_legacy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiLegacySubjectSmall _$BangumiLegacySubjectSmallFromJson(
  Map<String, dynamic> json,
) => BangumiLegacySubjectSmall(
  id: (json['id'] as num).toInt(),
  url: json['url'] as String,
  type: $enumDecode(_$BangumiLegacySubjectTypeEnumMap, json['type']),
  name: json['name'] as String,
  nameCn: json['name_cn'] as String,
  summary: json['summary'] as String,
  airDate: json['air_date'] as String,
  airWeekday: (json['air_weekday'] as num).toInt(),
  images: json['images'] == null
      ? null
      : BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
  eps: (json['eps'] as num?)?.toInt(),
  epsCount: (json['eps_count'] as num?)?.toInt(),
  rating: json['rating'] == null
      ? null
      : BangumiPatchRating.fromJson(json['rating'] as Map<String, dynamic>),
  rank: (json['rank'] as num?)?.toInt(),
  collection: json['collection'] == null
      ? null
      : BangumiPatchCollection.fromJson(
          json['collection'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$BangumiLegacySubjectSmallToJson(
  BangumiLegacySubjectSmall instance,
) => <String, dynamic>{
  'id': instance.id,
  'url': instance.url,
  'type': _$BangumiLegacySubjectTypeEnumMap[instance.type]!,
  'name': instance.name,
  'name_cn': instance.nameCn,
  'summary': instance.summary,
  'air_date': instance.airDate,
  'air_weekday': instance.airWeekday,
  'images': instance.images?.toJson(),
  'eps': instance.eps,
  'eps_count': instance.epsCount,
  'rating': instance.rating?.toJson(),
  'rank': instance.rank,
  'collection': instance.collection?.toJson(),
};

const _$BangumiLegacySubjectTypeEnumMap = {
  BangumiLegacySubjectType.book: 1,
  BangumiLegacySubjectType.anime: 2,
  BangumiLegacySubjectType.music: 3,
  BangumiLegacySubjectType.game: 4,
  BangumiLegacySubjectType.real: 6,
};

BangumiLegacySubjectCharacter _$BangumiLegacySubjectCharacterFromJson(
  Map<String, dynamic> json,
) => BangumiLegacySubjectCharacter(
  id: (json['id'] as num).toInt(),
  url: json['url'] as String,
  name: json['name'] as String,
  nameCn: json['name_cn'] as String,
  images: BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
  comment: (json['comment'] as num).toInt(),
  collects: (json['collects'] as num).toInt(),
  info: BangumiLegacyMonoInfo.fromJson(json['info'] as Map<String, dynamic>),
  actors: (json['actors'] as List<dynamic>)
      .map((e) => BangumiLegacyMonoBase.fromJson(e as Map<String, dynamic>))
      .toList(),
  roleName: json['role_name'] as String,
);

Map<String, dynamic> _$BangumiLegacySubjectCharacterToJson(
  BangumiLegacySubjectCharacter instance,
) => <String, dynamic>{
  'id': instance.id,
  'url': instance.url,
  'name': instance.name,
  'name_cn': instance.nameCn,
  'images': instance.images.toJson(),
  'comment': instance.comment,
  'collects': instance.collects,
  'info': instance.info.toJson(),
  'actors': instance.actors.map((e) => e.toJson()).toList(),
  'role_name': instance.roleName,
};

BangumiLegacySubjectStaff _$BangumiLegacySubjectStaffFromJson(
  Map<String, dynamic> json,
) => BangumiLegacySubjectStaff(
  id: (json['id'] as num).toInt(),
  url: json['url'] as String,
  name: json['name'] as String,
  nameCn: json['name_cn'] as String,
  images: BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
  comment: (json['comment'] as num).toInt(),
  collects: (json['collects'] as num).toInt(),
  info: BangumiLegacyMonoInfo.fromJson(json['info'] as Map<String, dynamic>),
  roleName: json['role_name'] as String,
  jobs: (json['jobs'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$BangumiLegacySubjectStaffToJson(
  BangumiLegacySubjectStaff instance,
) => <String, dynamic>{
  'id': instance.id,
  'url': instance.url,
  'name': instance.name,
  'name_cn': instance.nameCn,
  'images': instance.images.toJson(),
  'comment': instance.comment,
  'collects': instance.collects,
  'info': instance.info.toJson(),
  'role_name': instance.roleName,
  'jobs': instance.jobs,
};

BangumiLegacySubjectMedium _$BangumiLegacySubjectMediumFromJson(
  Map<String, dynamic> json,
) => BangumiLegacySubjectMedium(
  crt: (json['crt'] as List<dynamic>)
      .map(
        (e) =>
            BangumiLegacySubjectCharacter.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
  staff: (json['staff'] as List<dynamic>)
      .map((e) => BangumiLegacySubjectStaff.fromJson(e as Map<String, dynamic>))
      .toList(),
  id: (json['id'] as num).toInt(),
  url: json['url'] as String,
  type: $enumDecode(_$BangumiLegacySubjectTypeEnumMap, json['type']),
  name: json['name'] as String,
  nameCn: json['name_cn'] as String,
  summary: json['summary'] as String,
  airDate: json['air_date'] as String,
  airWeekday: (json['air_weekday'] as num).toInt(),
  images: json['images'] == null
      ? null
      : BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
  eps: (json['eps'] as num?)?.toInt(),
  epsCount: (json['eps_count'] as num?)?.toInt(),
  rating: json['rating'] == null
      ? null
      : BangumiPatchRating.fromJson(json['rating'] as Map<String, dynamic>),
  rank: (json['rank'] as num?)?.toInt(),
  collection: json['collection'] == null
      ? null
      : BangumiPatchCollection.fromJson(
          json['collection'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$BangumiLegacySubjectMediumToJson(
  BangumiLegacySubjectMedium instance,
) => <String, dynamic>{
  'crt': instance.crt.map((e) => e.toJson()).toList(),
  'staff': instance.staff.map((e) => e.toJson()).toList(),
  'id': instance.id,
  'url': instance.url,
  'type': _$BangumiLegacySubjectTypeEnumMap[instance.type]!,
  'name': instance.name,
  'name_cn': instance.nameCn,
  'summary': instance.summary,
  'air_date': instance.airDate,
  'air_weekday': instance.airWeekday,
  'images': instance.images?.toJson(),
  'eps': instance.eps,
  'eps_count': instance.epsCount,
  'rating': instance.rating?.toJson(),
  'rank': instance.rank,
  'collection': instance.collection?.toJson(),
};

BangumiLegacySubjectLarge _$BangumiLegacySubjectLargeFromJson(
  Map<String, dynamic> json,
) => BangumiLegacySubjectLarge(
  topic: (json['topic'] as List<dynamic>)
      .map((e) => BangumiLegacyTopic.fromJson(e as Map<String, dynamic>))
      .toList(),
  blog: (json['blog'] as List<dynamic>)
      .map((e) => BangumiLegacyBlog.fromJson(e as Map<String, dynamic>))
      .toList(),
  id: (json['id'] as num).toInt(),
  url: json['url'] as String,
  type: $enumDecode(_$BangumiLegacySubjectTypeEnumMap, json['type']),
  name: json['name'] as String,
  nameCn: json['name_cn'] as String,
  summary: json['summary'] as String,
  airDate: json['air_date'] as String,
  airWeekday: (json['air_weekday'] as num).toInt(),
  images: json['images'] == null
      ? null
      : BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
  eps: (json['eps'] as num?)?.toInt(),
  epsCount: (json['eps_count'] as num?)?.toInt(),
  rating: json['rating'] == null
      ? null
      : BangumiPatchRating.fromJson(json['rating'] as Map<String, dynamic>),
  rank: (json['rank'] as num?)?.toInt(),
  collection: json['collection'] == null
      ? null
      : BangumiPatchCollection.fromJson(
          json['collection'] as Map<String, dynamic>,
        ),
  crt: (json['crt'] as List<dynamic>)
      .map(
        (e) =>
            BangumiLegacySubjectCharacter.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
  staff: (json['staff'] as List<dynamic>)
      .map((e) => BangumiLegacySubjectStaff.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$BangumiLegacySubjectLargeToJson(
  BangumiLegacySubjectLarge instance,
) => <String, dynamic>{
  'topic': instance.topic.map((e) => e.toJson()).toList(),
  'blog': instance.blog.map((e) => e.toJson()).toList(),
  'id': instance.id,
  'url': instance.url,
  'type': _$BangumiLegacySubjectTypeEnumMap[instance.type]!,
  'name': instance.name,
  'name_cn': instance.nameCn,
  'summary': instance.summary,
  'air_date': instance.airDate,
  'air_weekday': instance.airWeekday,
  'images': instance.images?.toJson(),
  'eps': instance.eps,
  'eps_count': instance.epsCount,
  'rating': instance.rating?.toJson(),
  'rank': instance.rank,
  'collection': instance.collection?.toJson(),
  'crt': instance.crt.map((e) => e.toJson()).toList(),
  'staff': instance.staff.map((e) => e.toJson()).toList(),
};

BangumiLegacyEpisode _$BangumiLegacyEpisodeFromJson(
  Map<String, dynamic> json,
) => BangumiLegacyEpisode(
  id: (json['id'] as num).toInt(),
  url: json['url'] as String,
  type: $enumDecode(_$BangumiLegacyEpisodeTypeEnumMap, json['type']),
  sort: (json['sort'] as num).toInt(),
  name: json['name'] as String,
  nameCn: json['name_cn'] as String,
  duration: json['duration'] as String,
  airDate: json['airdate'] as String,
  comment: (json['comment'] as num).toInt(),
  desc: json['desc'] as String,
  status: $enumDecode(_$BangumiLegacyEpisodeStatusTypeEnumMap, json['status']),
);

Map<String, dynamic> _$BangumiLegacyEpisodeToJson(
  BangumiLegacyEpisode instance,
) => <String, dynamic>{
  'id': instance.id,
  'url': instance.url,
  'type': _$BangumiLegacyEpisodeTypeEnumMap[instance.type]!,
  'sort': instance.sort,
  'name': instance.name,
  'name_cn': instance.nameCn,
  'duration': instance.duration,
  'airdate': instance.airDate,
  'comment': instance.comment,
  'desc': instance.desc,
  'status': _$BangumiLegacyEpisodeStatusTypeEnumMap[instance.status]!,
};

const _$BangumiLegacyEpisodeTypeEnumMap = {
  BangumiLegacyEpisodeType.main: 0,
  BangumiLegacyEpisodeType.sp: 1,
  BangumiLegacyEpisodeType.op: 2,
  BangumiLegacyEpisodeType.ed: 3,
  BangumiLegacyEpisodeType.cm: 4,
  BangumiLegacyEpisodeType.mad: 5,
  BangumiLegacyEpisodeType.other: 6,
};

const _$BangumiLegacyEpisodeStatusTypeEnumMap = {
  BangumiLegacyEpisodeStatusType.air: 'Air',
  BangumiLegacyEpisodeStatusType.today: 'Today',
  BangumiLegacyEpisodeStatusType.na: 'NA',
};

BangumiLegacyTopic _$BangumiLegacyTopicFromJson(Map<String, dynamic> json) =>
    BangumiLegacyTopic(
      id: (json['id'] as num).toInt(),
      url: json['url'] as String,
      title: json['title'] as String,
      mainId: (json['main_id'] as num).toInt(),
      timestamp: (json['timestamp'] as num).toInt(),
      lastPost: (json['lastpost'] as num).toInt(),
      replies: (json['replies'] as num).toInt(),
      user: BangumiLegacyUser.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BangumiLegacyTopicToJson(BangumiLegacyTopic instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'title': instance.title,
      'main_id': instance.mainId,
      'timestamp': instance.timestamp,
      'lastpost': instance.lastPost,
      'replies': instance.replies,
      'user': instance.user.toJson(),
    };

BangumiLegacyBlog _$BangumiLegacyBlogFromJson(Map<String, dynamic> json) =>
    BangumiLegacyBlog(
      id: (json['id'] as num).toInt(),
      url: json['url'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      image: json['image'] as String,
      replies: (json['replies'] as num).toInt(),
      timestamp: (json['timestamp'] as num).toInt(),
      dateline: json['dateline'] as String,
      user: BangumiLegacyUser.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BangumiLegacyBlogToJson(BangumiLegacyBlog instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'title': instance.title,
      'summary': instance.summary,
      'image': instance.image,
      'replies': instance.replies,
      'timestamp': instance.timestamp,
      'dateline': instance.dateline,
      'user': instance.user.toJson(),
    };

BangumiLegacyUser _$BangumiLegacyUserFromJson(Map<String, dynamic> json) =>
    BangumiLegacyUser(
      id: (json['id'] as num).toInt(),
      url: json['url'] as String,
      username: json['username'] as String,
      nickname: json['nickname'] as String,
      avatar: BangumiAvatar.fromJson(json['avatar'] as Map<String, dynamic>),
      sign: json['sign'] as String,
      userGroup: $enumDecode(
        _$BangumiLegacyUserGroupTypeEnumMap,
        json['usergroup'],
      ),
    );

Map<String, dynamic> _$BangumiLegacyUserToJson(BangumiLegacyUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'username': instance.username,
      'nickname': instance.nickname,
      'avatar': instance.avatar.toJson(),
      'sign': instance.sign,
      'usergroup': _$BangumiLegacyUserGroupTypeEnumMap[instance.userGroup]!,
    };

const _$BangumiLegacyUserGroupTypeEnumMap = {
  BangumiLegacyUserGroupType.admin: 1,
  BangumiLegacyUserGroupType.bangumiAdmin: 2,
  BangumiLegacyUserGroupType.windowAdmin: 3,
  BangumiLegacyUserGroupType.mutedUser: 4,
  BangumiLegacyUserGroupType.bannedUser: 5,
  BangumiLegacyUserGroupType.personAdmin: 8,
  BangumiLegacyUserGroupType.wikiAdmin: 9,
  BangumiLegacyUserGroupType.user: 10,
  BangumiLegacyUserGroupType.wikiUser: 11,
};

BangumiLegacyPerson _$BangumiLegacyPersonFromJson(
  Map<String, dynamic> json,
) => BangumiLegacyPerson(
  id: (json['id'] as num).toInt(),
  url: json['url'] as String,
  name: json['name'] as String,
  nameCn: json['name_cn'] as String,
  images: BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
  comment: (json['comment'] as num).toInt(),
  collects: (json['collects'] as num).toInt(),
  info: BangumiLegacyMonoInfo.fromJson(json['info'] as Map<String, dynamic>),
);

Map<String, dynamic> _$BangumiLegacyPersonToJson(
  BangumiLegacyPerson instance,
) => <String, dynamic>{
  'id': instance.id,
  'url': instance.url,
  'name': instance.name,
  'name_cn': instance.nameCn,
  'images': instance.images.toJson(),
  'comment': instance.comment,
  'collects': instance.collects,
  'info': instance.info.toJson(),
};

BangumiLegacyCharacter _$BangumiLegacyCharacterFromJson(
  Map<String, dynamic> json,
) => BangumiLegacyCharacter(
  id: (json['id'] as num).toInt(),
  url: json['url'] as String,
  name: json['name'] as String,
  nameCn: json['name_cn'] as String,
  images: BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
  comment: (json['comment'] as num).toInt(),
  collects: (json['collects'] as num).toInt(),
  info: BangumiLegacyMonoInfo.fromJson(json['info'] as Map<String, dynamic>),
  actors: (json['actors'] as List<dynamic>)
      .map((e) => BangumiLegacyMonoBase.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$BangumiLegacyCharacterToJson(
  BangumiLegacyCharacter instance,
) => <String, dynamic>{
  'id': instance.id,
  'url': instance.url,
  'name': instance.name,
  'name_cn': instance.nameCn,
  'images': instance.images.toJson(),
  'comment': instance.comment,
  'collects': instance.collects,
  'info': instance.info.toJson(),
  'actors': instance.actors.map((e) => e.toJson()).toList(),
};

BangumiLegacyMonoBase _$BangumiLegacyMonoBaseFromJson(
  Map<String, dynamic> json,
) => BangumiLegacyMonoBase(
  id: (json['id'] as num).toInt(),
  url: json['url'] as String,
  name: json['name'] as String,
  images: BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
);

Map<String, dynamic> _$BangumiLegacyMonoBaseToJson(
  BangumiLegacyMonoBase instance,
) => <String, dynamic>{
  'id': instance.id,
  'url': instance.url,
  'name': instance.name,
  'images': instance.images.toJson(),
};

BangumiLegacyMono _$BangumiLegacyMonoFromJson(Map<String, dynamic> json) =>
    BangumiLegacyMono(
      id: (json['id'] as num).toInt(),
      url: json['url'] as String,
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      images: BangumiPersonImages.fromJson(
        json['images'] as Map<String, dynamic>,
      ),
      comment: (json['comment'] as num).toInt(),
      collects: (json['collects'] as num).toInt(),
    );

Map<String, dynamic> _$BangumiLegacyMonoToJson(BangumiLegacyMono instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'name': instance.name,
      'name_cn': instance.nameCn,
      'images': instance.images.toJson(),
      'comment': instance.comment,
      'collects': instance.collects,
    };

BangumiLegacyMonoInfo _$BangumiLegacyMonoInfoFromJson(
  Map<String, dynamic> json,
) => BangumiLegacyMonoInfo(
  birth: json['birth'] as String,
  height: json['height'] as String,
  gender: json['gender'] as String,
  alias: json['alias'] as Map<String, dynamic>,
  source: json['source'],
  nameCn: json['name_cn'] as String,
  cv: json['cv'] as String,
);

Map<String, dynamic> _$BangumiLegacyMonoInfoToJson(
  BangumiLegacyMonoInfo instance,
) => <String, dynamic>{
  'birth': instance.birth,
  'height': instance.height,
  'gender': instance.gender,
  'alias': instance.alias,
  'source': instance.source,
  'name_cn': instance.nameCn,
  'cv': instance.cv,
};
