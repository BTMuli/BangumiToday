// Dart imports:
import 'dart:async';
import 'dart:typed_data';

// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/rss_fetch_scheduler.dart';
import 'package:bangumi_today/core/utils/keyed_request_pool.dart';
import 'package:bangumi_today/core/utils/latest_request.dart';
import 'package:bangumi_today/data/parsers/rss_parser.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/models/rss/rss_request_failure.dart';
import 'package:bangumi_today/request/mikan/mikan_api.dart';

class _HttpResponse implements HttpClientAdapter {
  _HttpResponse(this.status);
  final int status;
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    return ResponseBody.fromString(
      '<rss><channel/></rss>',
      status,
      headers: {
        'retry-after': ['12'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('RSS 请求区分 HTTP 失败、透传总时限并保留 Retry-After', () async {
    for (var status in [200, 404, 429, 503]) {
      var api = BtrMikanApi();
      var adapter = _HttpResponse(status);
      api.client.dio.httpClientAdapter = adapter;
      try {
        var result = await api.getCustomRSS(
          'https://example.invalid/rss.xml',
          requestTimeout: const Duration(seconds: 2),
        );
        expect(
          adapter.options!.extra['requestTimeout'],
          const Duration(seconds: 2),
        );
        if (status == 200) {
          expect(result.code, 0);
          expect(result.data, isA<String>());
        } else {
          expect(result.code, status);
          var failure = result.data as RssRequestFailure;
          expect(failure.retryable, status != 404);
          expect(failure.retryAfter, const Duration(seconds: 12));
        }
      } finally {
        api.client.dispose();
      }
    }
  });

  test('重复搜索共享请求，切换搜索取消旧请求，旧完成不清除新请求', () async {
    var latest = LatestRequest<int>();
    var old = Completer<int>();
    var next = Completer<int>();
    late CancelToken oldToken;
    var first = latest.run('old', (token) {
      oldToken = token;
      return old.future;
    });
    expect(
      identical(first, latest.run('old', (_) => throw StateError('duplicate'))),
      isTrue,
    );
    var second = latest.run('new', (_) => next.future);
    expect(oldToken.isCancelled, isTrue);
    old.complete(1);
    expect(await first, 1);
    expect(
      identical(
        second,
        latest.run('new', (_) => throw StateError('duplicate')),
      ),
      isTrue,
    );
    next.complete(2);
    expect(await second, 2);
    latest.cancel();
  });

  test('单站点并发限制不阻塞其他站点，全局请求仍有上限', () async {
    var pool = KeyedRequestPool<int>(
      maxConcurrent: 3,
      maxConcurrentPerGroup: 1,
    );
    var active = <String>[];
    var pending = <String, Completer<int>>{};
    Future<int> submit(String id, String host) => pool.run(id, () {
      active.add(id);
      return (pending[id] = Completer<int>()).future;
    }, group: host);
    var a = submit('a', 'slow');
    var b = submit('b', 'slow');
    var c = submit('c', 'healthy');
    expect(active, ['a', 'c']);
    expect(pool.peakConcurrency, 2);
    pending['c']!.complete(3);
    expect(await c, 3);
    pending['a']!.complete(1);
    expect(await a, 1);
    await Future<void>.delayed(Duration.zero);
    expect(active, ['a', 'c', 'b']);
    pending['b']!.complete(2);
    expect(await b, 2);
  });

  test('退避释放请求槽并共享整个 feed 的重试结果', () async {
    var order = <String>[];
    var slowAttempts = 0;
    var scheduler = RssFetchScheduler(
      maxConcurrent: 1,
      request: (url, _, timeout) async {
        expect(timeout <= const Duration(seconds: 15), isTrue);
        order.add(url);
        if (url.endsWith('slow') && slowAttempts++ == 0) {
          return BTResponse.error(
            code: 503,
            message: '',
            data: const RssRequestFailure(
              retryable: true,
              retryAfter: Duration(milliseconds: 50),
            ),
          );
        }
        return BTResponse.success(data: 'ok');
      },
    );
    var token = CancelToken();
    var slow = scheduler.fetch('slow', 'https://example.invalid/slow', token);
    expect(
      identical(
        slow,
        scheduler.fetch('slow', 'https://example.invalid/slow', token),
      ),
      isTrue,
    );
    var fast = scheduler.fetch('fast', 'https://example.invalid/fast', token);
    expect((await fast).code, 0);
    expect((await slow).code, 0);
    expect(order.map((url) => url.split('/').last), ['slow', 'fast', 'slow']);
    expect(scheduler.peakConcurrency, 1);
  });

  test('永久失败不重试，Retry-After 超过总预算时立即结束', () async {
    for (var retryable in [false, true]) {
      var count = 0;
      var scheduler = RssFetchScheduler(
        refreshTimeout: const Duration(milliseconds: 20),
        request: (_, token, timeout) async {
          count++;
          return BTResponse.error(
            code: 429,
            message: '',
            data: RssRequestFailure(
              retryable: retryable,
              retryAfter: const Duration(seconds: 60),
            ),
          );
        },
      );
      expect(
        (await scheduler.fetch(
          'feed',
          'https://example.invalid',
          CancelToken(),
        )).code,
        429,
      );
      expect(count, 1);
    }
  });

  test('取消立即结束退避，不发送后续请求', () async {
    var count = 0;
    var token = CancelToken();
    var scheduler = RssFetchScheduler(
      request: (_, token, timeout) async {
        count++;
        return BTResponse.error(
          code: 503,
          message: '',
          data: const RssRequestFailure(
            retryable: true,
            retryAfter: Duration(seconds: 20),
          ),
        );
      },
    );
    var flight = scheduler.fetch('feed', 'https://example.invalid', token);
    var assertion = expectLater(flight, throwsA(isA<RequestPoolCancelled>()));
    await Future<void>.delayed(Duration.zero);
    token.cancel();
    await assertion;
    expect(count, 1);
  });

  test('大型 RSS 后台解析保留命名空间字段，普通 RSS 仍兼容', () async {
    var item =
        '<item><title>Anime</title><description>${'x' * 140000}</description>'
        '<a:bgmId>1</a:bgmId><a:language>CHS</a:language>'
        '<a:language>JP</a:language><a:episodeKey>BATCH</a:episodeKey></item>';
    var feed = await parseRssFeed(
      '<rss xmlns:a="https://anibt.net/xmlns/rss/1.0/">'
      '<channel>$item</channel></rss>',
    );
    expect(feed.items.single.anibt!.bgmId, 1);
    expect(feed.items.single.anibt!.languages, ['CHS', 'JP']);
    expect(feed.items.single.anibt!.episodeLabel, '合集');
    expect(
      (await parseRssFeed(
        '<rss><channel><item><title>Generic</title>'
        '</item></channel></rss>',
      )).items.single.anibt,
      isNull,
    );
  });
}
