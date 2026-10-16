// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// Package imports:
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Project imports:
import 'package:bangumi_today/core/constants/app_constants.dart';
import 'package:bangumi_today/request/bangumi/bangumi_private_api_probe.dart';
import 'package:bangumi_today/request/core/client.dart';

class _ProbeAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  late FutureOr<ResponseBody> Function(RequestOptions, Future<void>?) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return await respond(options, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

dynamic fixture(String name) => jsonDecode(
  File('test/bangumi/fixtures/private_api/$name.json').readAsStringSync(),
);

ResponseBody response(dynamic data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

dynamic payload(RequestOptions options) => switch (options.uri.path) {
  '/p1/calendar' => fixture('calendar'),
  '/p1/subjects/8' => fixture('subject'),
  '/p1/subjects/8/episodes' => {
    'total': 25,
    'data': (fixture('episodes')['data'] as List).take(1).toList(),
  },
  _ => throw StateError('Unexpected probe: ${options.uri}'),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'BangumiToday',
    packageName: 'bangumi_today',
    version: '1',
    buildNumber: '1',
    buildSignature: '',
  );

  late BtrClient client;
  late _ProbeAdapter adapter;

  setUp(() {
    client = BtrClient.withHeader();
    adapter = _ProbeAdapter()
      ..respond = (options, _) => response(payload(options));
    client.dio.httpClientAdapter = adapter;
  });

  tearDown(() => client.dispose());

  BangumiPrivateApiProbe probeFor([
    String origin = BTAppConstants.bgmapiBangumiApiBaseUrl,
  ]) {
    var probe = BangumiPrivateApiProbe(origin, client: client);
    addTearDown(probe.dispose);
    return probe;
  }

  test('progress only allows enabling once all three probes pass', () async {
    expect(BangumiPrivateProbeProgress.initial().allPassed, isFalse);
    var updates = await probeFor().run().toList();
    expect(updates, hasLength(4));
    expect(updates.map((progress) => progress.completed), [0, 1, 2, 3]);
    expect(updates.take(3).every((progress) => !progress.allPassed), isTrue);
    expect(updates.last.finished, isTrue);
    expect(updates.last.allPassed, isTrue);
    expect(
      updates.last.results.every((result) => result.elapsed != null),
      isTrue,
    );
    expect(updates.first.results.last.completed, isFalse);
    expect(() => updates.last.results.clear(), throwsUnsupportedError);
    expect(adapter.requests, hasLength(3));
    for (var request in adapter.requests) {
      expect(request.method, 'GET');
      expect(request.data, isNull);
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(request.headers.containsKey('Cookie'), isFalse);
      expect(
        request.extra['requestTimeout'],
        BangumiPrivateApiProbe.requestTimeout,
      );
    }
  });

  test(
    'all probes start concurrently and report independent results',
    () async {
      var pending = <String, Completer<ResponseBody>>{};
      adapter.respond = (options, _) {
        var completer = Completer<ResponseBody>();
        pending[options.uri.path] = completer;
        return completer.future;
      };
      var updates = <BangumiPrivateProbeProgress>[];
      var done = probeFor().run().forEach(updates.add);
      await pumpEventQueue();
      expect(adapter.requests, hasLength(3));
      expect(pending, hasLength(3));
      expect(
        updates.last.results.every(
          (result) => result.status == BangumiPrivateProbeStatus.running,
        ),
        isTrue,
      );

      var episodes = adapter.requests.last;
      pending[episodes.uri.path]!.complete(response(payload(episodes)));
      await pumpEventQueue();
      expect(updates.last.completed, 1);
      expect(updates.last.allPassed, isFalse);
      expect(
        updates.last.results.last.status,
        BangumiPrivateProbeStatus.passed,
      );
      for (var request in adapter.requests.take(2)) {
        pending[request.uri.path]!.complete(response(payload(request)));
      }
      await done;
      expect(updates.last.allPassed, isTrue);
    },
  );

  for (var origin in [
    BTAppConstants.officialBangumiApiBaseUrl,
    BTAppConstants.bgmapiBangumiApiBaseUrl,
    BTAppConstants.bangumiVipApiBaseUrl,
    'http://api.example.test:8081',
  ]) {
    test('probes the intended P1 origin for $origin before enabling', () async {
      var progress = await probeFor(origin).run().last;
      var target = origin == BTAppConstants.officialBangumiApiBaseUrl
          ? 'https://next.bgm.tv'
          : origin;
      expect(progress.allPassed, isTrue);
      expect(adapter.requests.map((request) => request.uri.toString()), [
        '$target/p1/calendar',
        '$target/p1/subjects/8',
        '$target/p1/subjects/8/episodes?limit=1',
      ]);
    });
  }

  for (var invalid in <String, dynamic>{
    'HTML': '<html><title>502 Bad Gateway</title></html>',
    'business 404': {'code': 404, 'error': 'Not Found'},
    'empty JSON': <String, dynamic>{},
    'legacy fields': {'id': 8, 'name_cn': '旧版数据'},
  }.entries) {
    test('HTTP 200 with ${invalid.key} cannot pass validation', () async {
      adapter.respond = (_, _) => response(invalid.value);
      var progress = await probeFor().run().last;
      expect(progress.finished, isTrue);
      expect(progress.allPassed, isFalse);
      expect(
        progress.results.every(
          (result) => result.status == BangumiPrivateProbeStatus.failed,
        ),
        isTrue,
      );
    });
  }

  for (var endpoint in BangumiPrivateProbeEndpoint.values) {
    test('one failed ${endpoint.label} probe blocks enabling', () async {
      adapter.respond = (options, _) => response(
        payload(options),
        status: options.uri.path == Uri.parse(endpoint.path).path ? 401 : 200,
      );
      var progress = await probeFor().run().last;
      expect(progress.finished, isTrue);
      expect(progress.allPassed, isFalse);
      expect(adapter.requests, hasLength(3));
      var failed = progress.results.singleWhere(
        (result) => result.status == BangumiPrivateProbeStatus.failed,
      );
      expect(failed.endpoint, endpoint);
      expect(failed.message, contains('HTTP 401'));
    });
  }

  test('malformed nested P1 data cannot pass', () async {
    adapter.respond = (options, _) => response(switch (options.uri.path) {
      '/p1/calendar' => {'1': <String, dynamic>{}},
      '/p1/subjects/8' => {'id': 8, 'nameCN': '缺少完整字段'},
      _ => {
        'total': 25,
        'data': [
          {'id': 522, 'subjectID': 99, 'nameCN': '错误条目'},
        ],
      },
    });
    var progress = await probeFor().run().last;
    expect(progress.finished, isTrue);
    expect(progress.allPassed, isFalse);
    expect(
      progress.results.every(
        (result) => result.status == BangumiPrivateProbeStatus.failed,
      ),
      isTrue,
    );
  });

  test(
    'timeout is reported and remaining endpoints are still tested',
    () async {
      adapter.respond = (options, _) {
        if (options.uri.path == '/p1/calendar') {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
          );
        }
        return response(payload(options));
      };
      var progress = await probeFor().run().last;
      expect(progress.finished, isTrue);
      expect(progress.allPassed, isFalse);
      expect(progress.results.first.message, contains('超时'));
      expect(adapter.requests, hasLength(3));
    },
  );

  test(
    'closing a probe cancels its request and stops further probes',
    () async {
      var started = Completer<void>();
      adapter.respond = (options, cancelFuture) async {
        if (adapter.requests.length == 3) started.complete();
        await cancelFuture;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        );
      };
      var probe = probeFor();
      var updates = <BangumiPrivateProbeProgress>[];
      var done = probe.run().forEach(updates.add);
      await started.future;
      probe.dispose();
      await done;
      expect(adapter.requests, hasLength(3));
      expect(updates.last.finished, isFalse);
      expect(updates.last.allPassed, isFalse);
    },
  );

  test('cancelled probes do not start requests', () async {
    var probe = probeFor()..dispose();
    expect(await probe.run().toList(), isEmpty);
    expect(adapter.requests, isEmpty);
  });
}
