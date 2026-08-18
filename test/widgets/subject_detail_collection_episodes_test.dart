// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/domain/repositories/bangumi_repository.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model_patch.dart';
import 'package:bangumi_today/pages/subject-detail/subject_stat_providers.dart';
import 'package:bangumi_today/providers/bangumi_providers.dart';
import 'package:bangumi_today/widgets/bangumi/subject_detail/bsd_user_collection.dart';
import 'package:bangumi_today/widgets/bangumi/subject_detail/bsd_user_episodes.dart';

BangumiSubject _subject() {
  return BangumiSubject(
    id: 8,
    type: BangumiSubjectType.anime,
    name: 'Frieren',
    nameCn: '葬送的芙莉莲',
    summary: '魔法使芙莉莲的故事。',
    nsfw: false,
    locked: false,
    date: '2023-09-29',
    platform: 'TV',
    images: BangumiImages(
      large: '',
      common: '',
      medium: '',
      small: '',
      grid: '',
    ),
    infobox: const [],
    volumes: 0,
    eps: 1,
    totalEpisodes: 1,
    rating: BangumiPatchRating(total: 1, count: const {}, score: 8.9, rank: 1),
    collection: BangumiPatchCollection(
      wish: 0,
      collect: 0,
      doing: 1,
      onHold: 0,
      dropped: 0,
    ),
    tags: const [],
  );
}

BangumiUser _user() {
  return BangumiUser(
    id: 1,
    username: 'user',
    nickname: '昵称',
    userGroup: BangumiLegacyUserGroupType.user,
    avatar: BangumiAvatar(large: '', medium: '', small: ''),
    sign: '',
  );
}

BangumiEpisode _episode() {
  return BangumiEpisode(
    id: 101,
    type: BangumiEpType.main,
    name: 'Ep',
    nameCn: '第一话',
    sort: 1,
    ep: 1,
    airDate: '2023-01-01',
    comment: 0,
    duration: '24m',
    desc: '',
    disc: 0,
    durationSeconds: 1440,
  );
}

BangumiUserSubjectCollection _collection() {
  return BangumiUserSubjectCollection(
    subjectId: 8,
    subjectType: BangumiSubjectType.anime,
    rate: 8,
    type: BangumiCollectionType.doing,
    comment: '',
    tags: const [],
    epStatus: 1,
    volStatus: 0,
    updatedAt: '2026-01-01',
    private: false,
    subject: BangumiSlimSubject(
      id: 8,
      type: BangumiSubjectType.anime,
      name: 'Frieren',
      nameCn: '葬送的芙莉莲',
      shortSummary: '',
      date: '2023-09-29',
      images: BangumiImages(
        large: '',
        common: '',
        medium: '',
        small: '',
        grid: '',
      ),
      volumes: 0,
      eps: 1,
      collectionTotal: 1,
      score: 8.9,
      tags: const [],
    ),
  );
}

class _DetailRepo extends Fake implements BTBangumiRepository {
  BangumiUserSubjectCollection? local;
  Completer<BangumiUserSubjectCollection>? remoteCollection;
  Completer<void>? episodeGate;
  Completer<void>? userEpisodeGate;

  var collectionSubjectCalls = 0;
  var episodeCalls = 0;
  var userEpisodeCalls = 0;
  int? lastEpisodeLimit;

  @override
  Future<BangumiUserSubjectCollection?> getLocalCollection(
    int subjectId,
  ) async {
    return local;
  }

  @override
  Future<BTResponse<BangumiUserSubjectCollection>> getCollectionSubject(
    String username,
    int subjectId,
  ) async {
    collectionSubjectCalls++;
    if (remoteCollection != null) {
      var data = await remoteCollection!.future;
      return BTResponse.success(data: data);
    }
    return BTResponse(code: 404, message: 'not found', data: null);
  }

