// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Project imports:
import 'package:bangumi_today/core/services/episode_mark_service.dart';
import 'package:bangumi_today/core/services/playback_episode_protocol.dart';
import 'package:bangumi_today/data/repositories/episode_mark_gateway_impl.dart';
import 'package:bangumi_today/domain/repositories/bangumi_repository.dart';
import 'package:bangumi_today/domain/repositories/bmf_repository.dart';
import 'package:bangumi_today/domain/repositories/episode_mark_gateway.dart';
import 'package:bangumi_today/domain/repositories/playback_episode_links.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';
import 'package:bangumi_today/models/playback/playback_completion.dart';
import 'package:bangumi_today/models/playback/playback_episode_link.dart';
import 'package:bangumi_today/models/playback/playback_episode_rule.dart';
import 'package:bangumi_today/models/playback/playback_item.dart';
import 'package:bangumi_today/providers/bangumi_providers.dart';
import 'package:bangumi_today/providers/bmf_providers.dart';
import 'package:bangumi_today/providers/episode_mark_providers.dart';
import 'package:bangumi_today/providers/playback_episode_link_providers.dart';
import 'package:bangumi_today/providers/playback_window_providers.dart';
import 'package:bangumi_today/providers/subject_playback_providers.dart';
import 'package:bangumi_today/store/bgm_user_hive.dart';
import 'package:bangumi_today/store/bt_download_store.dart';
import 'package:bangumi_today/store/playback_store.dart';

const _item = PlaybackItem(
  filePath: 'D:/Anime/536270/Show - 02.mkv',
  title: 'episode 2',
  subject: 536270,
);
const _next = PlaybackItem(
  filePath: 'D:/Anime/536270/Show - 03.mkv',
  title: 'episode 3',
  subject: 536270,
);

BangumiEpisode _episode(int id) => BangumiEpisode(
  id: id,
  type: BangumiEpType.main,
  name: 'episode ${id - 10000}',
  nameCn: '',
  sort: (id - 10000).toDouble(),
  ep: (id - 10000).toDouble(),
  airDate: '',
  comment: 0,
  duration: '',
  desc: '',
  disc: 0,
  durationSeconds: 0,
);

class _Repository extends Fake implements BTBangumiRepository {
  final readFailures = <int>[];
  final writeFailures = <int>[];
  final reads = <int>[];
  final writes = <int>[];
  final done = <int>{};
  List<int> chapterIds = [10002, 10003];
  Completer<void>? progressGate;
  final progressFailures = <int>[];
  final localProgress = <int>[];
  int episodePageReads = 0;
  int progressPageReads = 0;
  bool commitOnFailure = false;

  @override
  Future<BTResponse<BangumiPageT<BangumiEpisode>>> getEpisodeList(
    int id, {
    BangumiLegacyEpisodeType? type,
    int? limit,
    int? offset,
  }) async {
    episodePageReads++;
    return BTResponse.success(
      data: BangumiPageT(
        total: chapterIds.length,
        limit: 100,
        offset: 0,
        data: chapterIds.map(_episode).toList(),
      ),
    );
  }

  @override
  Future<BTResponse<BangumiUserEpisodeCollection>> getCollectionEpisode(
    int episodeId,
  ) async {
    reads.add(episodeId);
    if (readFailures.isNotEmpty) {
      return BTResponse.error(
        code: readFailures.removeAt(0),
        message: '读取失败',
        data: null,
      );
    }
    return BTResponse.success(
      data: BangumiUserEpisodeCollection(
        episode: _episode(episodeId),
        type: done.contains(episodeId)
            ? BangumiEpisodeCollectionType.done
            : BangumiEpisodeCollectionType.none,
      ),
    );
  }

