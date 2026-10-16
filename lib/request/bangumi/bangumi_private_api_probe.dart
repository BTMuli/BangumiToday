// Dart imports:
import 'dart:async';

// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import '../../core/constants/app_constants.dart';
import '../../data/parsers/bangumi_private_parser.dart';
import '../core/client.dart';
import 'bangumi_error_handler.dart';

enum BangumiPrivateProbeEndpoint {
  calendar('每日放送', '/p1/calendar'),
  subject('条目详情', '/p1/subjects/8'),
  episodes('章节列表', '/p1/subjects/8/episodes?limit=1');

  const BangumiPrivateProbeEndpoint(this.label, this.path);

  final String label;
  final String path;

  bool accepts(dynamic data) {
    if (data is! Map) return false;
    switch (this) {
      case calendar:
        if (!List.generate(
          7,
          (index) => '${index + 1}',
        ).any(data.containsKey)) {
          return false;
        }
        BangumiPrivateParser.calendar(data);
        return true;
      case subject:
        if (data['id'] != 8 || data['nameCN'] is! String) return false;
        BangumiPrivateParser.subject(data);
        return true;
      case episodes:
        var rows = data['data'];
        var total = data['total'];
        if (rows is! List ||
            rows.isEmpty ||
            total is! int ||
            total < rows.length) {
          return false;
        }
        for (var row in rows) {
          if (row is! Map ||
              row['subjectID'] != 8 ||
              row['nameCN'] is! String) {
            return false;
          }
          BangumiPrivateParser.episode(row);
        }
        return true;
    }
  }
}

enum BangumiPrivateProbeStatus { waiting, running, passed, failed }

class BangumiPrivateProbeResult {
  const BangumiPrivateProbeResult(
    this.endpoint, {
    this.status = BangumiPrivateProbeStatus.waiting,
    this.message = '',
    this.elapsed,
  });

  final BangumiPrivateProbeEndpoint endpoint;
  final BangumiPrivateProbeStatus status;
  final String message;
  final Duration? elapsed;

  bool get completed =>
      status == BangumiPrivateProbeStatus.passed ||
      status == BangumiPrivateProbeStatus.failed;
}

class BangumiPrivateProbeProgress {
  BangumiPrivateProbeProgress(Iterable<BangumiPrivateProbeResult> results)
    : results = List.unmodifiable(results);

  factory BangumiPrivateProbeProgress.initial() => BangumiPrivateProbeProgress(
    BangumiPrivateProbeEndpoint.values.map(BangumiPrivateProbeResult.new),
  );

  final List<BangumiPrivateProbeResult> results;

  int get completed => results.where((result) => result.completed).length;
  bool get finished => completed == BangumiPrivateProbeEndpoint.values.length;
  bool get allPassed =>
      finished &&
      results.every(
        (result) => result.status == BangumiPrivateProbeStatus.passed,
      );
}

/// 无认证、无缓存的公开 /p1 探测；沿用应用代理和请求总时限。
class BangumiPrivateApiProbe {
  BangumiPrivateApiProbe(String apiBaseUrl, {BtrClient? client})
    : baseUrl = BTAppConstants.bangumiPrivateApiBaseUrlFor(apiBaseUrl),
      _client = client ?? BtrClient.withHeader();

  static const requestTimeout = Duration(seconds: 10);

  final String baseUrl;
  final BtrClient _client;
  final CancelToken _cancelToken = CancelToken();

  Stream<BangumiPrivateProbeProgress> run() {
    late StreamController<BangumiPrivateProbeProgress> controller;
    controller = StreamController(
      onListen: () => unawaited(_run(controller)),
      onCancel: dispose,
    );
    return controller.stream;
  }

  Future<void> _run(
    StreamController<BangumiPrivateProbeProgress> controller,
  ) async {
    if (_cancelToken.isCancelled) {
      await controller.close();
      return;
    }
    var results = [
      for (var endpoint in BangumiPrivateProbeEndpoint.values)
        BangumiPrivateProbeResult(
          endpoint,
          status: BangumiPrivateProbeStatus.running,
        ),
    ];
    controller.add(BangumiPrivateProbeProgress(results));

    Future<void> test(int index) async {
      if (_cancelToken.isCancelled) return;
      var endpoint = results[index].endpoint;
      var stopwatch = Stopwatch()..start();
      var status = BangumiPrivateProbeStatus.failed;
      String message;
      try {
        var response = await _client.dio.get(
          '$baseUrl${endpoint.path}',
          options: Options(extra: {'requestTimeout': requestTimeout}),
          cancelToken: _cancelToken,
        );
        var httpStatus = response.statusCode ?? 0;
        if (httpStatus < 200 || httpStatus >= 300) {
          message = 'HTTP $httpStatus，接口请求失败';
        } else if (!endpoint.accepts(response.data)) {
          message = 'HTTP $httpStatus，返回数据不符合 P1 接口格式';
        } else {
          status = BangumiPrivateProbeStatus.passed;
          message = 'HTTP $httpStatus，P1 响应正常';
        }
      } on DioException catch (error) {
        if (_cancelToken.isCancelled) return;
        message = handleBangumiDioException(
          error,
          fallbackMessage: 'P1 接口测试失败',
        ).message;
      } catch (_) {
        message = '返回数据不符合 P1 接口格式';
      }
      if (_cancelToken.isCancelled) return;
      stopwatch.stop();
      results[index] = BangumiPrivateProbeResult(
        endpoint,
        status: status,
        message: message,
        elapsed: stopwatch.elapsed,
      );
      controller.add(BangumiPrivateProbeProgress(results));
    }

    try {
      await Future.wait(List.generate(results.length, test));
    } finally {
      await controller.close();
    }
  }

  void dispose() {
    _cancelToken.cancel('P1 接口测试已取消');
    _client.dispose();
  }
}
