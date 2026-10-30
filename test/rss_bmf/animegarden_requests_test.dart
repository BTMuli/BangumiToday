// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/controller/animegarden_controller.dart';
import 'package:bangumi_today/domain/rss/animegarden_query.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/models/rss/animegarden_resource.dart';
import 'package:bangumi_today/request/rss/animegarden_api.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, {this.status = 200});
  final Map<String, dynamic> body;
  final int status;
  int requests = 0;
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    requests++;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        'content-type': ['application/json'],
        'retry-after': ['120'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Pending {
  _Pending(this.query, this.token);
  final AnimeGardenQuery query;
  final CancelToken token;
  final result = Completer<BTResponse>();
}

class _API extends AnimeGardenAPI {
  final requests = <_Pending>[];

  @override
  Future<BTResponse> resources(
    AnimeGardenQuery query, {
    required CancelToken cancelToken,
  }) {
    var request = _Pending(query, cancelToken);
    requests.add(request);
    return request.result.future;
  }
}

Map<String, dynamic> _fixture() =>
    jsonDecode(
          File(
            'test/rss_bmf/fixtures/animegarden/resources.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

AnimeGardenPage _page({int page = 1, bool complete = false}) =>
    AnimeGardenPage.fromJson({
      ..._fixture(),
      'resources': [
        for (var resource in _fixture()['resources'] as List)
          {
            ...resource as Map<String, dynamic>,
            'id': (resource['id'] as int) + (page - 1) * 100,
          },
      ],
      'pagination': {'page': page, 'pageSize': 50, 'complete': complete},
    });

void main() {
  test('HTTP 失败与业务错误不可变为空成功；Retry-After 不叠加重试', () async {
    for (var status in [200, 404, 429, 503, 504]) {
      var api = AnimeGardenAPI();
      addTearDown(api.client.dispose);
      var adapter = _Adapter({'status': 'ERROR'}, status: status);
      api.client.dio.httpClientAdapter = adapter;
      var result = await api.resources(
        const AnimeGardenQuery(),
        cancelToken: CancelToken(),
      );
      expect(result.code, status == 200 ? 666 : status);
      expect(adapter.requests, 1);
      expect(adapter.options!.extra['requestTimeout'], isA<Duration>());
    }
  });

  test('完整查询键去重同一消费者请求，使用实际分页和磁力字段', () async {
    var api = AnimeGardenAPI();
    addTearDown(api.client.dispose);
    var adapter = _Adapter(_fixture());
    api.client.dio.httpClientAdapter = adapter;
    var token = CancelToken();
    const query = AnimeGardenQuery(search: '测试', keywords: ['简日']);
    var results = await Future.wait([
      api.resources(query, cancelToken: token),
      api.resources(query, cancelToken: token),
    ]);
    expect(adapter.requests, 1);
    expect(results.every((r) => r.code == 0), isTrue);
    expect(
      (results.first.data as AnimeGardenPage).pagination.complete,
      isFalse,
    );
    expect(adapter.options!.uri, query.resourceUri);
  });

  test('Retry-After 支持秒数与 HTTP 日期', () {
    var now = DateTime.utc(2026, 10, 30);
    expect(AnimeGardenAPI.retryAfter('12'), const Duration(seconds: 12));
    expect(AnimeGardenAPI.retryAfter('0'), Duration.zero);
    expect(AnimeGardenAPI.retryAfter('-1'), isNull);
    expect(AnimeGardenAPI.retryAfter('bad'), isNull);
    expect(
      AnimeGardenAPI.retryAfter('Fri, 30 Oct 2026 00:01:00 GMT', now: now),
      const Duration(minutes: 1),
    );
    expect(
      AnimeGardenAPI.retryAfter('Thu, 29 Oct 2026 00:00:00 GMT', now: now),
      Duration.zero,
    );
  });

  test('取消后立即查询相同 URL 不复用已取消的请求', () async {
    var api = AnimeGardenAPI();
    addTearDown(api.client.dispose);
    var adapter = _Adapter(_fixture());
    api.client.dio.httpClientAdapter = adapter;
    var cancelled = CancelToken()..cancel();
    var old = api.resources(const AnimeGardenQuery(), cancelToken: cancelled);
    var next = api.resources(
      const AnimeGardenQuery(),
      cancelToken: CancelToken(),
    );
    expect((await old).code, 499);
    expect((await next).code, 0);
    expect(adapter.requests, 1);
  });

  test('切换查询取消旧请求；旧响应不可覆盖；重复查询共享在途工作', () async {
    var api = _API();
    var controller = AnimeGardenController(api: api);
    addTearDown(controller.dispose);
    var first = controller.search(const AnimeGardenQuery(subjects: [42]));
    var repeated = controller.search(const AnimeGardenQuery(subjects: [42]));
    expect(api.requests.length, 1);
    var next = controller.search(const AnimeGardenQuery(search: '标题补充'));
    expect(api.requests.first.token.isCancelled, isTrue);
    expect(api.requests.last.query.subjects, isEmpty);
    api.requests.last.result.complete(BTResponse.success(data: _page()));
    await next;
    api.requests.first.result.complete(
      BTResponse.success(data: _page(page: 8)),
    );
    await Future.wait([first, repeated]);
    expect(controller.query.search, '标题补充');
    expect(controller.page, 1);
    expect(controller.resources.length, 2);
  });

  test('翻页失败保留资源和页码，重试成功后使用 complete，换条件清空', () async {
    var api = _API();
    var controller = AnimeGardenController(api: api);
    addTearDown(controller.dispose);
    var initial = controller.search(const AnimeGardenQuery());
    api.requests.last.result.complete(BTResponse.success(data: _page()));
    await initial;
    var original = controller.resources;
    expect(controller.canGoPrevious, isFalse);
    var next = controller.nextPage();
    expect(api.requests.last.query.page, 2);
    expect(controller.pendingPage, 2);
    expect(controller.page, 1);
    expect(controller.canGoNext, isFalse);
    api.requests.last.result.complete(
      BTResponse.error(code: 503, message: '暂不可用', data: null),
    );
    await next;
    expect(controller.resources, same(original));
    expect(controller.page, 1);
    expect(controller.complete, isFalse);
    expect(controller.error, isNotNull);
    expect(controller.failedPage, 2);
    var retry = controller.retry();
    expect(api.requests.last.query.page, 2);
    api.requests.last.result.complete(
      BTResponse.success(
        data: AnimeGardenPage(
          resources: const [],
          pagination: const AnimeGardenPagination(
            page: 2,
            pageSize: 50,
            complete: true,
          ),
        ),
      ),
    );
    await retry;
    expect(controller.resources, isEmpty);
    expect(controller.page, 2);
    expect(controller.complete, isTrue);
    expect(controller.canGoNext, isFalse);
    expect(controller.canGoPrevious, isTrue);
    expect(controller.failedPage, isNull);
    expect(controller.pendingPage, isNull);
    expect(controller.error, isNull);
    var changed = controller.search(const AnimeGardenQuery(search: '新条件'));
    expect(controller.resources, isEmpty);
    expect(controller.loaded, isFalse);
    expect(controller.page, 0);
    expect(api.requests.last.query.page, 1);
    api.requests.last.result.complete(BTResponse.success(data: _page()));
    await changed;
  });

  test('连续换页只保留当前页，上一页重新请求，最后一页不继续请求', () async {
    var api = _API();
    var controller = AnimeGardenController(api: api);
    addTearDown(controller.dispose);
    await controller.nextPage();
    await controller.previousPage();
    expect(api.requests, isEmpty);
    var initial = controller.search(const AnimeGardenQuery());
    api.requests.last.result.complete(BTResponse.success(data: _page()));
    await initial;
    var initialIds = controller.resources
        .map((resource) => resource.id)
        .toList();
    await controller.previousPage();
    expect(api.requests.length, 1);
    for (var page = 2; page <= 5; page++) {
      var next = controller.nextPage();
      api.requests.last.result.complete(
        BTResponse.success(
          data: _page(page: page, complete: page == 5),
        ),
      );
      await next;
      expect(controller.page, page);
      expect(controller.resources.length, 2);
      expect(
        controller.resources.map((resource) => resource.id),
        isNot(initialIds),
      );
    }
    await controller.nextPage();
    expect(api.requests.length, 5);
    var previous = controller.previousPage();
    expect(api.requests.last.query.page, 4);
    api.requests.last.result.complete(BTResponse.success(data: _page(page: 4)));
    await previous;
    expect(controller.resources.length, 2);
    expect(controller.page, 4);
    expect(controller.canGoNext, isTrue);
    var refresh = controller.refresh();
    expect(api.requests.last.query.page, 4);
    api.requests.last.result.complete(BTResponse.success(data: _page(page: 4)));
    await refresh;
    expect(controller.page, 4);
  });

  test('上一页失败可重试相同目标，保留当前页与筛选条件', () async {
    var api = _API();
    var controller = AnimeGardenController(api: api);
    addTearDown(controller.dispose);
    const query = AnimeGardenQuery(search: '番剧', keywords: ['1080p']);
    var initial = controller.search(query);
    api.requests.last.result.complete(BTResponse.success(data: _page()));
    await initial;
    var next = controller.nextPage();
    api.requests.last.result.complete(BTResponse.success(data: _page(page: 2)));
    await next;
    var resources = controller.resources;
    var previous = controller.previousPage();
    api.requests.last.result.complete(
      BTResponse.error(code: 503, message: '暂不可用', data: null),
    );
    await previous;
    expect(controller.page, 2);
    expect(controller.failedPage, 1);
    expect(controller.resources, same(resources));
    var retry = controller.retry();
    expect(api.requests.last.query.resourceUri, query.resourceUri);
    api.requests.last.result.complete(BTResponse.success(data: _page()));
    await retry;
    expect(controller.page, 1);
    expect(controller.failedPage, isNull);
    expect(controller.resources.length, 2);
  });

  test('翻页期间切换筛选取消旧请求，迟到翻页响应不覆盖新查询', () async {
    var api = _API();
    var controller = AnimeGardenController(api: api);
    addTearDown(controller.dispose);
    var initial = controller.search(const AnimeGardenQuery());
    api.requests.last.result.complete(BTResponse.success(data: _page()));
    await initial;
    var next = controller.nextPage();
    var oldRequest = api.requests.last;
    var changed = controller.search(
      const AnimeGardenQuery(search: '新条件', type: '漫画'),
    );
    expect(api.requests.last.query.resourceUri.queryParameters['type'], '漫画');
    expect(oldRequest.token.isCancelled, isTrue);
    expect(controller.resources, isEmpty);
    api.requests.last.result.complete(BTResponse.success(data: _page()));
    await changed;
    oldRequest.result.complete(BTResponse.success(data: _page(page: 2)));
    await next;
    expect(controller.query.search, '新条件');
    expect(controller.query.type, '漫画');
    expect(controller.page, 1);
    expect(controller.pendingPage, isNull);
    expect(controller.failedPage, isNull);
    expect(controller.resources.length, 2);
  });

  test('释放取消请求，迟到响应不再发布状态', () async {
    var api = _API();
    var controller = AnimeGardenController(api: api);
    var notifications = 0;
    controller.addListener(() => notifications++);
    var request = controller.search(const AnimeGardenQuery());
    controller.dispose();
    expect(api.requests.single.token.isCancelled, isTrue);
    api.requests.single.result.complete(BTResponse.success(data: _page()));
    await request;
    expect(notifications, 1);
  });
}