  @override
  Future<BTResponse<BangumiPageT<BangumiEpisode>>> getEpisodeList(
    int id, {
    BangumiLegacyEpisodeType? type,
    int? limit,
    int? offset,
  }) async {
    episodeCalls++;
    lastEpisodeLimit = limit;
    if (episodeGate != null) await episodeGate!.future;
    return BTResponse.success(
      data: BangumiPageT(
        total: 1,
        limit: limit ?? 100,
        offset: offset ?? 0,
        data: [_episode()],
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
    userEpisodeCalls++;
    if (userEpisodeGate != null) await userEpisodeGate!.future;
    return BTResponse.success(
      data: BangumiPageT(
        total: 1,
        limit: limit ?? 100,
        offset: offset ?? 0,
        data: [
          BangumiUserEpisodeCollection(
            episode: _episode(),
            type: BangumiEpisodeCollectionType.done,
          ),
        ],
      ),
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required BTBangumiRepository repository,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [bangumiRepositoryProvider.overrideWithValue(repository)],
      child: FluentApp(home: ScaffoldPage(content: child)),
    ),
  );
}

void main() {
  testWidgets('收藏可先用本地数据展示而不等待远程', (tester) async {
    var repo = _DetailRepo()
      ..local = _collection()
      ..remoteCollection = Completer<BangumiUserSubjectCollection>();
    addTearDown(() {
      if (!repo.remoteCollection!.isCompleted) {
        repo.remoteCollection!.complete(_collection());
      }
    });
    await _pump(
      tester,
      BsdUserCollection(_subject(), _user(), SubjectCollectStatProvider()),
      repository: repo,
    );
    await tester.pump();

    expect(find.text('在看'), findsOneWidget);
    expect(find.byKey(const ValueKey('subject-collect-loading')), findsNothing);
    expect(repo.collectionSubjectCalls, 1);
  });

  testWidgets('剧集列表不等待收藏接口且首屏 limit 为 100', (tester) async {
    var repo = _DetailRepo()..episodeGate = Completer<void>();
    addTearDown(() {
      if (!repo.episodeGate!.isCompleted) {
        repo.episodeGate!.complete();
      }
    });
    await _pump(
      tester,
      BsdUserEpisodes(_subject(), _user(), SubjectCollectStatProvider()),
      repository: repo,
    );
    await tester.pump();

    expect(repo.episodeCalls, 1);
    expect(repo.lastEpisodeLimit, 100);
    expect(repo.collectionSubjectCalls, 0);
    expect(repo.userEpisodeCalls, 0);
    expect(
      find.byKey(const ValueKey('subject-episodes-loading')),
      findsOneWidget,
    );

    repo.episodeGate!.complete();
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('已收藏时剧集列表和收藏章节并行请求', (tester) async {
    var repo = _DetailRepo()
      ..episodeGate = Completer<void>()
      ..userEpisodeGate = Completer<void>();
    addTearDown(() {
      if (!repo.episodeGate!.isCompleted) repo.episodeGate!.complete();
      if (!repo.userEpisodeGate!.isCompleted) {
        repo.userEpisodeGate!.complete();
      }
    });
    var provider = SubjectCollectStatProvider()..set(true);
    await _pump(
      tester,
      BsdUserEpisodes(_subject(), _user(), provider),
      repository: repo,
    );
    await tester.pump();

    expect(repo.episodeCalls, 1);
    expect(repo.userEpisodeCalls, 1);
    expect(repo.collectionSubjectCalls, 0);
    expect(find.text('1'), findsNothing);

    repo.episodeGate!.complete();
    await tester.pump();
    expect(find.text('1'), findsNothing);

    repo.userEpisodeGate!.complete();
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('收藏状态稍后到达时不清空已加载剧集', (tester) async {
    var repo = _DetailRepo()..userEpisodeGate = Completer<void>();
    addTearDown(() {
      if (!repo.userEpisodeGate!.isCompleted) {
        repo.userEpisodeGate!.complete();
      }
    });
    var provider = SubjectCollectStatProvider();
    await _pump(
      tester,
      BsdUserEpisodes(_subject(), _user(), provider),
      repository: repo,
    );
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(repo.userEpisodeCalls, 0);

    provider.set(true);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(repo.userEpisodeCalls, 1);

    repo.userEpisodeGate!.complete();
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('本地收藏命中后剧集与收藏章节并行，不互相阻塞', (tester) async {
    var repo = _DetailRepo()
      ..local = _collection()
      ..remoteCollection = Completer<BangumiUserSubjectCollection>()
      ..episodeGate = Completer<void>()
      ..userEpisodeGate = Completer<void>();
    addTearDown(() {
      if (!repo.remoteCollection!.isCompleted) {
        repo.remoteCollection!.complete(_collection());
      }
      if (!repo.episodeGate!.isCompleted) repo.episodeGate!.complete();
      if (!repo.userEpisodeGate!.isCompleted) {
        repo.userEpisodeGate!.complete();
      }
    });
    var provider = SubjectCollectStatProvider();
    await _pump(
      tester,
      Column(
        children: [
          BsdUserCollection(_subject(), _user(), provider, compact: true),
          BsdUserEpisodes(_subject(), _user(), provider),
        ],
      ),
      repository: repo,
    );
    await tester.pump();

    expect(find.text('在看'), findsOneWidget);
    expect(repo.episodeCalls, 1);
    expect(repo.userEpisodeCalls, 1);
    expect(repo.lastEpisodeLimit, 100);
    expect(find.text('1'), findsNothing);

    repo.episodeGate!.complete();
    repo.userEpisodeGate!.complete();
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('在看'), findsOneWidget);
  });
}
