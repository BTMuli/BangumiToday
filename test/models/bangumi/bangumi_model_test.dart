// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model_patch.dart';

void main() {
  T roundTrip<T>(
    T value,
    Map<String, dynamic> Function(T) toJson,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return fromJson(toJson(value));
  }

  BangumiPersonImages personImages({String prefix = 'img'}) {
    return BangumiPersonImages(
      large: '$prefix-large',
      medium: '$prefix-medium',
      small: '$prefix-small',
      grid: '$prefix-grid',
    );
  }

  BangumiImages images({String prefix = 'img'}) {
    return BangumiImages(
      large: '$prefix-large',
      common: '$prefix-common',
      medium: '$prefix-medium',
      small: '$prefix-small',
      grid: '$prefix-grid',
    );
  }

  BangumiPatchRating rating() {
    return BangumiPatchRating(
      total: 10,
      count: const {'1': 2},
      score: 7.5,
      rank: 3,
    );
  }

  BangumiPatchCollection collection() {
    return BangumiPatchCollection(
      wish: 1,
      collect: 2,
      doing: 3,
      onHold: 4,
      dropped: 5,
    );
  }

  group('legacy subject models', () {
    test('BangumiLegacySubjectSmall round trips', () {
      var value = BangumiLegacySubjectSmall(
        id: 1,
        url: 'https://bgm.tv/subject/1',
        type: BangumiLegacySubjectType.anime,
        name: 'name',
        nameCn: 'name_cn',
        summary: 'summary',
        airDate: '2026-01-01',
        airWeekday: 1,
        images: personImages(),
        eps: 12,
        epsCount: 12,
        rating: rating(),
        rank: 3,
        collection: collection(),
      );

      var restored = roundTrip(
        value,
        (v) => v.toJson(),
        BangumiLegacySubjectSmall.fromJson,
      );

      expect(restored.id, 1);
      expect(restored.type, BangumiLegacySubjectType.anime);
      expect(restored.images?.grid, 'img-grid');
      expect(restored.rating?.score, 7.5);
      expect(restored.collection?.doing, 3);
    });

    test('BangumiLegacyEpisode round trips enums', () {
      var value = BangumiLegacyEpisode(
        id: 1,
        url: 'https://bgm.tv/ep/1',
        type: BangumiLegacyEpisodeType.main,
        sort: 1,
        name: 'ep',
        nameCn: 'ep_cn',
        duration: '24:00',
        airDate: '2026-01-01',
        comment: 3,
        desc: 'desc',
        status: BangumiLegacyEpisodeStatusType.air,
      );

      var restored = roundTrip(
        value,
        (v) => v.toJson(),
        BangumiLegacyEpisode.fromJson,
      );

      expect(restored.type, BangumiLegacyEpisodeType.main);
      expect(restored.status, BangumiLegacyEpisodeStatusType.air);
      expect(restored.sort, 1);
    });

    test('BangumiLegacyMonoInfo round trips dynamic fields', () {
      var value = BangumiLegacyMonoInfo(
        birth: '1月1日',
        height: '152cm',
        gender: '女',
        alias: {'a': 'b'},
        source: ['source1', 'source2'],
        nameCn: '名字',
        cv: '声优',
      );

      var restored = roundTrip(
        value,
        (v) => v.toJson(),
        BangumiLegacyMonoInfo.fromJson,
      );

      expect(restored.alias['a'], 'b');
      expect(restored.source, ['source1', 'source2']);
      expect(restored.cv, '声优');
    });
  });

  test('BangumiUser round trips avatar and group', () {
    var value = BangumiUser(
      id: 1,
      username: 'user',
      nickname: '昵称',
      userGroup: BangumiLegacyUserGroupType.admin,
      avatar: BangumiAvatar(large: 'l', medium: 'm', small: 's'),
      sign: 'sign',
    );

    var restored = roundTrip(value, (v) => v.toJson(), BangumiUser.fromJson);

    expect(restored.userGroup, BangumiLegacyUserGroupType.admin);
    expect(restored.avatar.small, 's');
    expect(restored.username, 'user');
  });

  test('BangumiCharacterDetail round trips', () {
    var value = BangumiCharacterDetail(
      id: 1,
      name: '角色',
      type: BangumiCharacterType.character,
      images: personImages(),
      summary: 'summary',
      locked: false,
      infobox: 'infobox',
      gender: '女',
      bloodType: BangumiBloodType.o,
      birthYear: 2000,
      birthMon: 1,
      birthDay: 1,
      stat: BangumiStat(comments: 1, collects: 2),
    );

    var restored = roundTrip(
      value,
      (v) => v.toJson(),
      BangumiCharacterDetail.fromJson,
    );

    expect(restored.type, BangumiCharacterType.character);
    expect(restored.bloodType, BangumiBloodType.o);
    expect(restored.stat.collects, 2);
  });

  test('BangumiSubjectRevision round trips nested data', () {
    var value = BangumiSubjectRevision(
      id: 1,
      type: 2,
      creator: BangumiCreator(username: 'u', nickname: 'n'),
      summary: 'summary',
      createdAt: '2026-01-01',
      data: BangumiSubjectRevisionData(
        fieldEps: 12,
        fieldInfoBox: 'infobox',
        fieldSummary: 'summary',
        name: 'name',
        nameCn: 'name_cn',
        platform: 1,
        subjectId: 1,
        type: 2,
        typeId: 1,
        voteId: 1,
      ),
    );

    var restored = roundTrip(
      value,
      (v) => v.toJson(),
      BangumiSubjectRevision.fromJson,
    );

    expect(restored.creator.nickname, 'n');
    expect(restored.data.fieldEps, 12);
    expect(restored.data.subjectId, 1);
  });

  test('BangumiEpisode round trips ep type', () {
    var value = BangumiEpisode(
      id: 1,
      type: BangumiEpType.sp,
      name: 'ep',
      nameCn: 'ep_cn',
      sort: 1,
      ep: 1,
      airDate: '2026-01-01',
      comment: 0,
      duration: '24:00',
      desc: '',
      disc: 0,
      durationSeconds: 1440,
    );

    var restored = roundTrip(value, (v) => v.toJson(), BangumiEpisode.fromJson);

    expect(restored.type, BangumiEpType.sp);
    expect(restored.durationSeconds, 1440);
  });

  test('BangumiErrorOauth round trips', () {
    var value = BangumiErrorOauth(
      error: 'invalid_token',
      errorDescription: 'desc',
    );

    var restored = roundTrip(
      value,
      (v) => v.toJson(),
      BangumiErrorOauth.fromJson,
    );

    expect(restored.error, 'invalid_token');
    expect(restored.errorDescription, 'desc');
  });

  test('BangumiIndexSubject and generic page round trip', () {
    var item = BangumiIndexSubject(
      id: 1,
      type: BangumiSubjectType.anime,
      name: 'name',
      images: images(),
      infobox: [BangumiInfoBoxItem(key: 'k', value: 'v')],
      date: '2026-01-01',
      comment: 'comment',
      addedAt: '2026-01-01',
    );
    var page = BangumiPageT<BangumiIndexSubject>(
      total: 1,
      limit: 20,
      offset: 0,
      data: [item],
    );

    var restoredItem = roundTrip(
      item,
      (v) => v.toJson(),
      BangumiIndexSubject.fromJson,
    );
    var restoredPage = BangumiPageT<BangumiIndexSubject>.fromJson(
      page.toJson((value) => value.toJson()),
      (json) => BangumiIndexSubject.fromJson(json as Map<String, dynamic>),
    );

    expect(restoredItem.type, BangumiSubjectType.anime);
    expect(restoredItem.infobox.single.key, 'k');
    expect(restoredPage.total, 1);
    expect(restoredPage.data.single.name, 'name');
  });

  test('BangumiPerson and related character round trip', () {
    var person = BangumiPerson(
      id: 1,
      name: '声优',
      type: BangumiPersonType.person,
      career: BangumiPersonCareerType.seiyu,
      images: personImages(),
      shortSummary: 'summary',
      locked: false,
    );
    var related = BangumiRelatedCharacter(
      id: 1,
      name: '角色',
      type: BangumiCharacterType.character,
      images: personImages(),
      relation: '主角',
      actors: [person],
    );

    var restored = roundTrip(
      related,
      (v) => v.toJson(),
      BangumiRelatedCharacter.fromJson,
    );

    expect(restored.relation, '主角');
    expect(restored.actors.single.career, BangumiPersonCareerType.seiyu);
  });

  test('BangumiSubject round trips rating and tags', () {
    var value = BangumiSubject(
      id: 1,
      type: BangumiSubjectType.anime,
      name: 'name',
      nameCn: 'name_cn',
      summary: 'summary',
      nsfw: false,
      locked: false,
      date: '2026-01-01',
      platform: 'TV',
      images: images(),
      infobox: [BangumiInfoBoxItem(key: 'k', value: 'v')],
      volumes: 0,
      eps: 12,
      totalEpisodes: 12,
      rating: rating(),
      collection: collection(),
      tags: [BangumiTag(name: 'tag', count: 2)],
    );

    var restored = roundTrip(value, (v) => v.toJson(), BangumiSubject.fromJson);

    expect(restored.type, BangumiSubjectType.anime);
    expect(restored.rating.score, 7.5);
    expect(restored.tags.single.name, 'tag');
  });

  test('BangumiUserSubjectCollection round trips and sql json', () {
    var subject = BangumiSlimSubject(
      id: 1,
      type: BangumiSubjectType.anime,
      name: 'name',
      nameCn: 'name_cn',
      shortSummary: 'summary',
      date: '2026-01-01',
      images: images(),
      volumes: 0,
      eps: 12,
      collectionTotal: 10,
      score: 8.0,
      tags: [BangumiTag(name: 'tag', count: 2)],
    );
    var value = BangumiUserSubjectCollection(
      subjectId: 1,
      subjectType: BangumiSubjectType.anime,
      rate: 8,
      type: BangumiCollectionType.doing,
      comment: 'comment',
      tags: ['a', 'b'],
      epStatus: 3,
      volStatus: 0,
      updatedAt: '2026-01-01',
      private: false,
      subject: subject,
    );

    var restored = roundTrip(
      value,
      (v) => v.toJson(),
      BangumiUserSubjectCollection.fromJson,
    );
    var sqlRestored = BangumiUserSubjectCollection.fromSqlJson(
      value.toSqlJson(),
    );

    expect(restored.type, BangumiCollectionType.doing);
    expect(restored.subject.score, 8.0);
    expect(sqlRestored.subjectId, 1);
    expect(sqlRestored.subjectType, BangumiSubjectType.anime);
    expect(sqlRestored.tags, ['a', 'b']);
    expect(sqlRestored.subject.name, 'name');
  });
}
