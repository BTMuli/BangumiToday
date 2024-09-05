// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiLegacySubjectSmall _$BangumiLegacySubjectSmallFromJson(
        Map<String, dynamic> json) =>
    BangumiLegacySubjectSmall(
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
          : BangumiPersonImages.fromJson(
              json['images'] as Map<String, dynamic>),
      eps: (json['eps'] as num?)?.toInt(),
      epsCount: (json['eps_count'] as num?)?.toInt(),
      rating: json['rating'] == null
          ? null
          : BangumiPatchRating.fromJson(json['rating'] as Map<String, dynamic>),
      rank: (json['rank'] as num?)?.toInt(),
      collection: json['collection'] == null
          ? null
          : BangumiPatchCollection.fromJson(
              json['collection'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BangumiLegacySubjectSmallToJson(
        BangumiLegacySubjectSmall instance) =>
    <String, dynamic>{
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
        Map<String, dynamic> json) =>
    BangumiLegacySubjectCharacter(
      id: (json['id'] as num).toInt(),
      url: json['url'] as String,
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      images:
          BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
      comment: (json['comment'] as num).toInt(),
      collects: (json['collects'] as num).toInt(),
      info:
          BangumiLegacyMonoInfo.fromJson(json['info'] as Map<String, dynamic>),
      actors: (json['actors'] as List<dynamic>)
          .map((e) => BangumiLegacyMonoBase.fromJson(e as Map<String, dynamic>))
          .toList(),
      roleName: json['role_name'] as String,
    );

Map<String, dynamic> _$BangumiLegacySubjectCharacterToJson(
        BangumiLegacySubjectCharacter instance) =>
    <String, dynamic>{
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
        Map<String, dynamic> json) =>
    BangumiLegacySubjectStaff(
      id: (json['id'] as num).toInt(),
      url: json['url'] as String,
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      images:
          BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
      comment: (json['comment'] as num).toInt(),
      collects: (json['collects'] as num).toInt(),
      info:
          BangumiLegacyMonoInfo.fromJson(json['info'] as Map<String, dynamic>),
      roleName: json['role_name'] as String,
      jobs: (json['jobs'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$BangumiLegacySubjectStaffToJson(
        BangumiLegacySubjectStaff instance) =>
    <String, dynamic>{
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
        Map<String, dynamic> json) =>
    BangumiLegacySubjectMedium(
      crt: (json['crt'] as List<dynamic>)
          .map((e) =>
              BangumiLegacySubjectCharacter.fromJson(e as Map<String, dynamic>))
          .toList(),
      staff: (json['staff'] as List<dynamic>)
          .map((e) =>
              BangumiLegacySubjectStaff.fromJson(e as Map<String, dynamic>))
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
          : BangumiPersonImages.fromJson(
              json['images'] as Map<String, dynamic>),
      eps: (json['eps'] as num?)?.toInt(),
      epsCount: (json['eps_count'] as num?)?.toInt(),
      rating: json['rating'] == null
          ? null
          : BangumiPatchRating.fromJson(json['rating'] as Map<String, dynamic>),
      rank: (json['rank'] as num?)?.toInt(),
      collection: json['collection'] == null
          ? null
          : BangumiPatchCollection.fromJson(
              json['collection'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BangumiLegacySubjectMediumToJson(
        BangumiLegacySubjectMedium instance) =>
    <String, dynamic>{
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
        Map<String, dynamic> json) =>
    BangumiLegacySubjectLarge(
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
          : BangumiPersonImages.fromJson(
              json['images'] as Map<String, dynamic>),
      eps: (json['eps'] as num?)?.toInt(),
      epsCount: (json['eps_count'] as num?)?.toInt(),
      rating: json['rating'] == null
          ? null
          : BangumiPatchRating.fromJson(json['rating'] as Map<String, dynamic>),
      rank: (json['rank'] as num?)?.toInt(),
      collection: json['collection'] == null
          ? null
          : BangumiPatchCollection.fromJson(
              json['collection'] as Map<String, dynamic>),
      crt: (json['crt'] as List<dynamic>)
          .map((e) =>
              BangumiLegacySubjectCharacter.fromJson(e as Map<String, dynamic>))
          .toList(),
      staff: (json['staff'] as List<dynamic>)
          .map((e) =>
              BangumiLegacySubjectStaff.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BangumiLegacySubjectLargeToJson(
        BangumiLegacySubjectLarge instance) =>
    <String, dynamic>{
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
        Map<String, dynamic> json) =>
    BangumiLegacyEpisode(
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
      status:
          $enumDecode(_$BangumiLegacyEpisodeStatusTypeEnumMap, json['status']),
    );

Map<String, dynamic> _$BangumiLegacyEpisodeToJson(
        BangumiLegacyEpisode instance) =>
    <String, dynamic>{
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
      userGroup:
          $enumDecode(_$BangumiLegacyUserGroupTypeEnumMap, json['usergroup']),
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

BangumiLegacyPerson _$BangumiLegacyPersonFromJson(Map<String, dynamic> json) =>
    BangumiLegacyPerson(
      id: (json['id'] as num).toInt(),
      url: json['url'] as String,
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      images:
          BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
      comment: (json['comment'] as num).toInt(),
      collects: (json['collects'] as num).toInt(),
      info:
          BangumiLegacyMonoInfo.fromJson(json['info'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BangumiLegacyPersonToJson(
        BangumiLegacyPerson instance) =>
    <String, dynamic>{
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
        Map<String, dynamic> json) =>
    BangumiLegacyCharacter(
      id: (json['id'] as num).toInt(),
      url: json['url'] as String,
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      images:
          BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
      comment: (json['comment'] as num).toInt(),
      collects: (json['collects'] as num).toInt(),
      info:
          BangumiLegacyMonoInfo.fromJson(json['info'] as Map<String, dynamic>),
      actors: (json['actors'] as List<dynamic>)
          .map((e) => BangumiLegacyMonoBase.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BangumiLegacyCharacterToJson(
        BangumiLegacyCharacter instance) =>
    <String, dynamic>{
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
        Map<String, dynamic> json) =>
    BangumiLegacyMonoBase(
      id: (json['id'] as num).toInt(),
      url: json['url'] as String,
      name: json['name'] as String,
      images:
          BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BangumiLegacyMonoBaseToJson(
        BangumiLegacyMonoBase instance) =>
    <String, dynamic>{
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
      images:
          BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
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
        Map<String, dynamic> json) =>
    BangumiLegacyMonoInfo(
      birth: json['birth'] as String,
      height: json['height'] as String,
      gender: json['gender'] as String,
      alias: json['alias'] as Map<String, dynamic>,
      source: json['source'],
      nameCn: json['name_cn'] as String,
      cv: json['cv'] as String,
    );

Map<String, dynamic> _$BangumiLegacyMonoInfoToJson(
        BangumiLegacyMonoInfo instance) =>
    <String, dynamic>{
      'birth': instance.birth,
      'height': instance.height,
      'gender': instance.gender,
      'alias': instance.alias,
      'source': instance.source,
      'name_cn': instance.nameCn,
      'cv': instance.cv,
    };

BangumiUser _$BangumiUserFromJson(Map<String, dynamic> json) => BangumiUser(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      nickname: json['nickname'] as String,
      userGroup:
          $enumDecode(_$BangumiLegacyUserGroupTypeEnumMap, json['user_group']),
      avatar: BangumiAvatar.fromJson(json['avatar'] as Map<String, dynamic>),
      sign: json['sign'] as String,
    );

Map<String, dynamic> _$BangumiUserToJson(BangumiUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'nickname': instance.nickname,
      'user_group': _$BangumiLegacyUserGroupTypeEnumMap[instance.userGroup]!,
      'avatar': instance.avatar.toJson(),
      'sign': instance.sign,
    };

BangumiAvatar _$BangumiAvatarFromJson(Map<String, dynamic> json) =>
    BangumiAvatar(
      large: json['large'] as String,
      medium: json['medium'] as String,
      small: json['small'] as String,
    );

Map<String, dynamic> _$BangumiAvatarToJson(BangumiAvatar instance) =>
    <String, dynamic>{
      'large': instance.large,
      'medium': instance.medium,
      'small': instance.small,
    };

BangumiCharacterDetail _$BangumiCharacterDetailFromJson(
        Map<String, dynamic> json) =>
    BangumiCharacterDetail(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: $enumDecode(_$BangumiCharacterTypeEnumMap, json['type']),
      images:
          BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
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
        BangumiCharacterDetail instance) =>
    <String, dynamic>{
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
        Map<String, dynamic> json) =>
    BangumiCharacterPerson(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: $enumDecode(_$BangumiCharacterTypeEnumMap, json['type']),
      images:
          BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
      subjectId: (json['subject_id'] as num).toInt(),
      subjectName: json['subject_name'] as String,
      subjectNameCn: json['subject_name_cn'] as String,
      staff: json['staff'] as String,
    );

Map<String, dynamic> _$BangumiCharacterPersonToJson(
        BangumiCharacterPerson instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': _$BangumiCharacterTypeEnumMap[instance.type]!,
      'images': instance.images.toJson(),
      'subject_id': instance.subjectId,
      'subject_name': instance.subjectName,
      'subject_name_cn': instance.subjectNameCn,
      'staff': instance.staff,
    };

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

BangumiDetailedRevision _$BangumiDetailedRevisionFromJson(
        Map<String, dynamic> json) =>
    BangumiDetailedRevision(
      id: (json['id'] as num).toInt(),
      type: (json['type'] as num).toInt(),
      creator: BangumiCreator.fromJson(json['creator'] as Map<String, dynamic>),
      summary: json['summary'] as String,
      createdAt: json['created_at'] as String,
      data: json['data'],
    );

Map<String, dynamic> _$BangumiDetailedRevisionToJson(
        BangumiDetailedRevision instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'creator': instance.creator.toJson(),
      'summary': instance.summary,
      'created_at': instance.createdAt,
      'data': instance.data,
    };

BangumiPersonRevision _$BangumiPersonRevisionFromJson(
        Map<String, dynamic> json) =>
    BangumiPersonRevision(
      id: (json['id'] as num).toInt(),
      type: (json['type'] as num).toInt(),
      creator: BangumiCreator.fromJson(json['creator'] as Map<String, dynamic>),
      summary: json['summary'] as String,
      createdAt: json['created_at'] as String,
      data: (json['data'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k,
            BangumiPersonRevisionDataItem.fromJson(e as Map<String, dynamic>)),
      ),
    );

Map<String, dynamic> _$BangumiPersonRevisionToJson(
        BangumiPersonRevision instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'creator': instance.creator.toJson(),
      'summary': instance.summary,
      'created_at': instance.createdAt,
      'data': instance.data.map((k, e) => MapEntry(k, e.toJson())),
    };

BangumiPersonRevisionDataItem _$BangumiPersonRevisionDataItemFromJson(
        Map<String, dynamic> json) =>
    BangumiPersonRevisionDataItem(
      personInfoBox: json['prsn_infobox'] as String,
      personSummary: json['prsn_summary'] as String,
      profession: BangumiPersonRevisionProfession.fromJson(
          json['profession'] as Map<String, dynamic>),
      extra:
          BangumiRevisionExtra.fromJson(json['extra'] as Map<String, dynamic>),
      personName: json['prsn_name'] as String,
    );

Map<String, dynamic> _$BangumiPersonRevisionDataItemToJson(
        BangumiPersonRevisionDataItem instance) =>
    <String, dynamic>{
      'prsn_infobox': instance.personInfoBox,
      'prsn_summary': instance.personSummary,
      'profession': instance.profession.toJson(),
      'extra': instance.extra.toJson(),
      'prsn_name': instance.personName,
    };

BangumiPersonRevisionProfession _$BangumiPersonRevisionProfessionFromJson(
        Map<String, dynamic> json) =>
    BangumiPersonRevisionProfession(
      producer: json['producer'] as String,
      mangaka: json['mangaka'] as String,
      artist: json['artist'] as String,
      seiyu: json['seiyu'] as String,
      writer: json['writer'] as String,
      illustrator: json['illustrator'] as String,
      actor: json['actor'] as String,
    );

Map<String, dynamic> _$BangumiPersonRevisionProfessionToJson(
        BangumiPersonRevisionProfession instance) =>
    <String, dynamic>{
      'producer': instance.producer,
      'mangaka': instance.mangaka,
      'artist': instance.artist,
      'seiyu': instance.seiyu,
      'writer': instance.writer,
      'illustrator': instance.illustrator,
      'actor': instance.actor,
    };

BangumiRevisionExtra _$BangumiRevisionExtraFromJson(
        Map<String, dynamic> json) =>
    BangumiRevisionExtra(
      img: json['img'] as String,
    );

Map<String, dynamic> _$BangumiRevisionExtraToJson(
        BangumiRevisionExtra instance) =>
    <String, dynamic>{
      'img': instance.img,
    };

BangumiSubjectRevision _$BangumiSubjectRevisionFromJson(
        Map<String, dynamic> json) =>
    BangumiSubjectRevision(
      id: (json['id'] as num).toInt(),
      type: (json['type'] as num).toInt(),
      creator: BangumiCreator.fromJson(json['creator'] as Map<String, dynamic>),
      summary: json['summary'] as String,
      createdAt: json['created_at'] as String,
      data: BangumiSubjectRevisionData.fromJson(
          json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BangumiSubjectRevisionToJson(
        BangumiSubjectRevision instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'creator': instance.creator.toJson(),
      'summary': instance.summary,
      'created_at': instance.createdAt,
      'data': instance.data.toJson(),
    };

BangumiSubjectRevisionData _$BangumiSubjectRevisionDataFromJson(
        Map<String, dynamic> json) =>
    BangumiSubjectRevisionData(
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
        BangumiSubjectRevisionData instance) =>
    <String, dynamic>{
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
        Map<String, dynamic> json) =>
    BangumiCharacterRevision(
      id: (json['id'] as num).toInt(),
      type: (json['type'] as num).toInt(),
      creator: BangumiCreator.fromJson(json['creator'] as Map<String, dynamic>),
      summary: json['summary'] as String,
      createdAt: json['created_at'] as String,
      data: (json['data'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
            k,
            BangumiCharacterRevisionDataItem.fromJson(
                e as Map<String, dynamic>)),
      ),
    );

Map<String, dynamic> _$BangumiCharacterRevisionToJson(
        BangumiCharacterRevision instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'creator': instance.creator.toJson(),
      'summary': instance.summary,
      'created_at': instance.createdAt,
      'data': instance.data.map((k, e) => MapEntry(k, e.toJson())),
    };

BangumiCharacterRevisionDataItem _$BangumiCharacterRevisionDataItemFromJson(
        Map<String, dynamic> json) =>
    BangumiCharacterRevisionDataItem(
      infoBox: json['infobox'] as String,
      summary: json['summary'] as String,
      name: json['name'] as String,
      extra:
          BangumiRevisionExtra.fromJson(json['extra'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BangumiCharacterRevisionDataItemToJson(
        BangumiCharacterRevisionDataItem instance) =>
    <String, dynamic>{
      'infobox': instance.infoBox,
      'summary': instance.summary,
      'name': instance.name,
      'extra': instance.extra.toJson(),
    };

BangumiEpisode _$BangumiEpisodeFromJson(Map<String, dynamic> json) =>
    BangumiEpisode(
      id: (json['id'] as num).toInt(),
      type: $enumDecode(_$BangumiEpTypeEnumMap, json['type']),
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      sort: (json['sort'] as num).toDouble(),
      ep: (json['ep'] as num).toDouble(),
      airDate: json['airdate'] as String,
      comment: (json['comment'] as num).toInt(),
      duration: json['duration'] as String,
      desc: json['desc'] as String,
      disc: (json['disc'] as num).toInt(),
      durationSeconds: (json['duration_seconds'] as num).toInt(),
    );

Map<String, dynamic> _$BangumiEpisodeToJson(BangumiEpisode instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$BangumiEpTypeEnumMap[instance.type]!,
      'name': instance.name,
      'name_cn': instance.nameCn,
      'sort': instance.sort,
      'ep': instance.ep,
      'airdate': instance.airDate,
      'comment': instance.comment,
      'duration': instance.duration,
      'desc': instance.desc,
      'disc': instance.disc,
      'duration_seconds': instance.durationSeconds,
    };

const _$BangumiEpTypeEnumMap = {
  BangumiEpType.main: 0,
  BangumiEpType.sp: 1,
  BangumiEpType.op: 2,
  BangumiEpType.ed: 3,
  BangumiEpType.cm: 4,
  BangumiEpType.mad: 5,
  BangumiEpType.other: 6,
};

BangumiEpisodeDetail _$BangumiEpisodeDetailFromJson(
        Map<String, dynamic> json) =>
    BangumiEpisodeDetail(
      id: (json['id'] as num).toInt(),
      type: $enumDecode(_$BangumiEpTypeEnumMap, json['type']),
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      sort: (json['sort'] as num).toInt(),
      ep: (json['ep'] as num).toInt(),
      airDate: json['airdate'] as String,
      comment: (json['comment'] as num).toInt(),
      duration: json['duration'] as String,
      desc: json['desc'] as String,
      disc: (json['disc'] as num).toInt(),
      subjectId: (json['subject_id'] as num).toInt(),
    );

Map<String, dynamic> _$BangumiEpisodeDetailToJson(
        BangumiEpisodeDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$BangumiEpTypeEnumMap[instance.type]!,
      'name': instance.name,
      'name_cn': instance.nameCn,
      'sort': instance.sort,
      'ep': instance.ep,
      'airdate': instance.airDate,
      'comment': instance.comment,
      'duration': instance.duration,
      'desc': instance.desc,
      'disc': instance.disc,
      'subject_id': instance.subjectId,
    };

BangumiErrorDetail _$BangumiErrorDetailFromJson(Map<String, dynamic> json) =>
    BangumiErrorDetail(
      title: json['error'] as String,
      description: json['error_description'] as String,
      details: json['details'],
    );

Map<String, dynamic> _$BangumiErrorDetailToJson(BangumiErrorDetail instance) =>
    <String, dynamic>{
      'error': instance.title,
      'error_description': instance.description,
      'details': instance.details,
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

BangumiIndex _$BangumiIndexFromJson(Map<String, dynamic> json) => BangumiIndex(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      desc: json['desc'] as String,
      total: (json['total'] as num).toInt(),
      stat: BangumiStat.fromJson(json['stat'] as Map<String, dynamic>),
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      creator: BangumiCreator.fromJson(json['creator'] as Map<String, dynamic>),
      nsfw: json['nsfw'] as bool,
    );

Map<String, dynamic> _$BangumiIndexToJson(BangumiIndex instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'desc': instance.desc,
      'total': instance.total,
      'stat': instance.stat.toJson(),
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'creator': instance.creator.toJson(),
      'nsfw': instance.nsfw,
    };

BangumiIndexSubject _$BangumiIndexSubjectFromJson(Map<String, dynamic> json) =>
    BangumiIndexSubject(
      id: (json['id'] as num).toInt(),
      type: $enumDecode(_$BangumiSubjectTypeEnumMap, json['type']),
      name: json['name'] as String,
      images: BangumiImages.fromJson(json['images'] as Map<String, dynamic>),
      infobox: (json['infobox'] as List<dynamic>)
          .map((e) => BangumiInfoBoxItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      date: json['date'] as String,
      comment: json['comment'] as String,
      addedAt: json['added_at'] as String,
    );

Map<String, dynamic> _$BangumiIndexSubjectToJson(
        BangumiIndexSubject instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$BangumiSubjectTypeEnumMap[instance.type]!,
      'name': instance.name,
      'images': instance.images.toJson(),
      'infobox': instance.infobox.map((e) => e.toJson()).toList(),
      'date': instance.date,
      'comment': instance.comment,
      'added_at': instance.addedAt,
    };

const _$BangumiSubjectTypeEnumMap = {
  BangumiSubjectType.book: 1,
  BangumiSubjectType.anime: 2,
  BangumiSubjectType.music: 3,
  BangumiSubjectType.game: 4,
  BangumiSubjectType.real: 6,
};

BangumiIndexBasicInfo1 _$BangumiIndexBasicInfo1FromJson(
        Map<String, dynamic> json) =>
    BangumiIndexBasicInfo1(
      title: json['title'] as String,
      description: json['description'] as String,
    );

Map<String, dynamic> _$BangumiIndexBasicInfo1ToJson(
        BangumiIndexBasicInfo1 instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
    };

BangumiIndexBasicInfo2 _$BangumiIndexBasicInfo2FromJson(
        Map<String, dynamic> json) =>
    BangumiIndexBasicInfo2(
      subjectId: (json['subject_id'] as num).toInt(),
      sort: (json['sort'] as num).toInt(),
      comment: json['comment'] as String,
    );

Map<String, dynamic> _$BangumiIndexBasicInfo2ToJson(
        BangumiIndexBasicInfo2 instance) =>
    <String, dynamic>{
      'subject_id': instance.subjectId,
      'sort': instance.sort,
      'comment': instance.comment,
    };

BangumiIndexBasicInfo3 _$BangumiIndexBasicInfo3FromJson(
        Map<String, dynamic> json) =>
    BangumiIndexBasicInfo3(
      sort: (json['sort'] as num).toInt(),
      comment: json['comment'] as String,
    );

Map<String, dynamic> _$BangumiIndexBasicInfo3ToJson(
        BangumiIndexBasicInfo3 instance) =>
    <String, dynamic>{
      'sort': instance.sort,
      'comment': instance.comment,
    };

BangumiInfoBoxItem _$BangumiInfoBoxItemFromJson(Map<String, dynamic> json) =>
    BangumiInfoBoxItem(
      key: json['key'] as String,
      value: json['value'],
    );

Map<String, dynamic> _$BangumiInfoBoxItemToJson(BangumiInfoBoxItem instance) =>
    <String, dynamic>{
      'key': instance.key,
      'value': instance.value,
    };

BangumiPage _$BangumiPageFromJson(Map<String, dynamic> json) => BangumiPage(
      total: (json['total'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
      offset: (json['offset'] as num).toInt(),
    );

Map<String, dynamic> _$BangumiPageToJson(BangumiPage instance) =>
    <String, dynamic>{
      'total': instance.total,
      'limit': instance.limit,
      'offset': instance.offset,
    };

BangumiPageT<T> _$BangumiPageTFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) =>
    BangumiPageT<T>(
      total: (json['total'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
      offset: (json['offset'] as num).toInt(),
      data: (json['data'] as List<dynamic>).map(fromJsonT).toList(),
    );

Map<String, dynamic> _$BangumiPageTToJson<T>(
  BangumiPageT<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      'total': instance.total,
      'limit': instance.limit,
      'offset': instance.offset,
      'data': instance.data.map(toJsonT).toList(),
    };

BangumiPerson _$BangumiPersonFromJson(Map<String, dynamic> json) =>
    BangumiPerson(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: $enumDecode(_$BangumiPersonTypeEnumMap, json['type']),
      career: $enumDecode(_$BangumiPersonCareerTypeEnumMap, json['career']),
      images:
          BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
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
        Map<String, dynamic> json) =>
    BangumiPersonCharacter(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: $enumDecode(_$BangumiCharacterTypeEnumMap, json['type']),
      images:
          BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
      subjectId: (json['subject_id'] as num).toInt(),
      subjectName: json['subject_name'] as String,
      subjectNameCn: json['subject_name_cn'] as String,
      staff: json['staff'] as String,
    );

Map<String, dynamic> _$BangumiPersonCharacterToJson(
        BangumiPersonCharacter instance) =>
    <String, dynamic>{
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
      images:
          BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
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
        BangumiPersonDetail instance) =>
    <String, dynamic>{
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
        BangumiPersonImages instance) =>
    <String, dynamic>{
      'large': instance.large,
      'medium': instance.medium,
      'small': instance.small,
      'grid': instance.grid,
    };

BangumiRelatedCharacter _$BangumiRelatedCharacterFromJson(
        Map<String, dynamic> json) =>
    BangumiRelatedCharacter(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: $enumDecode(_$BangumiCharacterTypeEnumMap, json['type']),
      images:
          BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
      relation: json['relation'] as String,
      actors: (json['actors'] as List<dynamic>)
          .map((e) => BangumiPerson.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BangumiRelatedCharacterToJson(
        BangumiRelatedCharacter instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': _$BangumiCharacterTypeEnumMap[instance.type]!,
      'images': instance.images.toJson(),
      'relation': instance.relation,
      'actors': instance.actors.map((e) => e.toJson()).toList(),
    };

BangumiRelatedPerson _$BangumiRelatedPersonFromJson(
        Map<String, dynamic> json) =>
    BangumiRelatedPerson(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: $enumDecode(_$BangumiPersonTypeEnumMap, json['type']),
      career: $enumDecode(_$BangumiPersonCareerTypeEnumMap, json['career']),
      images:
          BangumiPersonImages.fromJson(json['images'] as Map<String, dynamic>),
      relation: json['relation'] as String,
    );

Map<String, dynamic> _$BangumiRelatedPersonToJson(
        BangumiRelatedPerson instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': _$BangumiPersonTypeEnumMap[instance.type]!,
      'career': _$BangumiPersonCareerTypeEnumMap[instance.career]!,
      'images': instance.images.toJson(),
      'relation': instance.relation,
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

BangumiStat _$BangumiStatFromJson(Map<String, dynamic> json) => BangumiStat(
      comments: (json['comments'] as num).toInt(),
      collects: (json['collects'] as num).toInt(),
    );

Map<String, dynamic> _$BangumiStatToJson(BangumiStat instance) =>
    <String, dynamic>{
      'comments': instance.comments,
      'collects': instance.collects,
    };

BangumiSubject _$BangumiSubjectFromJson(Map<String, dynamic> json) =>
    BangumiSubject(
      id: (json['id'] as num).toInt(),
      type: $enumDecode(_$BangumiSubjectTypeEnumMap, json['type']),
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      summary: json['summary'] as String,
      nsfw: json['nsfw'] as bool,
      locked: json['locked'] as bool,
      date: json['date'] as String?,
      platform: json['platform'] as String,
      images: BangumiImages.fromJson(json['images'] as Map<String, dynamic>),
      infobox: (json['infobox'] as List<dynamic>)
          .map((e) => BangumiInfoBoxItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      volumes: (json['volumes'] as num).toInt(),
      eps: (json['eps'] as num).toInt(),
      totalEpisodes: (json['total_episodes'] as num).toInt(),
      rating:
          BangumiPatchRating.fromJson(json['rating'] as Map<String, dynamic>),
      collection: BangumiPatchCollection.fromJson(
          json['collection'] as Map<String, dynamic>),
      tags: (json['tags'] as List<dynamic>)
          .map((e) => BangumiTag.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BangumiSubjectToJson(BangumiSubject instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$BangumiSubjectTypeEnumMap[instance.type]!,
      'name': instance.name,
      'name_cn': instance.nameCn,
      'summary': instance.summary,
      'nsfw': instance.nsfw,
      'locked': instance.locked,
      'date': instance.date,
      'platform': instance.platform,
      'images': instance.images.toJson(),
      'infobox': instance.infobox.map((e) => e.toJson()).toList(),
      'volumes': instance.volumes,
      'eps': instance.eps,
      'total_episodes': instance.totalEpisodes,
      'rating': instance.rating.toJson(),
      'collection': instance.collection.toJson(),
      'tags': instance.tags.map((e) => e.toJson()).toList(),
    };

BangumiSlimSubject _$BangumiSlimSubjectFromJson(Map<String, dynamic> json) =>
    BangumiSlimSubject(
      id: (json['id'] as num).toInt(),
      type: $enumDecode(_$BangumiSubjectTypeEnumMap, json['type']),
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      shortSummary: json['short_summary'] as String,
      date: json['date'] as String?,
      images: BangumiImages.fromJson(json['images'] as Map<String, dynamic>),
      volumes: (json['volumes'] as num).toInt(),
      eps: (json['eps'] as num).toInt(),
      collectionTotal: (json['collection_total'] as num).toInt(),
      score: (json['score'] as num).toDouble(),
      tags: (json['tags'] as List<dynamic>)
          .map((e) => BangumiTag.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BangumiSlimSubjectToJson(BangumiSlimSubject instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$BangumiSubjectTypeEnumMap[instance.type]!,
      'name': instance.name,
      'name_cn': instance.nameCn,
      'short_summary': instance.shortSummary,
      'date': instance.date,
      'images': instance.images.toJson(),
      'volumes': instance.volumes,
      'eps': instance.eps,
      'collection_total': instance.collectionTotal,
      'score': instance.score,
      'tags': instance.tags.map((e) => e.toJson()).toList(),
    };

BangumiTag _$BangumiTagFromJson(Map<String, dynamic> json) => BangumiTag(
      name: json['name'] as String,
      count: (json['count'] as num).toInt(),
    );

Map<String, dynamic> _$BangumiTagToJson(BangumiTag instance) =>
    <String, dynamic>{
      'name': instance.name,
      'count': instance.count,
    };

BangumiUserSubjectCollection _$BangumiUserSubjectCollectionFromJson(
        Map<String, dynamic> json) =>
    BangumiUserSubjectCollection(
      subjectId: (json['subject_id'] as num).toInt(),
      subjectType:
          $enumDecode(_$BangumiSubjectTypeEnumMap, json['subject_type']),
      rate: (json['rate'] as num).toInt(),
      type: $enumDecode(_$BangumiCollectionTypeEnumMap, json['type']),
      comment: json['comment'] as String?,
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      epStatus: (json['ep_status'] as num).toInt(),
      volStatus: (json['vol_status'] as num).toInt(),
      updatedAt: json['updated_at'] as String,
      private: json['private'] as bool,
      subject:
          BangumiSlimSubject.fromJson(json['subject'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BangumiUserSubjectCollectionToJson(
        BangumiUserSubjectCollection instance) =>
    <String, dynamic>{
      'subject_id': instance.subjectId,
      'subject_type': _$BangumiSubjectTypeEnumMap[instance.subjectType]!,
      'rate': instance.rate,
      'type': _$BangumiCollectionTypeEnumMap[instance.type]!,
      'comment': instance.comment,
      'tags': instance.tags,
      'ep_status': instance.epStatus,
      'vol_status': instance.volStatus,
      'updated_at': instance.updatedAt,
      'private': instance.private,
      'subject': instance.subject.toJson(),
    };

const _$BangumiCollectionTypeEnumMap = {
  BangumiCollectionType.unknown: 0,
  BangumiCollectionType.wish: 1,
  BangumiCollectionType.collect: 2,
  BangumiCollectionType.doing: 3,
  BangumiCollectionType.onHold: 4,
  BangumiCollectionType.dropped: 5,
};

BangumiUserSubjectCollectionModifyPayload
    _$BangumiUserSubjectCollectionModifyPayloadFromJson(
            Map<String, dynamic> json) =>
        BangumiUserSubjectCollectionModifyPayload(
          type: $enumDecode(_$BangumiCollectionTypeEnumMap, json['type']),
          rate: (json['rate'] as num).toInt(),
          epStatus: (json['ep_status'] as num).toInt(),
          volStatus: (json['vol_status'] as num).toInt(),
          comment: json['comment'] as String,
          private: json['private'] as bool,
          tags:
              (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
        );

Map<String, dynamic> _$BangumiUserSubjectCollectionModifyPayloadToJson(
        BangumiUserSubjectCollectionModifyPayload instance) =>
    <String, dynamic>{
      'type': _$BangumiCollectionTypeEnumMap[instance.type]!,
      'rate': instance.rate,
      'ep_status': instance.epStatus,
      'vol_status': instance.volStatus,
      'comment': instance.comment,
      'private': instance.private,
      'tags': instance.tags,
    };

BangumiUserEpisodeCollection _$BangumiUserEpisodeCollectionFromJson(
        Map<String, dynamic> json) =>
    BangumiUserEpisodeCollection(
      episode: BangumiEpisode.fromJson(json['episode'] as Map<String, dynamic>),
      type: $enumDecode(_$BangumiEpisodeCollectionTypeEnumMap, json['type']),
    );

Map<String, dynamic> _$BangumiUserEpisodeCollectionToJson(
        BangumiUserEpisodeCollection instance) =>
    <String, dynamic>{
      'episode': instance.episode.toJson(),
      'type': _$BangumiEpisodeCollectionTypeEnumMap[instance.type]!,
    };

const _$BangumiEpisodeCollectionTypeEnumMap = {
  BangumiEpisodeCollectionType.none: 0,
  BangumiEpisodeCollectionType.wish: 1,
  BangumiEpisodeCollectionType.done: 2,
  BangumiEpisodeCollectionType.dropped: 3,
};

BangumiRelatedSubject _$BangumiRelatedSubjectFromJson(
        Map<String, dynamic> json) =>
    BangumiRelatedSubject(
      id: (json['id'] as num).toInt(),
      staff: json['staff'] as String,
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      image: json['image'] as String,
    );

Map<String, dynamic> _$BangumiRelatedSubjectToJson(
        BangumiRelatedSubject instance) =>
    <String, dynamic>{
      'id': instance.id,
      'staff': instance.staff,
      'name': instance.name,
      'name_cn': instance.nameCn,
      'image': instance.image,
    };

BangumiSubjectRelation _$BangumiSubjectRelationFromJson(
        Map<String, dynamic> json) =>
    BangumiSubjectRelation(
      id: (json['id'] as num).toInt(),
      type: $enumDecode(_$BangumiSubjectTypeEnumMap, json['type']),
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      images: BangumiImages.fromJson(json['images'] as Map<String, dynamic>),
      relation: json['relation'] as String,
    );

Map<String, dynamic> _$BangumiSubjectRelationToJson(
        BangumiSubjectRelation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$BangumiSubjectTypeEnumMap[instance.type]!,
      'name': instance.name,
      'name_cn': instance.nameCn,
      'images': instance.images.toJson(),
      'relation': instance.relation,
    };