  @override
  Future<BTResponse<BangumiPageT<BangumiUserEpisodeCollection>>>
  getCollectionEpisodes(
    int subjectId, {
    int? offset,
    int? limit,
    BangumiLegacyEpisodeType? type,
  }) async {
    progressPageReads++;
    await progressGate?.future;
    if (progressFailures.isNotEmpty) {
      return BTResponse.error(
        code: progressFailures.removeAt(0),
        message: '读取失败',
        data: null,
      );
    }
    return BTResponse.success(
      data: BangumiPageT(
        total: chapterIds.length,
        limit: 100,
        offset: 0,
        data: [
          for (var id in chapterIds)
            BangumiUserEpisodeCollection(
              episode: _episode(id),
              type: done.contains(id)
                  ? BangumiEpisodeCollectionType.done
                  : BangumiEpisodeCollectionType.none,
            ),
        ],
      ),
    );
  }

  @override
  Future<BTResponse<void>> updateCollectionEpisode({
    required BangumiEpisodeCollectionType type,
    required int episode,
    bool Function()? authScope,
  }) async {
    expect(authScope?.call(), isTrue);
    expect(type, BangumiEpisodeCollectionType.done);
    writes.add(episode);
    var code = writeFailures.isEmpty ? 0 : writeFailures.removeAt(0);
    if (code == 0 || commitOnFailure) done.add(episode);
    return BTResponse(code: code, message: '写入失败', data: null);
  }

  @override
  Future<BTResponse<void>> saveLocalCollectionProgress(
    int subjectId,
    int watchedEpisodes, {
    required bool Function() authScope,
  }) async {
    expect(authScope(), isTrue);
    localProgress.add(watchedEpisodes);
    return BTResponse(code: 0, message: 'saved locally', data: null);
  }
}

class _Links extends Fake implements PlaybackEpisodeLinks {
  final values = <String, PlaybackEpisodeLink>{};
  Completer<void>? readGate;

  @override
  Future<Map<String, PlaybackEpisodeLink>> readAll() async {
    await readGate?.future;
    return Map.of(values);
  }

  @override
  Stream<Map<String, PlaybackEpisodeLink>> watchAll() => const Stream.empty();

  @override
  Future<List<PlaybackEpisodeRule>> readRules() async => [];

  @override
  Stream<List<PlaybackEpisodeRule>> watchRules() => const Stream.empty();
}

class _Downloads extends BtDownloadStore {
  @override
  BtDownloadState build() => const BtDownloadState();
}

class _Bmf extends Fake implements BmfRepository {}

class _User extends BgmUserStore {
  @override
  BgmUserState build() => const BgmUserState();

  void authorize(String token, {int generation = 0, int id = 1}) {
    state = BgmUserState(
      user: BangumiUser(
        id: id,
        username: 'user_$id',
        nickname: '用户 $id',
        userGroup: BangumiLegacyUserGroupType.user,
        avatar: BangumiAvatar(large: '', medium: '', small: ''),
        sign: '',
      ),
      accessToken: token,
      sessionGeneration: generation,
    );
  }
}

/// Playback notifications without starting mpv or interacting with any UI.
class _Playback extends ChangeNotifier implements PlaybackStore {
  final _finished = StreamController<PlaybackCompletion>.broadcast(sync: true);

  @override
  bool get isClosed => false;

  @override
  bool autoMarkWatched = false;

  @override
  Stream<PlaybackCompletion> get completions => _finished.stream;

  @override
  PlaybackItem? current = _item;

  void select(PlaybackItem item) {
    current = item;
    notifyListeners();
  }

