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
import 'package:bangumi_today/domain/repositories/episode_mark_gateway.dart';
import 'package:bangumi_today/domain/repositories/playback_episode_links.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';
import 'package:bangumi_today/models/playback/playback_episode_link.dart';
import 'package:bangumi_today/models/playback/playback_episode_rule.dart';
import 'package:bangumi_today/models/playback/playback_item.dart';
import '../collections/collection_fixture.dart';

class _Local extends BTBangumiLocalDataSourceImpl {
  _Local(BtDatabase database)
    : super(db: BtsBangumiCollection.forDatabase(database));
  int deletions = 0;

  @override
  Future<void> deleteCollection(int subjectId) async {
    deletions++;
    await super.deleteCollection(subjectId);
  }
}

class _Remote extends Fake implements BTBangumiRemoteDataSource {
  _Remote({
    required this.done,
    required this.failWrite,
    this.failRefresh = false,
  });
  bool done;
  final bool failWrite;
  final bool failRefresh;
  int writes = 0;
  int refreshes = 0;

  @override
  Future<BTResponse<BangumiUserSubjectCollection>> getCollectionSubject(
    String username,
    int subjectId, {
    bool fresh = false,
    bool Function()? authScope,
  }) async {
    expect(fresh, isTrue);
    expect(authScope?.call(), isTrue);
    refreshes++;
    return failRefresh
        ? BTResponse(code: 404, message: 'temporarily unavailable', data: null)
        : BTResponse.success(data: collectionFixture(epStatus: 2));
  }

  @override
  Future<BTResponse<BangumiUserEpisodeCollection>> getCollectionEpisode(
    int episodeId,
  ) async => BTResponse.success(
    data: BangumiUserEpisodeCollection(
      episode: BangumiEpisode(
        id: episodeId,
        type: BangumiEpType.main,
        name: 'episode 2',
        nameCn: '',
        sort: 2,
        ep: 2,
        airDate: '',
        comment: 0,
        duration: '',
        desc: '',
        disc: 0,
        durationSeconds: 0,
      ),
      type: done
          ? BangumiEpisodeCollectionType.done
          : BangumiEpisodeCollectionType.none,
    ),
  );

  @override
  Future<BTResponse<void>> updateCollectionEpisode({
    required BangumiEpisodeCollectionType type,
    required int episode,
    bool Function()? authScope,
  }) async {
    expect(authScope?.call(), isTrue);
    expect(type, BangumiEpisodeCollectionType.done);
    writes++;
    if (!failWrite) done = true;
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

class _ConcurrentRemote extends _Remote {
  _ConcurrentRemote() : super(done: false, failWrite: false);

  final marked = <int>{};
  final pendingRefreshes = <({Completer<void> gate, int progress})>[];

  @override
  Future<BTResponse<BangumiUserEpisodeCollection>> getCollectionEpisode(
    int episodeId,
  ) async {
    var response = await super.getCollectionEpisode(episodeId);
    response.data!.type = marked.contains(episodeId)
        ? BangumiEpisodeCollectionType.done
        : BangumiEpisodeCollectionType.none;
    return response;
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
    marked.add(episode);
    return BTResponse(code: 0, message: 'success', data: null);
  }

  @override
  Future<BTResponse<BangumiUserSubjectCollection>> getCollectionSubject(
    String username,
    int subjectId, {
    bool fresh = false,
    bool Function()? authScope,
  }) async {
    expect(fresh, isTrue);
    expect(authScope?.call(), isTrue);
    refreshes++;
    var pending = (gate: Completer<void>(), progress: marked.length);
    pendingRefreshes.add(pending);
    await pending.gate.future;
    return BTResponse.success(
      data: collectionFixture(epStatus: pending.progress),
    );
  }
}

void main() {
  test('连续标记不同章节时收藏进度刷新不互相失效，并保留最后一次进度', () async {
    var db = BtDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    var local = _Local(db);
    await local.insertCollection(collectionFixture());
    var remote = _ConcurrentRemote();
    var service = EpisodeMarkService(
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
    addTearDown(service.close);
    Future<EpisodeMarkWriteResult> mark(int number) => service.confirm(
      EpisodeMarkCandidate(
        item: PlaybackItem(
          filePath: 'D:/Anime/536270/$number.mkv',
          title: 'episode $number',
          subject: 536270,
        ),
        account: 'test:1',
        episode: EpisodeMarkEpisode(
          id: 10000 + number,
          type: 0,
          sort: number.toDouble(),
          name: 'episode $number',
        ),
        number: number.toDouble(),
      ),
    );

    var first = mark(2);
    await pumpEventQueue();
    expect(remote.pendingRefreshes.single.progress, 1);
    var pending = [first, mark(3), mark(4)];
    await pumpEventQueue();
    expect(remote.marked, {10002, 10003, 10004});
    // Each response reflects progress when its request started. A refresh
    // queued after a later mark must fetch again rather than reuse the first.
    for (var index = 0; index < pending.length; index++) {
      await pumpEventQueue();
      remote.pendingRefreshes[index].gate.complete();
      await pending[index];
    }
    var results = await Future.wait(pending);
    expect(
      results.map((result) => result.status),
      everyElement(EpisodeMarkWriteStatus.marked),
    );
    expect(results.map((result) => result.message), everyElement(isNull));
    expect(remote.writes, 3);
    expect(local.deletions, 0);
    expect((await local.getCollection(536270))!.epStatus, 3);
  });

  for (var scenario in [
    (name: '标记章节成功', done: false, fail: false, refreshFails: false),
    (name: '确认章节已看过', done: true, fail: false, refreshFails: false),
    (name: '标记章节失败', done: false, fail: true, refreshFails: false),
    (name: '标记成功但进度刷新失败', done: false, fail: false, refreshFails: true),
  ]) {
    test('${scenario.name}后保留条目收藏，仅在成功时通知刷新', () async {
      var db = BtDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var local = _Local(db);
      await local.insertCollection(collectionFixture());
      var before = await db.select(db.bangumiCollection).getSingle();
      var remote = _Remote(
        done: scenario.done,
        failWrite: scenario.fail,
        failRefresh: scenario.refreshFails,
      );
      var service = EpisodeMarkService(
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
      addTearDown(service.close);
      var events = <EpisodeMarkRefresh>[];
      var subscription = service.refreshes.listen(events.add);
      addTearDown(subscription.cancel);
      var result = await service.confirm(
        const EpisodeMarkCandidate(
          item: PlaybackItem(
            filePath: 'D:/Anime/536270/02.mkv',
            title: 'episode 2',
            subject: 536270,
          ),
          account: 'test:1',
          episode: EpisodeMarkEpisode(
            id: 10002,
            type: 0,
            sort: 2,
            name: 'episode 2',
          ),
          number: 2,
        ),
      );
      await Future<void>.delayed(Duration.zero);
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
      if (!scenario.fail && !scenario.refreshFails) expected['epStat'] = 2;
      expect(after.toJson(), expected);
      expect(remote.refreshes, scenario.fail ? 0 : 1);
      expect(
        result.message,
        scenario.refreshFails || scenario.fail ? isNotNull : isNull,
      );
      expect(events, hasLength(scenario.fail ? 0 : 1));
      if (events.isNotEmpty) {
        expect(events.single.subject, 536270);
        expect(events.single.episode, 10002);
        expect(events.single.account, 'test:1');
      }
    });
  }
}
