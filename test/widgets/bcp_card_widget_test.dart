// Flutter imports:
import 'package:flutter/widgets.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model_patch.dart';
import 'package:bangumi_today/pages/bangumi-calendar/bc_pw_card.dart';
import 'package:bangumi_today/pages/bangumi-calendar/bc_pw_day.dart';
import 'package:bangumi_today/widgets/bangumi/bt_bangumi_cover.dart';

void main() {
  BangumiLegacySubjectSmall buildSubject({
    int id = 1,
    String? name,
    String? nameCn,
    String? cover,
  }) {
    return BangumiLegacySubjectSmall(
      id: id,
      url: 'https://bgm.tv/subject/$id',
      type: BangumiLegacySubjectType.anime,
      name: name ?? 'ふつつかな悪女ではございますが ～雛宮蝶鼠とりかえ伝～',
      nameCn: nameCn ?? '恶女不才，请多关照 ～雏宫蝶鼠换身传～',
      summary: '',
      airDate: '2026-07-01',
      airWeekday: 2,
      images: BangumiPersonImages(
        large: cover ?? '',
        medium: '',
        small: '',
        grid: '',
      ),
      eps: null,
      epsCount: null,
      rating: BangumiPatchRating(
        total: 4995,
        count: const {},
        score: 6.9,
        rank: null,
      ),
      rank: null,
      collection: BangumiPatchCollection(
        wish: null,
        collect: null,
        doing: 975,
        onHold: null,
        dropped: null,
      ),
    );
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required Size windowSize,
    required Size cardSize,
    BangumiLegacySubjectSmall? subject,
    String? airTime,
  }) async {
    tester.view.physicalSize = windowSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          child: fluent.FluentApp(
            debugShowCheckedModeBanner: false,
            home: fluent.ScaffoldPage(
              padding: fluent.EdgeInsets.zero,
              content: Center(
                child: SizedBox(
                  width: cardSize.width,
                  height: cardSize.height,
                  child: BcpCardWidget(
                    data: subject ?? buildSubject(),
                    airTime: airTime,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
  }

  testWidgets('card has no overflow at default 1280x720 size', (tester) async {
    await pumpCard(
      tester,
      windowSize: const Size(1280, 720),
      cardSize: const Size(298, 209),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('card has no overflow when maximized with the sidebar expanded', (
    tester,
  ) async {
    // 2575x1407 maximized window + 320px expanded sidebar =>
    // 5-column grid, each card 428.8 x 300.2 logical px.
    await pumpCard(
      tester,
      windowSize: const Size(2575, 1407),
      cardSize: const Size(428.8, 300.2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('long titles do not overflow in narrow grid cards', (
    tester,
  ) async {
    // 1280x720 下 5 列网格的真实卡片尺寸约 262 x 183.7 逻辑像素。
    await pumpCard(
      tester,
      windowSize: const Size(1280, 720),
      cardSize: const Size(262, 183.7),
      subject: buildSubject(
        name:
            'とても長い日本語のタイトルで確認する「異世界おじさん」第１２話・最終回（前編）'
            '——カードの省略とレイアウト崩れを確認するための長いタイトルです',
        nameCn:
            '这是一个非常长的中文标题，用于验证卡片在窄尺寸下不会溢出：'
            '异世界舅舅第十二话最终回（前篇）——请确认文字能够正确省略而不是撑破布局',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a provided air time and hides it when missing', (
    tester,
  ) async {
    await pumpCard(
      tester,
      windowSize: const Size(1280, 720),
      cardSize: const Size(298, 209),
      airTime: '22:30',
    );
    expect(find.text('22:30'), findsOneWidget);

    await pumpCard(
      tester,
      windowSize: const Size(1280, 720),
      cardSize: const Size(298, 209),
    );
    expect(find.text('22:30'), findsNothing);
  });

  testWidgets('calendar cards use the shared cover widget', (tester) async {
    await pumpCard(
      tester,
      windowSize: const Size(1280, 720),
      cardSize: const Size(298, 209),
    );
    expect(find.byType(BtBangumiCover), findsOneWidget);
  });

  testWidgets('calendar cards dispose after scrolling offscreen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 240);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var subjects = [
      for (var i = 0; i < 20; i++)
        buildSubject(id: i + 1, name: 'show-$i', nameCn: '番剧$i'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: fluent.FluentApp(
          debugShowCheckedModeBanner: false,
          home: fluent.ScaffoldPage(
            padding: fluent.EdgeInsets.zero,
            content: SizedBox(
              width: 400,
              height: 240,
              child: BcpDayWidget(data: subjects, loading: false),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    var firstCard = find.byType(BcpCardWidget).first;
    var element = tester.element(firstCard);
    expect(element.mounted, isTrue);

    await tester.drag(find.byType(GridView), const Offset(0, -4000));
    await tester.pumpAndSettle();

    expect(element.mounted, isFalse);
  });
}