  void finish(PlaybackItem item) {
    _finished.add(
      PlaybackCompletion(
        sessionId: item.key,
        item: item,
        positionMs: 1000,
        durationMs: 1000,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_finished.close());
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'BangumiToday',
    packageName: 'bangumi_today',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );

  late _Repository repository;
  late _User user;
  late _Playback playback;
  late _Links links;
  late ProviderContainer container;
  late EpisodeMarkController controller;

  setUp(() {
    repository = _Repository();
    playback = _Playback();
    links = _Links();
    container = ProviderContainer(
      overrides: [
        bgmUserStoreProvider.overrideWith(_User.new),
        bangumiRepositoryProvider.overrideWithValue(repository),
        playbackStoreProvider.overrideWith((ref) => playback),
        playbackEpisodeLinksProvider.overrideWithValue(links),
      ],
    );
    user = container.read(bgmUserStoreProvider.notifier) as _User;
    user.authorize('token-1');
    controller = container.read(episodeMarkProvider.notifier);
  });

  tearDown(() => container.dispose());

  group('播放结束自动标记', () {
    test('默认关闭，播放完成不写观看进度', () async {
      await controller.syncItems([_item, _next]);
      playback.finish(_item);
      await pumpEventQueue();
      expect(repository.writes, isEmpty);
    });

    test('切集后仍标记刚播完的章节，重复结束事件只写一次', () async {
      await controller.syncItems([_item, _next]);
      playback.autoMarkWatched = true;
      playback.finish(_item);
      playback.finish(_item);
      playback.select(_next);
      await pumpEventQueue();
      expect(repository.writes, [10002]);
      expect(repository.progressPageReads, 1);
      expect(repository.episodePageReads, 0);
      expect(repository.reads, isEmpty);
    });

    test('手动切集不标记，最后一集自然结束仍标记', () async {
      await controller.syncItems([_item, _next]);
      playback.autoMarkWatched = true;
      playback.select(_next);
      await pumpEventQueue();
      expect(repository.writes, isEmpty);
      playback.finish(_next);
      await pumpEventQueue();
      expect(repository.writes, [10003]);
    });

    test('已看过的章节不重复请求', () async {
      repository.done.add(10002);
      await controller.syncItems([_item, _next]);
      playback.autoMarkWatched = true;
      playback.finish(_item);
      await pumpEventQueue();
      expect(repository.writes, isEmpty);
      expect(repository.progressPageReads, 1);
      expect(repository.reads, isEmpty);
    });

    test('未打开选集面板也能复用预加载章节自动标记', () async {
      await controller.service.chaptersForPlayback(_item.subject!);
      expect(container.read(episodeMarkProvider).checked, isEmpty);
      playback.autoMarkWatched = true;
      playback.finish(_item);
      playback.select(_next);
      await pumpEventQueue();
      expect(repository.writes, [10002]);
      expect(repository.progressPageReads, 1);
      expect(repository.episodePageReads, 0);
      expect(repository.reads, isEmpty);
    });

    test('未关联、匹配不唯一、排除的文件和未登录状态不启用', () async {
      const unassociated = PlaybackItem(filePath: 'movie.mkv', title: 'movie');
      const ambiguous = PlaybackItem(
        filePath: 'D:/Anime/Show 02-03.mkv',
        title: 'merged',
        subject: 536270,
      );
      links.values[_next.key] = PlaybackEpisodeLink(
        filePath: _next.filePath,
        subject: _next.subject!,
        episode: null,
      );
      await controller.syncItems([_item, _next, ambiguous]);
      var progress = container.read(episodeMarkProvider);
      expect(progress.autoMarkDisabledReason(_item), isNull);
      expect(progress.autoMarkDisabledReason(null), isNotNull);
      expect(progress.autoMarkDisabledReason(unassociated), isNotNull);
      expect(progress.autoMarkDisabledReason(ambiguous), isNotNull);
      expect(progress.autoMarkDisabledReason(_next), isNotNull);
      expect(const EpisodeMarkState().autoMarkDisabledReason(_item), isNotNull);
      playback.autoMarkWatched = true;
      playback.finish(unassociated);
      playback.finish(ambiguous);
      playback.finish(_next);
      await pumpEventQueue();
      expect(repository.writes, isEmpty);
    });

    test('结束时进度仍在加载则共享请求，读取完成前不写入', () async {
      var gate = repository.progressGate = Completer<void>();
      var syncing = controller.syncItems([_item]);
      await pumpEventQueue();
      playback.autoMarkWatched = true;
      expect(
        container.read(episodeMarkProvider).autoMarkDisabledReason(_item),
        '正在读取条目观看进度…',
      );
      playback.finish(_item);
      playback.select(_next);
      await pumpEventQueue();
      expect(repository.writes, isEmpty);
      gate.complete();
      await syncing;
      await pumpEventQueue();
      expect(repository.writes, [10002]);
      expect(repository.progressPageReads, 1);
    });

    test('结束后换号使原账户的待处理标记失效', () async {
      await controller.syncItems([_item, _next]);
      playback.autoMarkWatched = true;
      var gate = links.readGate = Completer<void>();
      playback.finish(_item);
      await pumpEventQueue();
      user.authorize('another', id: 2, generation: 1);
      await container.pump();
      gate.complete();
      await pumpEventQueue();
      expect(repository.writes, isEmpty);
    });

    test('结束后排除当前文件不会误标原匹配章节', () async {
      await controller.syncItems([_item, _next]);
      playback.autoMarkWatched = true;
      var gate = links.readGate = Completer<void>();
      playback.finish(_item);
      links.values[_item.key] = PlaybackEpisodeLink(
        filePath: _item.filePath,
        subject: _item.subject!,
        episode: null,
      );
      gate.complete();
      await pumpEventQueue();
      expect(repository.writes, isEmpty);
    });

    test('独立播放器将结束文件交给主窗口标记，浮出层关闭不影响处理', () async {
      var calls = <(String, Map<String, Object?>)>[];
      var childPlayback = _Playback();
      const state = EpisodeMarkState(account: 'account');
      var remote = RemoteEpisodeMarkController((method, body) async {
        calls.add((method, body));
        return {
          'state': encodeEpisodeMarkState(
            state,
            account: 'account',
            revision: 2,
          ),
          'result': {'status': 'marked', 'message': null},
        };
      });
      var child = ProviderContainer(
        overrides: [
          playbackStoreProvider.overrideWith((ref) => childPlayback),
          episodeMarkProvider.overrideWith(() => remote),
        ],
      );
      addTearDown(child.dispose);
      child.read(episodeMarkProvider);
      remote.receive(
        encodeEpisodeMarkState(state, account: 'account', revision: 1),
      );
      childPlayback.autoMarkWatched = true;
      childPlayback.finish(_item);
      childPlayback.select(_next);
      await pumpEventQueue();
      expect(calls, hasLength(1));
      expect(calls.single.$1, 'episodes.markItem');
      expect(calls.single.$2['account'], 'account');
      expect((calls.single.$2['item'] as Map)['filePath'], _item.filePath);
      expect(repository.writes, isEmpty);
    });
  });

  test('选集进度加载后连续标记复用章节列表', () async {
    await controller.syncItems([_item, _next]);
    expect(repository.progressPageReads, 1);

    expect(
      (await controller.markItem(_item)).status,
      EpisodeMarkWriteStatus.marked,
    );
    expect(
      (await controller.markItem(_next)).status,
      EpisodeMarkWriteStatus.marked,
    );
    expect(repository.progressPageReads, 1);
    expect(repository.episodePageReads, 0);
    expect(repository.writes, [10002, 10003]);
    expect(repository.reads, isEmpty);
    expect(repository.localProgress, [1, 2]);
  });

  for (var concurrent in [false, true]) {
    test('${concurrent ? '并发' : '连续'}标记12集仅发送12次写入，重复标记不请求', () async {
      repository.chapterIds = List.generate(12, (index) => 10001 + index);
      var items = [
        for (var number = 1; number <= 12; number++)
          PlaybackItem(
            filePath: 'D:/Anime/536270/Show - $number.mkv',
            title: 'episode $number',
            subject: 536270,
          ),
      ];
      await controller.syncItems(items);
      expect(repository.progressPageReads, 1);
      var results = <EpisodeMarkWriteResult>[];
      if (concurrent) {
        results = await Future.wait(items.map(controller.markItem));
      } else {
        for (var item in items) {
          results.add(await controller.markItem(item));
        }
      }
      expect(
        results.map((result) => result.status),
        everyElement(EpisodeMarkWriteStatus.marked),
      );
      expect(repository.writes, repository.chapterIds);
      expect(repository.reads, isEmpty);
      expect(repository.progressPageReads, 1);
      expect(repository.episodePageReads, 0);
      expect(container.read(episodeMarkProvider).marked, hasLength(12));
      expect(
        (await controller.markItem(items.first)).status,
        EpisodeMarkWriteStatus.alreadyDone,
      );
      expect(repository.writes, hasLength(12));
      expect(repository.reads, isEmpty);
    });
  }

  test('选集进度读取期间切集和续期 Token，仍完成原章节标记', () async {
    var gate = repository.progressGate = Completer<void>();
    var account = controller.currentAccount();
    var pending = controller.markItem(_item);
    await pumpEventQueue();
    expect(repository.progressPageReads, 1);
    playback.select(_next);
    user.authorize('token-2');
    expect(controller.currentAccount(), account);
    gate.complete();
    expect((await pending).status, EpisodeMarkWriteStatus.marked);
    expect(repository.writes, [10002]);
    expect(repository.done, {10002});
    expect(container.read(episodeMarkProvider).marked, {
      EpisodeMarkState.itemKey(_item),
    });
  });

  for (var scenario in [
    (name: '切换账号', id: 2, generation: 1),
    (name: '同一账号重新登录', id: 1, generation: 1),
  ]) {
    test('${scenario.name}使进行中的标记失效', () async {
      var gate = repository.progressGate = Completer<void>();
      var pending = controller.markItem(_item);
      await pumpEventQueue();
      user.authorize(
        'token-1',
        id: scenario.id,
        generation: scenario.generation,
      );
      gate.complete();
      expect((await pending).status, EpisodeMarkWriteStatus.expired);
      expect(repository.writes, isEmpty);
    });
  }

  test('选集进度读取发生短暂网络失败，切集后重试仍指向原章节', () async {
    repository.progressFailures.add(666);
    var pending = controller.markItem(_item);
    await pumpEventQueue();
    playback.select(_next);
    expect((await pending).status, EpisodeMarkWriteStatus.marked);
    expect(repository.progressPageReads, 2);
    expect(repository.reads, isEmpty);
    expect(repository.writes, [10002]);
  });

  test('写入响应丢失时先查回状态，避免重复提交', () async {
    repository.writeFailures.add(666);
    repository.commitOnFailure = true;
    expect(
      (await controller.markItem(_item)).status,
      EpisodeMarkWriteStatus.marked,
    );
    expect(repository.writes, [10002]);
    expect(repository.reads, [10002]);
  });

  test('确认写入未生效后重试原章节', () async {
    repository.writeFailures.add(503);
    var pending = controller.markItem(_item);
    await pumpEventQueue();
    playback.select(_next);
    expect((await pending).status, EpisodeMarkWriteStatus.marked);
    expect(repository.writes, [10002, 10002]);
    expect(repository.done, {10002});
  });

  test('重试等待期间换号不会继续查回或提交', () async {
    repository.writeFailures.add(666);
    var pending = controller.markItem(_item);
    await pumpEventQueue();
    expect(repository.writes, [10002]);
    user.authorize('token-2', id: 2, generation: 1);
    expect((await pending).status, EpisodeMarkWriteStatus.expired);
    expect(repository.writes, [10002]);
    expect(repository.reads, isEmpty);
  });

  for (var code in [401, 404, 666]) {
    test('收藏读取错误 $code 按实际原因提示且限制重试次数', () async {
      repository.readFailures.addAll([code, code, code]);
      var gateway = BangumiEpisodeMarkGateway(repository);
      await expectLater(
        gateway.isDone(10002),
        throwsA(
          isA<EpisodeMarkFailure>().having(
            (error) => error.message,
            'message',
            code == 401
                ? contains('重新登录')
                : code == 404
                ? contains('条目已收藏')
                : allOf(isNot(contains('登录')), isNot(contains('已收藏'))),
          ),
        ),
      );
      expect(repository.reads, hasLength(code == 666 ? 3 : 1));
    });
  }

  test('持续写入失败最多尝试三次，并保留失败状态', () async {
    repository.writeFailures.addAll([503, 503, 503]);
    var result = await controller.markItem(_item);
    expect(result.status, EpisodeMarkWriteStatus.failed);
    expect(repository.writes, [10002, 10002, 10002]);
    expect(repository.done, isEmpty);
    expect(container.read(episodeMarkProvider).marked, isEmpty);
  });

  test('鉴权或限流拒绝写入时不重试', () async {
    for (var code in [401, 403, 429]) {
      repository.writes.clear();
      repository.writeFailures.add(code);
      expect(
        (await controller.markItem(_item)).status,
        EpisodeMarkWriteStatus.failed,
      );
      expect(repository.writes, [10002]);
    }
  });

  group('实际播放器 provider 的章节共享', () {
    late ProviderContainer actualContainer;

    setUp(() {
      // Keep the real PlaybackStore provider and its chapter-loading callbacks.
      // Only replace external data sources; no player or UI is started.
      actualContainer = ProviderContainer(
        overrides: [
          bgmUserStoreProvider.overrideWith(_User.new),
          bangumiRepositoryProvider.overrideWithValue(repository),
          btDownloadStoreProvider.overrideWith(_Downloads.new),
          bmfRepositoryProvider.overrideWithValue(_Bmf()),
          playbackEpisodeLinksProvider.overrideWithValue(_Links()),
        ],
      );
      (actualContainer.read(bgmUserStoreProvider.notifier) as _User).authorize(
        'token-1',
      );
    });

    tearDown(() async {
      await actualContainer.read(playbackStoreProvider).shutdown();
      actualContainer.dispose();
    });

    test('实际 provider 初始化后预加载章节不出现循环依赖', () async {
      var actualPlayback = actualContainer.read(playbackStoreProvider);
      await actualPlayback.library.prepareNextEpisode([_item, _next], 0);

      expect(
        await actualPlayback.library.nextEpisodeIndex([_item, _next], 0),
        1,
      );
      expect(repository.progressPageReads, 1);
    });

    test('章节控制器先初始化时连续切集仍复用章节', () async {
      actualContainer.read(episodeMarkProvider);
      var actualPlayback = actualContainer.read(playbackStoreProvider);
      await actualPlayback.library.prepareNextEpisode([_item, _next], 0);
      actualPlayback.notifyCoverResolved();
      await actualPlayback.library.prepareNextEpisode([_item, _next], 1);

      expect(
        await actualPlayback.library.nextEpisodeIndex([_item, _next], 0),
        1,
      );
      expect(repository.progressPageReads, 1);
    });

    test('实际 provider 的预加载和列表进度共用并发请求', () async {
      var gate = repository.progressGate = Completer<void>();
      var actualPlayback = actualContainer.read(playbackStoreProvider);
      var preparing = actualPlayback.library.prepareNextEpisode([
        _item,
        _next,
      ], 0);
      var actualController = actualContainer.read(episodeMarkProvider.notifier);
      var syncing = actualController.syncItems([_item, _next]);
      await pumpEventQueue();
      expect(repository.progressPageReads, 1);
      gate.complete();
      await Future.wait([preparing, syncing]);

      expect(
        await actualPlayback.library.nextEpisodeIndex([_item, _next], 0),
        1,
      );
      expect(repository.progressPageReads, 1);
    });

    test('关闭实际播放会话仍使进行中的章节标记失效', () async {
      var actualPlayback = actualContainer.read(playbackStoreProvider);
      var actualController = actualContainer.read(episodeMarkProvider.notifier);
      var gate = repository.progressGate = Completer<void>();
      var pending = actualController.markItem(_item);
      await pumpEventQueue();

      await actualPlayback.shutdown();
      expect(actualController.currentAccount(), isNull);
      gate.complete();
      expect((await pending).status, EpisodeMarkWriteStatus.expired);
      expect(repository.writes, isEmpty);
    });

    test('条目续播读取已有单章标记，换号后不保留旧观看状态', () async {
      var actualController = actualContainer.read(episodeMarkProvider.notifier);
      actualController.receiveSubjectProgress(536270, [
        BangumiUserEpisodeCollection(
          episode: _episode(10002),
          type: BangumiEpisodeCollectionType.done,
        ),
      ], account: actualController.currentAccount());
      var provider = subjectEpisodeProgressProvider(536270);
      var subscription = actualContainer.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      expect(actualContainer.read(provider), {10002: true});

      (actualContainer.read(bgmUserStoreProvider.notifier) as _User).authorize(
        'token-2',
        id: 2,
        generation: 1,
      );
      await actualContainer.pump();
      expect(actualContainer.read(provider), isEmpty);
      expect(repository.progressPageReads, 0);
    });
  });
}
