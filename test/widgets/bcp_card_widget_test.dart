import 'package:bangumi_today/database/bt_sqlite.dart';
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model_patch.dart';
import 'package:bangumi_today/pages/bangumi-calendar/bc_pw_card.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    BTSqlite().db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  });

  tearDownAll(() async {
    await BTSqlite().db.close();
  });

  BangumiLegacySubjectSmall buildSubject() {
    return BangumiLegacySubjectSmall(
      id: 1,
      url: 'https://bgm.tv/subject/1',
      type: BangumiLegacySubjectType.anime,
      name: 'ふつつかな悪女ではございますが ～雛宮蝶鼠とりかえ伝～',
      nameCn: '恶女不才，请多关照 ～雏宫蝶鼠换身传～',
      summary: '',
      airDate: '2026-07-01',
      airWeekday: 2,
      images: BangumiPersonImages(large: '', medium: '', small: '', grid: ''),
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
  }) async {
    tester.view.physicalSize = windowSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          child: ScreenUtilInit(
            designSize: const Size(1280, 720),
            builder: (_, _) => fluent.FluentApp(
              debugShowCheckedModeBanner: false,
              home: fluent.ScaffoldPage(
                padding: fluent.EdgeInsets.zero,
                content: Center(
                  child: SizedBox(
                    width: cardSize.width,
                    height: cardSize.height,
                    child: BcpCardWidget(data: buildSubject()),
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
}
