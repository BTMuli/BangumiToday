// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/models/rss/animegarden_detail.dart';
import 'package:bangumi_today/request/rss/animegarden_api.dart';

Map<String, dynamic> _fixture() =>
    jsonDecode(
          File(
            'test/rss_bmf/fixtures/animegarden/detail.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, {this.status = 200});
  final Map<String, dynamic> body;
  final int status;
  int requests = 0;
  RequestOptions? options;
  final started = Completer<void>();
  Completer<ResponseBody>? pending;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    requests++;
    if (!started.isCompleted) started.complete();
    if (pending != null) return pending!.future;
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

void main() {
  test('真实详情样本保留正文 HTML、文件大小文本、磁力与抓取时间', () {
    var raw = _fixture();
    var response = AnimeGardenDetailResponse.fromJson(raw);
    var detail = response.detail!;
    expect(response.isDeleted, isFalse);
    expect(detail.id, response.resource.id);
    expect(detail.fetchedAt.isUtc, isTrue);
    expect(detail.description, (raw['detail'] as Map)['description']);
    expect(detail.description, contains('<'));
    expect(detail.files.single.size, '541.5MB');
    expect(detail.magnets.length, 4);
    expect(detail.hasMoreFiles, isFalse);
    expect(
      AnimeGardenDetailResponse.fromJson(
        response.toJson(),
      ).detail!.files.single.name,
      detail.files.single.name,
    );
  });

  test('HTTP 200 缺少详情合法，删除标记、重复 ID 和空详情字段独立保留', () {
    var raw = _fixture()..remove('detail');
    raw['isDeleted'] = null;
    raw['duplicatedId'] = 42;
    var missing = AnimeGardenDetailResponse.fromJson(raw);
    expect(missing.detail, isNull);
    expect(missing.isDeleted, isNull);
    expect(missing.duplicatedId, 42);
    raw = _fixture();
    raw['isDeleted'] = true;
    raw['detail'] = {
      ...raw['detail'] as Map<String, dynamic>,
      'description': '',
      'files': [],
      'magnets': [],
      'hasMoreFiles': true,
    };
    var empty = AnimeGardenDetailResponse.fromJson(raw);
    expect(empty.isDeleted, isTrue);
    expect(empty.detail!.files, isEmpty);
    expect(empty.detail!.hasMoreFiles, isTrue);
  });

  test('业务失败和资源 ID 错配不能当作正常详情', () {
    expect(
      () => AnimeGardenDetailResponse.fromJson({'status': 'ERROR'}),
      throwsFormatException,
    );
    var raw = _fixture();
    (raw['detail'] as Map<String, dynamic>)['id'] = -1;
    expect(
      () => AnimeGardenDetailResponse.fromJson(raw),
      throwsFormatException,
    );
  });

  test('详情按 provider 和 providerId 查询，同一取消作用域合并相同请求', () async {
    var api = AnimeGardenAPI();
    addTearDown(api.client.dispose);
    var adapter = _Adapter(_fixture());
    api.client.dio.httpClientAdapter = adapter;
    var token = CancelToken();
    var results = await Future.wait([
      api.detail('dmhy', '723178', cancelToken: token),
      api.detail('dmhy', '723178', cancelToken: token),
    ]);
    expect(adapter.requests, 1);
    expect(
      adapter.options!.uri.toString(),
      'https://api.animes.garden/detail/dmhy/723178',
    );
    expect(
      results.every(
        (result) =>
            result.code == 0 && result.data is AnimeGardenDetailResponse,
      ),
      isTrue,
    );
  });

  test('来源 ID 作为独立路径段编码，不混入查询参数或片段', () async {
    var api = AnimeGardenAPI();
    addTearDown(api.client.dispose);
    var adapter = _Adapter(_fixture());
    api.client.dio.httpClientAdapter = adapter;
    await api.detail('moe', 'id /#中文?', cancelToken: CancelToken());
    expect(adapter.options!.uri.pathSegments, ['detail', 'moe', 'id /#中文?']);
    expect(adapter.options!.uri.hasQuery, isFalse);
    expect(adapter.options!.uri.hasFragment, isFalse);
  });

  test('无详情与 HTTP/业务错误区分，Retry-After 仍由统一调度处理', () async {
    for (var status in [200, 404, 429, 503, 504]) {
      var api = AnimeGardenAPI();
      addTearDown(api.client.dispose);
      var body = _fixture()..remove('detail');
      var adapter = _Adapter(body, status: status);
      api.client.dio.httpClientAdapter = adapter;
      var response = await api.detail(
        'dmhy',
        '723178',
        cancelToken: CancelToken(),
      );
      expect(adapter.requests, 1);
      expect(response.code, status == 200 ? 0 : status);
      if (status == 200) {
        expect((response.data as AnimeGardenDetailResponse).detail, isNull);
      }
    }
    var api = AnimeGardenAPI();
    addTearDown(api.client.dispose);
    api.client.dio.httpClientAdapter = _Adapter({'status': 'ERROR'});
    expect(
      (await api.detail('dmhy', '723178', cancelToken: CancelToken())).code,
      666,
    );
  });

  test('关闭详情时取消在途请求，迟到响应不改变取消结果', () async {
    var api = AnimeGardenAPI();
    addTearDown(api.client.dispose);
    var adapter = _Adapter(_fixture())..pending = Completer<ResponseBody>();
    api.client.dio.httpClientAdapter = adapter;
    var token = CancelToken();
    var request = api.detail('dmhy', '723178', cancelToken: token);
    await adapter.started.future;
    token.cancel('详情已关闭');
    var result = await request.timeout(const Duration(seconds: 2));
    expect(result.code, 499);
    adapter.pending!.complete(
      ResponseBody.fromString(jsonEncode(_fixture()), 200),
    );
    expect(result.code, 499);
  });
}
