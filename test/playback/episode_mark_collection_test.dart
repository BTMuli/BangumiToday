// Dart imports:
import 'dart:async';

// Package imports:
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/episode_mark_service.dart';
import 'package:bangumi_today/data/datasources/bangumi_local_data_source_impl.dart';
import 'package:bangumi_today/data/datasources/bangumi_remote_data_source.dart';
import 'package:bangumi_today/data/repositories/bangumi_repository_impl.dart';
import 'package:bangumi_today/data/repositories/episode_mark_gateway_impl.dart';
import 'package:bangumi_today/database/bangumi/bangumi_collection.dart';
import 'package:bangumi_today/database/drift/bt_database.dart';
import 'package:bangumi_today/domain/repositories/playback_episode_links.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';
import 'package:bangumi_today/models/playback/episode_mark_state.dart';
import 'package:bangumi_today/models/playback/playback_episode_link.dart';
import 'package:bangumi_today/models/playback/playback_episode_rule.dart';
import 'package:bangumi_today/models/playback/playback_item.dart';
import '../collections/collection_fixture.dart';

PlaybackItem _item(int number) => PlaybackItem(
  filePath: 'D:/Anime/536270/Show - $number.mkv',
  title: 'episode $number',
  subject: 536270,
);

BangumiEpisode _episode(
  int number, {
  BangumiEpType type = BangumiEpType.main,
}) => BangumiEpisode(
  id: 10000 + number,
  type: type,
  name: 'episode $number',
  nameCn: '',
  sort: number.toDouble(),
  ep: number.toDouble(),
  airDate: '',
  comment: 0,
  duration: '',
  desc: '',
  disc: 0,
  durationSeconds: 0,
);

class _Local extends BTBangumiLocalDataSourceImpl {
  _Local(BtDatabase database)
    : super(db: BtsBangumiCollection.forDatabase(database));
  int deletions = 0;
  bool failSave = false;

  @override
  Future<void> deleteCollection(int subjectId) async {
    deletions++;
    await super.deleteCollection(subjectId);
  }

  @override
  Future<void> updateCollection(BangumiUserSubjectCollection collection) async {
    if (failSave) throw StateError('local storage unavailable');
    await super.updateCollection(collection);
  }
}

class _Remote extends Fake implements BTBangumiRemoteDataSource {
  final done = <int>{};
  int episodeCount = 12;
  final episodeTypes = <int, BangumiEpType>{};
  final otherStatuses = <int, BangumiEpisodeCollectionType>{};
  bool failWrite = false;
  int writes = 0;
  int reads = 0;
  int progressReads = 0;
  int collectionReads = 0;

  @override
  Future<BTResponse<BangumiUserSubjectCollection>> getCollectionSubject(
    String username,
    int subjectId, {
    bool fresh = false,
    bool Function()? authScope,
  }) async {
    collectionReads++;
    return BTResponse.success(data: collectionFixture(epStatus: done.length));
  }

  BangumiUserEpisodeCollection progress(
    int number,
  ) => BangumiUserEpisodeCollection(
    episode: _episode(number, type: episodeTypes[number] ?? BangumiEpType.main),
    type: done.contains(10000 + number)
        ? BangumiEpisodeCollectionType.done
        : otherStatuses[10000 + number] ?? BangumiEpisodeCollectionType.none,
  );

  @override
  Future<BTResponse<BangumiPageT<BangumiUserEpisodeCollection>>>
  getCollectionEpisodes(
    int subjectId, {
    int? offset,
    int? limit,
    BangumiLegacyEpisodeType? type,
  }) async {
    progressReads++;
    return BTResponse.success(
      data: BangumiPageT(
        total: episodeCount,
        limit: 100,
        offset: 0,
        data: List.generate(episodeCount, (index) => progress(index + 1)),
      ),
    );
  }

  @override
  Future<BTResponse<BangumiUserEpisodeCollection>> getCollectionEpisode(
    int episodeId,
  ) async {
    reads++;
    return BTResponse.success(data: progress(episodeId - 10000));
  }

  @override
  Future<BTResponse<void>> updateCollectionEpisode({
    required BangumiEpisodeCollectionType type,
    required int episode,
    bool Function()? authScope,
  }) async {
    expect(authScope?.call(), isTrue);
    expect(type, BangumiEpisodeCollectionType.done);
    writes++;
    if (!failWrite) done.add(episode);
    return BTResponse(
      code: failWrite ? 502 : 0,
      message: failWrite ? 'server unavailable' : 'success',
      data: null,
    );
  }
}

class _Links extends Fake implements PlaybackEpisodeLinks {
  @override
  Future<Map<String, PlaybackEpisodeLink>> readAll() async => {};

  @override
  Stream<Map<String, PlaybackEpisodeLink>> watchAll() => const Stream.empty();

  @override
  Future<List<PlaybackEpisodeRule>> readRules() async => [];

  @override
  Stream<List<PlaybackEpisodeRule>> watchRules() => const Stream.empty();
}

