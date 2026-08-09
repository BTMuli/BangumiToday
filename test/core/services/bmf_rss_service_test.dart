import 'package:bangumi_today/core/services/bmf_rss_service.dart';
import 'package:bangumi_today/database/app/app_bmf.dart';
import 'package:bangumi_today/database/app/app_rss.dart';
import 'package:bangumi_today/database/bt_sqlite.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/models/database/app_bmf_model.dart';
import 'package:bangumi_today/models/database/app_rss_model.dart';
import 'package:bangumi_today/plugins/mikan/mikan_api.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });

  tearDownAll(() async {
    await database.close();
  });

  setUp(() async {
    BtsAppBmf.hasTitle = false;
    BtsAppBmf.hasMk = false;
    BtsAppBmf.hasAirDate = false;
    BtsAppBmf.hasAutoUpdate = false;
    BtsAppRss.hasMkBgmId = false;
    BtsAppRss.hasPendingItems = false;
    BtsAppRss.hasCacheVersion = false;
    BtsAppRss.hasLastFailed = false;
    await database.execute('DROP TABLE IF EXISTS AppBmf');
    await database.execute('DROP TABLE IF EXISTS AppRss');
    await database.execute('DROP TABLE IF EXISTS AppConfig');
  });

  Future<void> seedSubscription(int subject, String rss) async {
    var bmfDb = BtsAppBmf();
    await bmfDb.write(
      AppBmfModel(subject: subject, title: 'T$subject', rss: rss),
    );
  }

  Future<void> seedCache(
    String rss, {
    required int updated,
    String data = _rssXml,
    int cacheVersion = AppRssModel.currentCacheVersion,
  }) async {
    await BtsAppRss().preCheck();
    await database.insert('AppRss', {
      'rss': rss,
      'data': data,
      'ttl': 15,
      'updated': updated,
      'pendingItems': '[]',
      'cacheVersion': cacheVersion,
      'lastFailed': 0,
    });
  }

  BmfRssService buildService(
    _FakeMikanApi api,
    DateTime Function() now, {
    int concurrency = 4,
    Duration recoveryWindow = const Duration(minutes: 5),
    int maxAttempts = 4,
  }) {
    return BmfRssService.forTesting(
      api: api,
      now: now,
      retryBaseDelay: Duration.zero,
      jitter: () => Duration.zero,
      concurrency: concurrency,
      recoveryWindow: recoveryWindow,
      maxAttempts: maxAttempts,
    );
  }

  test('startup reuses fresh cache and makes no network requests', () async {
    var now = DateTime.now();
    var rss1 = 'https://example.com/feed-1.xml';
    var rss2 = 'https://example.com/feed-2.xml';
    await seedSubscription(1, rss1);
    await seedSubscription(2, rss2);
    await seedCache(
      rss1,
      updated: now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
    );
    await seedCache(
      rss2,
      updated: now.subtract(const Duration(minutes: 2)).millisecondsSinceEpoch,
    );

    var api = _FakeMikanApi();
    var service = buildService(api, () => now);
    await service.start(refreshInterval: const Duration(hours: 1));

    expect(api.requestedUrls, isEmpty);
    expect(service.lastRefreshMetrics?.total, 2);
    expect(service.lastRefreshMetrics?.cacheHits, 2);
    expect(service.lastRefreshMetrics?.requested, 0);
    service.stop();
  });

  test('startup refreshes only expired subscriptions', () async {
    var now = DateTime.now();
    var freshRss = 'https://example.com/fresh.xml';
    var staleRss = 'https://example.com/stale.xml';
    await seedSubscription(1, freshRss);
    await seedSubscription(2, staleRss);
    await seedCache(
      freshRss,
      updated: now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
    );
    await seedCache(
      staleRss,
      updated: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
    );

    var api = _FakeMikanApi()
      ..responses[staleRss] = BTResponse.success(data: _rssXml);
    var service = buildService(api, () => now);
    await service.start(refreshInterval: const Duration(hours: 1));

    expect(api.requestedUrls, [staleRss]);
    expect(service.lastRefreshMetrics?.cacheHits, 1);
    expect(service.lastRefreshMetrics?.requested, 1);
    service.stop();
  });

  test('manual refresh bypasses the freshness window', () async {
    var now = DateTime.now();
    var rss1 = 'https://example.com/manual-1.xml';
    var rss2 = 'https://example.com/manual-2.xml';
    await seedSubscription(1, rss1);
    await seedSubscription(2, rss2);
    await seedCache(
      rss1,
      updated: now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
    );
    await seedCache(
      rss2,
      updated: now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
    );

    var api = _FakeMikanApi()
      ..handler = (_) => BTResponse.success(data: _rssXml);
    var service = buildService(api, () => now);
    await service.start(refreshInterval: const Duration(hours: 1));
    expect(api.requestedUrls, isEmpty);

    await service.refreshNow();

    expect(api.requestedUrls.toSet(), {rss1, rss2});
    expect(service.lastRefreshMetrics?.cacheHits, 0);
    expect(service.lastRefreshMetrics?.requested, 2);
    service.stop();
  });

  test('a failing source does not block other subscriptions', () async {
    var now = DateTime.now();
    var failingRss = 'https://example.com/fail.xml';
    var okRss = 'https://example.com/ok.xml';
    await seedSubscription(1, failingRss);
    await seedSubscription(2, okRss);
    await seedCache(
      failingRss,
      updated: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
    await seedCache(
      okRss,
      updated: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
    );

    var api = _FakeMikanApi()
      ..handler = (url) => url == failingRss
          ? BTResponse.error(code: 500, message: 'boom', data: null)
          : BTResponse.success(data: _rssXml);
    var service = buildService(api, () => now);
    await service.start(refreshInterval: const Duration(hours: 1));

    expect(api.requestedUrls.toSet(), {failingRss, okRss});
    expect((await BtsAppRss().read(failingRss))?.lastFailed, isNot(0));
    expect((await BtsAppRss().read(okRss))?.lastFailed, 0);
    expect(service.lastRefreshMetrics?.requested, 2);
    expect(service.lastRefreshMetrics?.successes, 1);
    expect(service.lastRefreshMetrics?.failures, 1);
    service.stop();
  });

  test('a cache version mismatch forces a refresh', () async {
    var now = DateTime.now();
    var rss = 'https://example.com/version.xml';
    await seedSubscription(1, rss);
    await seedCache(
      rss,
      updated: now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
      cacheVersion: 0,
    );

    var api = _FakeMikanApi()
      ..responses[rss] = BTResponse.success(data: _rssXml);
    var service = buildService(api, () => now);
    await service.start(refreshInterval: const Duration(hours: 1));

    expect(api.requestedUrls, [rss]);
    expect(service.lastRefreshMetrics?.cacheHits, 0);
    service.stop();
  });

  test('a future cache timestamp is treated as stale', () async {
    var now = DateTime.now();
    var rss = 'https://example.com/future.xml';
    await seedSubscription(1, rss);
    await seedCache(
      rss,
      updated: now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );

    var api = _FakeMikanApi()
      ..responses[rss] = BTResponse.success(data: _rssXml);
    var service = buildService(api, () => now);
    await service.start(refreshInterval: const Duration(hours: 1));

    expect(api.requestedUrls, [rss]);
    service.stop();
  });

  test('corrupted cached data is treated as stale', () async {
    var now = DateTime.now();
    var rss = 'https://example.com/corrupt.xml';
    await seedSubscription(1, rss);
    await seedCache(
      rss,
      updated: now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
      data: '{{{{ not xml',
    );

    var api = _FakeMikanApi()
      ..responses[rss] = BTResponse.success(data: _rssXml);
    var service = buildService(api, () => now);
    await service.start(refreshInterval: const Duration(hours: 1));

    expect(api.requestedUrls, [rss]);
    service.stop();
  });

  test('a 429 source is retried up to the max attempts', () async {
    var now = DateTime.now();
    var rss = 'https://example.com/429.xml';
    await seedSubscription(1, rss);
    await seedCache(
      rss,
      updated: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
    );

    var api = _FakeMikanApi()
      ..handler = (_) =>
          BTResponse.error(code: 429, message: 'rate limited', data: null);
    var service = buildService(api, () => now, maxAttempts: 4);
    await service.start(refreshInterval: const Duration(hours: 1));

    expect(api.requestedUrls, hasLength(4));
    expect(service.lastRefreshMetrics?.failures, 1);
    expect((await BtsAppRss().read(rss))?.lastFailed, isNot(0));
    service.stop();
  });

  test(
    'retries recover within the same refresh and clear the failure state',
    () async {
      var now = DateTime.now();
      var rss = 'https://example.com/recover.xml';
      await seedSubscription(1, rss);
      await seedCache(
        rss,
        updated: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
      );

      var attempts = 0;
      var api = _FakeMikanApi()
        ..handler = (_) {
          attempts++;
          if (attempts < 3) {
            return BTResponse.error(code: 500, message: 'boom', data: null);
          }
          return BTResponse.success(data: _rssXml);
        };
      var service = buildService(api, () => now);
      await service.start(refreshInterval: const Duration(hours: 1));

      expect(attempts, 3);
      expect(service.lastRefreshMetrics?.successes, 1);
      expect(service.lastRefreshMetrics?.failures, 0);
      expect((await BtsAppRss().read(rss))?.lastFailed, 0);
      service.stop();
    },
  );

  test('a recently failed source is skipped by backoff and recovers after the '
      'window', () async {
    var current = DateTime.now();
    var rss = 'https://example.com/backoff.xml';
    await seedSubscription(1, rss);
    await seedCache(
      rss,
      updated: current
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch,
    );
    await database.update(
      'AppRss',
      {
        'lastFailed': current
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      },
      where: 'rss = ?',
      whereArgs: [rss],
    );

    var api = _FakeMikanApi()
      ..handler = (_) => BTResponse.success(data: _rssXml);
    var service = buildService(api, () => current);
    await service.start(refreshInterval: const Duration(hours: 1));
    expect(api.requestedUrls, isEmpty);
    expect(service.lastRefreshMetrics?.backoffSkips, 1);

    service.stop();
    current = current.add(const Duration(minutes: 6));
    await service.start(refreshInterval: const Duration(hours: 1));

    expect(api.requestedUrls, [rss]);
    expect(service.lastRefreshMetrics?.successes, 1);
    expect((await BtsAppRss().read(rss))?.lastFailed, 0);
    service.stop();
  });

  test('cancelPendingRefresh stops scheduling the remaining sources', () async {
    var now = DateTime.now();
    var rss1 = 'https://example.com/cancel-1.xml';
    var rss2 = 'https://example.com/cancel-2.xml';
    await seedSubscription(1, rss1);
    await seedSubscription(2, rss2);
    await seedCache(
      rss1,
      updated: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
    await seedCache(
      rss2,
      updated: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
    );

    late BmfRssService service;
    var firstRequest = true;
    var api = _FakeMikanApi()
      ..handler = (url) {
        if (firstRequest) {
          firstRequest = false;
          service.cancelPendingRefresh();
        }
        return BTResponse.success(data: _rssXml);
      };
    service = buildService(api, () => now, concurrency: 1);
    await service.start(refreshInterval: const Duration(hours: 1));

    expect(api.requestedUrls, hasLength(1));
    expect(service.lastRefreshMetrics?.requested, 2);
    expect(service.lastRefreshMetrics?.successes, 1);
    service.stop();
  });
}

class _FakeMikanApi extends BtrMikanApi {
  final Map<String, BTResponse> responses = {};
  final List<String> requestedUrls = [];
  BTResponse Function(String url)? handler;

  @override
  Future<BTResponse> getCustomRSS(
    String url, {
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) async {
    requestedUrls.add(url);
    if (handler != null) return handler!(url);
    return responses[url] ??
        BTResponse.error(code: 500, message: 'not stubbed', data: null);
  }
}
