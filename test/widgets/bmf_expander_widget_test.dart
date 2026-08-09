import 'package:bangumi_today/database/app/app_bmf.dart';
import 'package:bangumi_today/database/app/app_config.dart';
import 'package:bangumi_today/database/app/app_rss.dart';
import 'package:bangumi_today/database/bt_sqlite.dart';
import 'package:bangumi_today/models/database/app_bmf_model.dart';
import 'package:bangumi_today/models/database/app_rss_model.dart';
import 'package:bangumi_today/pages/rss-bmf/rb_pw_bmf.dart';
import 'package:bangumi_today/store/bmf_store.dart';
import 'package:bangumi_today/widgets/bangumi/subject_detail/bmf_expander.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _rssXml = '''
<rss version="2.0">
  <channel>
    <title>Example</title>
    <link>https://example.com</link>
    <description>Example feed</description>
    <ttl>15</ttl>
    <item>
      <title>Episode 1</title>
      <link>https://example.com/1</link>
      <pubDate>2026-01-01</pubDate>
    </item>
    <item>
      <title>Episode 2</title>
      <link>https://example.com/2</link>
      <pubDate>2026-01-02</pubDate>
    </item>
  </channel>
</rss>
''';

void main() {
  late Database database;

  setUpAll(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    BTSqlite().db = database;
    PackageInfo.setMockInitialValues(
      appName: 'BangumiToday',
      packageName: 'BangumiToday',
      version: '0.8.0',
      buildNumber: '22',
      buildSignature: '',
    );
  });

  tearDownAll(() async {
    await database.close();
  });

  setUp(() {
    BtsAppBmf.hasTitle = false;
    BtsAppBmf.hasMk = false;
    BtsAppBmf.hasAirDate = false;
    BtsAppBmf.hasAutoUpdate = false;
    BtsAppRss.hasMkBgmId = false;
    BtsAppRss.hasPendingItems = false;
    BtsAppRss.hasCacheVersion = false;
    BtsAppRss.hasLastFailed = false;
  });

  /// 清理并初始化测试数据库，再写入订阅缓存。
  ///
  /// 必须放在 runAsync 内：testWidgets 的 FakeAsync 区域无法完成
  /// sqflite_ffi 的真实异步调用。
  Future<void> resetDatabase(
    WidgetTester tester, {
    String? rss,
    String pendingItems = '[]',
  }) async {
    await tester.runAsync(() async {
      await database.execute('DROP TABLE IF EXISTS AppBmf');
      await database.execute('DROP TABLE IF EXISTS AppRss');
      await database.execute('DROP TABLE IF EXISTS AppConfig');
      // BTAppStore 构造时会并发执行多次配置读取，先建表避免 preCheck 竞态。
      await BtsAppConfig().preCheck();
      if (rss != null) {
        await BtsAppRss().preCheck();
        await database.insert('AppRss', {
          'rss': rss,
          'data': _rssXml,
          'ttl': 15,
          'updated': 0,
          'pendingItems': pendingItems,
          'cacheVersion': AppRssModel.currentCacheVersion,
          'lastFailed': 0,
        });
      }
    });
  }

  Future<void> pumpForRealAsync(
    WidgetTester tester,
    Widget widget, {
    Duration settle = const Duration(milliseconds: 250),
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(widget);
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(settle);
      await tester.pump(const Duration(milliseconds: 100));
    });
  }

  testWidgets('BmfRssExpander renders cached items and pending state', (
    tester,
  ) async {
    var rssUrl = 'https://example.com/feed.xml';
    await resetDatabase(
      tester,
      rss: rssUrl,
      pendingItems: '["Episode 1|2026-01-01"]',
    );

    await pumpForRealAsync(
      tester,
      ProviderScope(
        child: FluentApp(
          home: Scaffold(
            body: BmfRssExpander(
              bmf: AppBmfModel(subject: 1, title: 'T1', rss: rssUrl),
              isConfig: false,
              maxHeight: 300,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Episode 1'), findsOneWidget);
    expect(find.text('Episode 2'), findsOneWidget);
    expect(find.text('1 条更新'), findsOneWidget);
    expect(find.text('新'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(FluentIcons.check_mark));
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 100));
    });

    expect(find.text('1 条更新'), findsNothing);
    expect(find.text('新'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('RbpBmfWidget renders seeded BMF list with stats', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var rssUrl = 'https://example.com/feed.xml';
    await resetDatabase(
      tester,
      rss: rssUrl,
      pendingItems: '["Episode 1|2026-01-01"]',
    );
    var navigationStore = BmfNavigationStore();
    await tester.runAsync(() async {
      var bmfDb = BtsAppBmf();
      await bmfDb.write(
        AppBmfModel(
          subject: 1,
          title: 'A 番剧',
          airDate: '2026-02-10',
          rss: rssUrl,
          download: r'D:\A',
        ),
      );
      await bmfDb.write(
        AppBmfModel(
          subject: 2,
          title: 'B 番剧',
          airDate: '2026-05-20',
          autoUpdate: false,
        ),
      );
    });

    await pumpForRealAsync(
      tester,
      ProviderScope(
        overrides: [
          bmfListProvider.overrideWith(BmfListNotifier.new),
          bmfNavigationProvider.overrideWith((ref) => navigationStore),
        ],
        child: const FluentApp(home: Scaffold(body: RbpBmfWidget())),
      ),
    );

    expect(find.text('BMF 工作台'), findsOneWidget);
    expect(find.text('2 个关联'), findsOneWidget);
    expect(find.text('A 番剧'), findsOneWidget);
    expect(find.text('B 番剧'), findsOneWidget);
    expect(find.text('有更新'), findsOneWidget);
    expect(find.text('已关联 RSS'), findsOneWidget);

    // 打开详情面板，覆盖 RSS 与文件两个资源展开器。
    await tester.runAsync(() async {
      await tester.tap(find.text('A 番剧'));
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 100));
    });
    expect(find.text('RSS 订阅'), findsOneWidget);
    expect(find.text('下载目录'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
