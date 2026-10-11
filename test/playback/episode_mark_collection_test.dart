// Dart imports:
import 'dart:async';

// Package imports:
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/episode_mark_service.dart';
import 'package:bangumi_today/data/datasources/bangumi_local_data_source.dart';
import 'package:bangumi_today/data/datasources/bangumi_remote_data_source.dart';
import 'package:bangumi_today/data/repositories/bangumi_repository_impl.dart';
import 'package:bangumi_today/data/repositories/episode_mark_gateway_impl.dart';
import 'package:bangumi_today/database/drift/bt_database.dart';
import 'package:bangumi_today/database/drift/collection_storage.dart';
import 'package:bangumi_today/domain/repositories/episode_mark_gateway.dart';
import 'package:bangumi_today/domain/repositories/playback_episode_links.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';
import 'package:bangumi_today/models/playback/playback_episode_link.dart';
import 'package:bangumi_today/models/playback/playback_episode_rule.dart';
import 'package:bangumi_today/models/playback/playback_item.dart';

class _Local extends Fake implements BTBangumiLocalDataSource {
  _Local(this.db);
  final BtDatabase db;
  int deletions = 0;

  @override
  Future<void> deleteCollection(int subjectId) async {
    deletions++;
    await (db.delete(
      db.bangumiCollection,
    )..where((row) => row.subjectId.equals(subjectId))).go();
  }
}

class _Remote extends Fake implements BTBangumiRemoteDataSource {
  _Remote({required this.done, required this.failWrite});
  bool done;
  final bool failWrite;
  int writes = 0;

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

void main() {
  for (var scenario in [
    (name: '标记章节成功', done: false, fail: false),
    (name: '确认章节已看过', done: true, fail: false),
    (name: '标记章节失败', done: false, fail: true),
  ]) {
    test('${scenario.name}后保留条目收藏，仅在成功时通知刷新', () async {
      var db = BtDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await CollectionStorage(db).saveAll([
        BangumiCollectionCompanion.insert(
          subjectId: const Value(536270),
          subjectType: 2,
          rate: 7,
          collectionType: BangumiCollectionType.doing.value,
          tags: '["保留标签"]',
          epStat: 1,
          volStat: 0,
          updatedAt: '2026-10-11T22:07:58+08:00',
          private: 1,
          comment: const Value('保留短评'),
          subject: const Value(
            '{"id":536270,"name":"目覚めたら最強装備と宇宙船持ちだったので、"'
            ',"name_cn":"一觉醒来坐拥神装和飞船"}',
          ),
        ),
      ]);
      var before = await db.select(db.bangumiCollection).getSingle();
      var local = _Local(db);
      var remote = _Remote(done: scenario.done, failWrite: scenario.fail);
      var service = EpisodeMarkService(
        gateway: BangumiEpisodeMarkGateway(
          BTBangumiRepositoryImpl(
            remoteDataSource: remote,
            localDataSource: local,
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
      expect(remote.writes, scenario.done ? 0 : 1);
      var after = await db.select(db.bangumiCollection).getSingle();
      expect(after.toJson(), before.toJson());
      expect(events, hasLength(scenario.fail ? 0 : 1));
      if (events.isNotEmpty) {
        expect(events.single.subject, 536270);
        expect(events.single.episode, 10002);
        expect(events.single.account, 'test:1');
      }
    });
  }
}
