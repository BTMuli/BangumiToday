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
import 'package:bangumi_today/pages/subject-detail/sd_pw_rate_chart.dart';
import 'package:bangumi_today/pages/subject-detail/sdp_action_bar.dart';
import 'package:bangumi_today/pages/subject-detail/sdp_identity_band.dart';
import 'package:bangumi_today/pages/subject-detail/sdp_layout_a.dart';
import 'package:bangumi_today/pages/subject-detail/sdp_layout_switcher.dart';
import 'package:bangumi_today/pages/subject-detail/sdp_view_data.dart';
import 'package:bangumi_today/pages/subject-detail/subject_layout_mode.dart';
import 'package:bangumi_today/pages/subject-detail/subject_stat_providers.dart';
import 'package:bangumi_today/providers/bangumi_providers.dart';

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
    infobox: [BangumiInfoBoxItem(key: '话数', value: '28')],
    volumes: 0,
    eps: 28,
    totalEpisodes: 28,
    rating: BangumiPatchRating(
      total: 12000,
      count: const {'1': 10, '5': 100, '8': 400, '9': 800, '10': 200},
      score: 8.9,
      rank: 1,
    ),
    collection: BangumiPatchCollection(
      wish: 10,
      collect: 20,
      doing: 30,
      onHold: 1,
      dropped: 0,
    ),
    tags: [BangumiTag(name: '奇幻', count: 99)],
  );
}

SubjectDetailViewData _view({
  Key? collectionKey,
  Key? episodesKey,
  Key? relationsKey,
}) {
  return SubjectDetailViewData(
    subject: _subject(),
    user: null,
    collectProvider: SubjectCollectStatProvider(),
    onTagTap: (_) {},
    contextMenuBuilder: (context, state) => const SizedBox.shrink(),
    openBmfDrawer: () {},
    collectionKey: collectionKey,
    episodesKey: episodesKey,
    relationsKey: relationsKey,
  );
}

class _FakeDetailRepository extends Fake implements BTBangumiRepository {
  @override
  Future<BTResponse<List<BangumiSubjectRelation>>> getSubjectRelations(
    int id,
  ) async {
    return BTResponse.success(data: <BangumiSubjectRelation>[]);
  }

  @override
  Future<BTResponse<BangumiPageT<BangumiEpisode>>> getEpisodeList(
    int id, {
    BangumiLegacyEpisodeType? type,
    int? limit,
    int? offset,
  }) async {
    return BTResponse.success(
      data: BangumiPageT(
        total: 0,
        limit: limit ?? 30,
        offset: offset ?? 0,
        data: const [],
      ),
    );
  }

  @override
  Future<BTResponse<BangumiUserSubjectCollection>> getCollectionSubject(
    String username,
    int subjectId,
  ) async {
    return BTResponse(code: 404, message: 'not found', data: null);
  }
}

class _CountingDetailRepository extends _FakeDetailRepository {
  int relationCalls = 0;
  int episodeCalls = 0;

  @override
  Future<BTResponse<List<BangumiSubjectRelation>>> getSubjectRelations(
    int id,
  ) async {
    relationCalls++;
    return super.getSubjectRelations(id);
  }

  @override
  Future<BTResponse<BangumiPageT<BangumiEpisode>>> getEpisodeList(
    int id, {
    BangumiLegacyEpisodeType? type,
    int? limit,
    int? offset,
  }) async {
    episodeCalls++;
    return super.getEpisodeList(id, type: type, limit: limit, offset: offset);
  }
}

class _KeepAliveSwitchHost extends StatefulWidget {
  const _KeepAliveSwitchHost({required this.view});

  final SubjectDetailViewData view;

  @override
  State<_KeepAliveSwitchHost> createState() => _KeepAliveSwitchHostState();
}

class _KeepAliveSwitchHostState extends State<_KeepAliveSwitchHost> {
  var useA = false;

  @override
  Widget build(BuildContext context) {
    var episodes = widget.view.buildEpisodes(
      showSummary: useA,
      showGrid: !useA,
    );
    var relations = widget.view.buildRelations();
    return Column(
      children: [
        Button(
          key: const ValueKey('test-switch-layout'),
          onPressed: () => setState(() => useA = !useA),
          child: const Text('切换'),
        ),
        if (useA)
          Column(
            key: const ValueKey('layout-a'),
            children: [episodes, relations],
          )
        else
          Column(
            key: const ValueKey('layout-current'),
            children: [episodes, relations],
          ),
      ],
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1280, 800),
  BTBangumiRepository? repository,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bangumiRepositoryProvider.overrideWithValue(
          repository ?? _FakeDetailRepository(),
        ),
      ],
      child: FluentApp(home: child),
    ),
  );
  await tester.pump();
}

