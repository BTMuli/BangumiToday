// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/controller/app/page_controller.dart';
import 'package:bangumi_today/domain/repositories/bangumi_repository.dart';
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model_patch.dart';
import 'package:bangumi_today/models/bangumi/request_subject.dart';
import 'package:bangumi_today/pages/subject-search/subject_search_page.dart';
import 'package:bangumi_today/providers/app_providers.dart';
import 'package:bangumi_today/widgets/bangumi/subject_card/bsc_search.dart';

class _FakeSearchRepository extends Fake implements BTBangumiRepository {
  List<String>? lastTag;

  @override
  Future<dynamic> searchSubjects(
    String keyword, {
    String sort = 'match',
    int offset = 0,
    int limit = 10,
    List<BangumiSubjectType> type = const [BangumiSubjectType.anime],
    List<String>? tag,
    List<String>? airdate,
    List<String>? rating,
    List<String>? rank,
    bool? nsfw,
  }) async {
    lastTag = tag;
    return BangumiSubjectSearchResp.success(
      data: BangumiPageT<BangumiSubjectSearchData>(
        total: 24,
        limit: limit,
        offset: offset,
        data: List.generate(12, (index) => _buildSubject(id: index + 1)),
      ),
    );
  }

  BangumiSubjectSearchData _buildSubject({int id = 1}) {
    return BangumiSubjectSearchData(
      id: id,
      type: BangumiSubjectType.anime,
      name: '乙女ゲーム世界はモブに厳しい世界です2',
      nameCn: '恋爱游戏世界对路人角色很不友好 第二季',
      summary: '',
      series: false,
      nsfw: false,
      locked: false,
      date: '2026-01-01',
      platform: 'TV',
      images: BangumiImages(
        large: '',
        common: '',
        medium: '',
        small: '',
        grid: '',
      ),
      infobox: [],
      volumes: 0,
      eps: 12,
      totalEpisodes: 12,
      rating: BangumiPatchRating(
        total: 100,
        count: const {},
        score: 4.9,
        rank: null,
      ),
      collection: BangumiPatchCollection(
        wish: 64,
        collect: 601,
        doing: 0,
        onHold: 0,
        dropped: 0,
      ),
      metaTags: const [],
      tags: [
        BangumiTag(name: '科幻', count: 12),
        BangumiTag(name: '机战', count: 8),
      ],
    );
  }
}

class _RecordingNavStore extends BTNavStore {
  final List<Map<String, Object>> detailCalls = [];

  @override
  void addNavItemB({
    String type = '条目',
    required int subject,
    String? paneTitle,
    bool jump = true,
  }) {
    detailCalls.add({'subject': subject, 'jump': jump});
  }
}

Future<void> _pumpSearchPage(
  WidgetTester tester,
  _FakeSearchRepository repository,
  BTNavStore navStore,
) async {
  tester.view.physicalSize = const Size(1536, 864);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bangumiRepositoryProvider.overrideWithValue(repository),
        navStoreProvider.overrideWith((ref) => navStore),
      ],
      child: const FluentApp(home: SubjectSearchPage(tag: '动作')),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('search page uses normal cards and supports tag navigation', (
    tester,
  ) async {
    var repository = _FakeSearchRepository();
    var navStore = _RecordingNavStore();
    await _pumpSearchPage(tester, repository, navStore);

    expect(repository.lastTag, ['动作']);
    expect(tester.takeException(), isNull);

    expect(find.text('网格'), findsNothing);
    expect(find.text('列表'), findsNothing);
    expect(find.byType(PageWidget), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    var cards = find.byType(BscSearch);
    expect(cards.evaluate().length, greaterThanOrEqualTo(2));
    expect(tester.getSize(cards.first).height, closeTo(168, 0.01));
    expect(find.byKey(const ValueKey('subject-type-1')), findsOneWidget);
    expect(find.text('科幻'), findsWidgets);

    await tester.tap(find.text('科幻').first);
    await tester.pump();

    expect(navStore.navItems, hasLength(1));
    expect(navStore.navItems.single.body, isA<SubjectSearchPage>());
    expect((navStore.navItems.single.body as SubjectSearchPage).tag, '科幻');

    await tester.longPress(
      find.byKey(const ValueKey('subject-detail-action-1')),
    );
    await tester.pump();
    expect(navStore.detailCalls, hasLength(1));
    expect(navStore.detailCalls.single, {'subject': 1, 'jump': false});

    await tester.tap(find.byKey(const ValueKey('subject-detail-action-2')));
    await tester.pump();
    expect(navStore.detailCalls, hasLength(2));
    expect(navStore.detailCalls.last, {'subject': 2, 'jump': true});
    expect(tester.takeException(), isNull);
  });
}
