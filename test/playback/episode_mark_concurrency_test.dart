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
import 'package:bangumi_today/data/repositories/episode_mark_gateway_impl.dart';
import 'package:bangumi_today/domain/repositories/bangumi_repository.dart';
import 'package:bangumi_today/domain/repositories/episode_mark_gateway.dart';
import 'package:bangumi_today/domain/repositories/playback_episode_links.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';
import 'package:bangumi_today/models/playback/playback_episode_link.dart';
import 'package:bangumi_today/models/playback/playback_episode_rule.dart';
import 'package:bangumi_today/models/playback/playback_item.dart';
import 'package:bangumi_today/providers/bangumi_providers.dart';
import 'package:bangumi_today/providers/episode_mark_providers.dart';
import 'package:bangumi_today/providers/playback_episode_link_providers.dart';
import 'package:bangumi_today/store/bgm_user_hive.dart';
import 'package:bangumi_today/store/playback_store.dart';
import '../collections/collection_fixture.dart';

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
  Completer<void>? readGate;
  bool commitOnFailure = false;

  @override
  Future<BTResponse<BangumiPageT<BangumiEpisode>>> getEpisodeList(
    int id, {
    BangumiLegacyEpisodeType? type,
    int? limit,
    int? offset,
  }) async => BTResponse.success(
    data: BangumiPageT(
      total: 2,
      limit: 100,
      offset: 0,
      data: [_episode(10002), _episode(10003)],
    ),
  );

  @override
  Future<BTResponse<BangumiUserEpisodeCollection>> getCollectionEpisode(
    int episodeId,
  ) async {
    reads.add(episodeId);
    await readGate?.future;
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
  Future<BTResponse<BangumiUserSubjectCollection>> refreshCollectionSubject(
    int subjectId, {
    bool Function()? authScope,
  }) async {
    expect(authScope?.call(), isTrue);
    return BTResponse.success(data: collectionFixture(epStatus: done.length));
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
  @override
  bool get isClosed => false;

  @override
  PlaybackItem? current = _item;

  void select(PlaybackItem item) {
    current = item;
    notifyListeners();
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
  late ProviderContainer container;
  late EpisodeMarkController controller;

  setUp(() {
    repository = _Repository();
    playback = _Playback();
    container = ProviderContainer(
      overrides: [
        bgmUserStoreProvider.overrideWith(_User.new),
        bangumiRepositoryProvider.overrideWithValue(repository),
        playbackStoreProvider.overrideWith((ref) => playback),
        playbackEpisodeLinksProvider.overrideWithValue(_Links()),
      ],
    );
    user = container.read(bgmUserStoreProvider.notifier) as _User;
    user.authorize('token-1');
    controller = container.read(episodeMarkProvider.notifier);
  });

  tearDown(() => container.dispose());

  test('收藏读取期间切集和续期 Token，仍完成原章节标记', () async {
    var gate = repository.readGate = Completer<void>();
    var account = controller.currentAccount();
    var pending = controller.markItem(_item);
    await pumpEventQueue();
    expect(repository.reads, [10002]);
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
      var gate = repository.readGate = Completer<void>();
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

  test('收藏读取发生短暂网络失败，切集后重试仍指向原章节', () async {
    repository.readFailures.add(666);
    var pending = controller.markItem(_item);
    await pumpEventQueue();
    playback.select(_next);
    expect((await pending).status, EpisodeMarkWriteStatus.marked);
    expect(repository.reads, everyElement(10002));
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
    expect(repository.reads, [10002, 10002, 10002]);
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
    expect(repository.reads, [10002, 10002]);
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
}