void main() {
  late BtDatabase db;
  late _Local local;
  late _Remote remote;
  late EpisodeMarkService service;

  setUp(() {
    db = BtDatabase(NativeDatabase.memory());
    local = _Local(db);
    remote = _Remote();
    service = EpisodeMarkService(
      gateway: BangumiEpisodeMarkGateway(
        BTBangumiRepositoryImpl(
          remoteDataSource: remote,
          localDataSource: local,
          accountSession: () => (username: 'test', generation: 1),
        ),
      ),
      accountSession: () => 'test:1',
      links: _Links(),
    );
  });

  tearDown(() async {
    service.close();
    await db.close();
  });

  for (var concurrent in [false, true]) {
    test('${concurrent ? '并发' : '连续'}标记12集仅发送12次写入并保存完整本地进度', () async {
      await local.insertCollection(collectionFixture(epStatus: 0));
      var before = await db.select(db.bangumiCollection).getSingle();
      var items = List.generate(12, (index) => _item(index + 1));
      await service.syncItems(items);
      var results = <EpisodeMarkWriteResult>[];
      if (concurrent) {
        results = await Future.wait(items.map(service.mark));
      } else {
        for (var item in items) {
          results.add(await service.mark(item));
        }
      }
      expect(
        results.map((result) => result.status),
        everyElement(EpisodeMarkWriteStatus.marked),
      );
      expect(results.map((result) => result.message), everyElement(isNull));
      expect(remote.writes, 12);
      expect(remote.reads, 0);
      expect(remote.progressReads, 1);
      expect(remote.collectionReads, 0);
      expect(local.deletions, 0);
      var after = await db.select(db.bangumiCollection).getSingle();
      expect(after.toJson(), {...before.toJson(), 'epStat': 12});
      expect(service.knownProgress(536270).values, everyElement(isTrue));
      expect(
        (await service.mark(items.first)).status,
        EpisodeMarkWriteStatus.alreadyDone,
      );
      expect(remote.writes, 12);
      expect(remote.reads, 0);
    });
  }

  for (var scenario in [
    (name: '标记章节成功', done: false, fail: false, saveFails: false),
    (name: '已看过章节', done: true, fail: false, saveFails: false),
    (name: '标记章节失败', done: false, fail: true, saveFails: false),
    (name: '标记成功但本地保存失败', done: false, fail: false, saveFails: true),
  ]) {
    test('${scenario.name}保留收藏元数据且不请求远程刷新', () async {
      await local.insertCollection(collectionFixture());
      var before = await db.select(db.bangumiCollection).getSingle();
      remote.done.add(10001);
      if (scenario.done) remote.done.add(10002);
      remote.failWrite = scenario.fail;
      local.failSave = scenario.saveFails;
      await service.syncItems([_item(2)]);
      var result = await service.mark(_item(2));
      expect(
        result.status,
        scenario.fail
            ? EpisodeMarkWriteStatus.failed
            : scenario.done
            ? EpisodeMarkWriteStatus.alreadyDone
            : EpisodeMarkWriteStatus.marked,
      );
      expect(local.deletions, 0);
      expect(
        remote.writes,
        scenario.done
            ? 0
            : scenario.fail
            ? 3
            : 1,
      );
      var after = await db.select(db.bangumiCollection).getSingle();
      var expected = before.toJson();
      if (!scenario.done && !scenario.fail && !scenario.saveFails) {
        expected['epStat'] = 2;
      }
      expect(after.toJson(), expected);
      expect(remote.collectionReads, 0);
      expect(remote.reads, scenario.fail ? 3 : 0);
      expect(
        result.message,
        scenario.saveFails || scenario.fail ? isNotNull : isNull,
      );
      expect(service.knownProgress(536270)[10002], !scenario.fail);
    });
  }

  test('本地没有收藏记录时不额外读取远程或构造缺失元数据', () async {
    await service.syncItems([_item(2)]);
    expect(
      (await service.mark(_item(2))).status,
      EpisodeMarkWriteStatus.marked,
    );
    expect(await local.getCollection(536270), isNull);
    expect(remote.writes, 1);
    expect(remote.collectionReads, 0);
    expect(remote.reads, 0);
  });

  test('按整数播出编号自动匹配特别篇并标记看过', () async {
    await local.insertCollection(collectionFixture(epStatus: 0));
    remote.episodeCount = 13;
    remote.episodeTypes[13] = BangumiEpType.sp;
    var item = _item(13);

    await service.syncItems([item]);
    expect(
      service.progressState.checked,
      contains(EpisodeMarkState.itemKey(item)),
    );
    expect((await service.mark(item)).status, EpisodeMarkWriteStatus.marked);
    expect(
      service.progressState.marked,
      contains(EpisodeMarkState.itemKey(item)),
    );
    expect((await local.getCollection(536270))!.epStatus, 1);
    expect(remote.done, {10013});
    expect(remote.writes, 1);
    expect(remote.progressReads, 1);
    expect(remote.reads, 0);
  });

  test('本地收藏计数与服务端一致，包含特别篇及其他非空状态', () async {
    await local.insertCollection(collectionFixture());
    remote.episodeCount = 13;
    remote.episodeTypes[13] = BangumiEpType.sp;
    remote.otherStatuses[10003] = BangumiEpisodeCollectionType.wish;
    await service.syncItems([_item(1)]);
    var special = service
        .knownChapters(536270)!
        .singleWhere((episode) => episode.id == 10013);
    var specialResult = await service.confirm(
      EpisodeMarkCandidate(
        item: _item(13),
        account: 'test:1',
        episode: special,
        number: 13,
      ),
    );
    expect(specialResult.status, EpisodeMarkWriteStatus.marked);
    expect((await local.getCollection(536270))!.epStatus, 2);
    expect(
      (await service.mark(_item(1))).status,
      EpisodeMarkWriteStatus.marked,
    );
    expect((await local.getCollection(536270))!.epStatus, 3);
    expect(remote.writes, 2);
    expect(remote.reads, 0);
    expect(remote.collectionReads, 0);
  });
}