void main() {
  test('操作条主操作随登录/收藏/BMF 切换', () {
    expect(
      sdpResolvePrimaryAction(
        loggedIn: false,
        collected: false,
        type: BangumiCollectionType.unknown,
        hasBmf: false,
      ),
      SdpPrimaryAction.subscribe,
    );
    expect(
      sdpResolvePrimaryAction(
        loggedIn: true,
        collected: false,
        type: BangumiCollectionType.unknown,
        hasBmf: false,
      ),
      SdpPrimaryAction.collect,
    );
    expect(
      sdpResolvePrimaryAction(
        loggedIn: true,
        collected: true,
        type: BangumiCollectionType.doing,
        hasBmf: true,
      ),
      SdpPrimaryAction.progress,
    );
    expect(
      sdpResolvePrimaryAction(
        loggedIn: true,
        collected: true,
        type: BangumiCollectionType.collect,
        hasBmf: true,
      ),
      SdpPrimaryAction.openBmf,
    );
  });

  test('详情布局配置可解析', () {
    expect(SubjectDetailLayoutModeX.tryParse(null), isNull);
    expect(SubjectDetailLayoutModeX.tryParse(''), isNull);
    expect(SubjectDetailLayoutModeX.tryParse('b'), isNull);
    expect(
      SubjectDetailLayoutModeX.tryParse('current'),
      SubjectDetailLayoutMode.current,
    );
    expect(SubjectDetailLayoutModeX.tryParse('a'), SubjectDetailLayoutMode.a);
  });

  testWidgets('页头可用开关选择新布局', (tester) async {
    await _pump(tester, const ScaffoldPage(header: SdpLayoutSwitcher()));
    expect(find.text('新布局'), findsOneWidget);
    expect(find.text('现状'), findsNothing);
    expect(find.text('A'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('subject-layout-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    var element = tester.element(find.byType(SdpLayoutSwitcher));
    var container = ProviderScope.containerOf(element);
    expect(
      container.read(subjectDetailLayoutModeProvider),
      SubjectDetailLayoutMode.a,
    );

    await tester.tap(find.byKey(const ValueKey('subject-layout-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      container.read(subjectDetailLayoutModeProvider),
      SubjectDetailLayoutMode.current,
    );
  });

  testWidgets('身份带展示评分数而不是柱状图', (tester) async {
    await _pump(tester, SdpIdentityBand(subject: _subject()));
    expect(
      find.byKey(const ValueKey('subject-identity-score')),
      findsOneWidget,
    );
    expect(find.byType(SdpRateChartWidget), findsNothing);
    expect(find.text('想看'), findsNothing);
    expect(
      find.byKey(const ValueKey('subject-identity-copy-title')),
      findsOneWidget,
    );
  });

  testWidgets('身份带在封面右侧展示标题', (tester) async {
    await _pump(
      tester,
      Center(
        child: SizedBox(
          width: 600,
          child: SdpIdentityBand(subject: _subject()),
        ),
      ),
    );
    var cover = tester.getRect(
      find.byKey(const ValueKey('subject-identity-cover')),
    );
    var title = tester.getRect(find.text('葬送的芙莉莲'));
    expect(title.left, greaterThan(cover.right));
    expect(title.top, lessThan(cover.bottom));
  });

  testWidgets('未登录操作条仍有 BMF 入口', (tester) async {
    await _pump(
      tester,
      ScaffoldPage(content: SdpActionBar(view: _view(), hasBmf: false)),
    );
    expect(find.text('登录后追番'), findsOneWidget);
    expect(find.text('订阅下载'), findsOneWidget);
  });

  testWidgets('方案 A 首屏有身份带和订阅入口', (tester) async {
    await _pump(
      tester,
      ScaffoldPage(content: SdpLayoutA(view: _view(), hasBmf: false)),
    );
    expect(find.byKey(const ValueKey('subject-layout-a')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('subject-identity-score')),
      findsOneWidget,
    );
    expect(find.text('订阅下载'), findsOneWidget);
    expect(find.text('评分与热度'), findsOneWidget);
  });

  testWidgets('方案 A 首屏不请求剧集和关联', (tester) async {
    var repo = _CountingDetailRepository();
    await _pump(
      tester,
      ScaffoldPage(content: SdpLayoutA(view: _view(), hasBmf: false)),
      repository: repo,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(repo.episodeCalls, 0);
    expect(repo.relationCalls, 0);
    expect(find.byType(SdpRateChartWidget), findsNothing);
  });

  testWidgets('方案 A 展开折叠节后才请求剧集和关联', (tester) async {
    var repo = _CountingDetailRepository();
    await _pump(
      tester,
      ScaffoldPage(content: SdpLayoutA(view: _view(), hasBmf: false)),
      repository: repo,
    );
    await tester.pump();

    await tester.tap(find.text('剧集进度'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(repo.episodeCalls, 1);
    expect(repo.relationCalls, 0);

    await tester.ensureVisible(find.text('关联条目'));
    await tester.tap(find.text('关联条目'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(repo.episodeCalls, 1);
    expect(repo.relationCalls, 1);
  });

  testWidgets('方案 A 有 BMF 时首屏请求剧集', (tester) async {
    var repo = _CountingDetailRepository();
    await _pump(
      tester,
      ScaffoldPage(content: SdpLayoutA(view: _view(), hasBmf: true)),
      repository: repo,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(repo.episodeCalls, 1);
    expect(repo.relationCalls, 0);
  });

  testWidgets('切换布局不重复请求剧集和关联', (tester) async {
    var repo = _CountingDetailRepository();
    var view = _view(episodesKey: GlobalKey(), relationsKey: GlobalKey());
    await _pump(tester, _KeepAliveSwitchHost(view: view), repository: repo);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(repo.episodeCalls, 1);
    expect(repo.relationCalls, 1);

    await tester.tap(find.byKey(const ValueKey('test-switch-layout')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(repo.episodeCalls, 1);
    expect(repo.relationCalls, 1);

    await tester.tap(find.byKey(const ValueKey('test-switch-layout')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(repo.episodeCalls, 1);
    expect(repo.relationCalls, 1);
  });
}
