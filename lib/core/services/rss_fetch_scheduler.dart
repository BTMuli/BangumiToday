// Dart imports:
import 'dart:async';
import 'dart:math';

// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import '../../models/app/response.dart';
import '../../models/rss/rss_request_failure.dart';
import '../utils/keyed_request_pool.dart';

/// Retries share one feed result, but only HTTP attempts occupy network slots.
class RssFetchScheduler {
  RssFetchScheduler({
    required this.request,
    int maxConcurrent = 4,
    this.maxAttempts = 4,
    this.requestTimeout = const Duration(seconds: 15),
    this.refreshTimeout = const Duration(minutes: 1),
  }) : _requests = KeyedRequestPool(
         maxConcurrent: maxConcurrent,
         maxConcurrentPerGroup: 2,
       );

  final Future<BTResponse> Function(String, CancelToken, Duration) request;
  final int maxAttempts;
  final Duration requestTimeout;
  final Duration refreshTimeout;
  final KeyedRequestPool<BTResponse> _requests;
  final Map<String, Future<BTResponse>> _feeds = {};

  int get peakConcurrency => _requests.peakConcurrency;
  void resetPeakConcurrency() => _requests.resetPeakConcurrency();
  void cancelPending() => _requests.cancelPending();

  Future<BTResponse> fetch(String key, String url, CancelToken cancelToken) =>
      _feeds.putIfAbsent(key, () {
        late Future<BTResponse> flight;
        flight = _fetch(key, url, cancelToken).whenComplete(() {
          if (identical(_feeds[key], flight)) _feeds.remove(key);
        });
        return flight;
      });

  Future<BTResponse> _fetch(
    String key,
    String url,
    CancelToken cancelToken,
  ) async {
    var clock = Stopwatch()..start();
    BTResponse response = BTResponse.error(
      code: 666,
      message: 'RSS 刷新超过总时限',
      data: null,
    );
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (cancelToken.isCancelled) throw const RequestPoolCancelled();
      if (clock.elapsed >= refreshTimeout) return response;
      response = await _requests.run(key, () async {
        if (cancelToken.isCancelled) throw const RequestPoolCancelled();
        var remaining = refreshTimeout - clock.elapsed;
        if (remaining <= Duration.zero) return response;
        return request(
          url,
          cancelToken,
          remaining < requestTimeout ? remaining : requestTimeout,
        );
      }, group: Uri.parse(url).host);
      if (cancelToken.isCancelled) throw const RequestPoolCancelled();
      var failure = response.data;
      if (response.code == 0 ||
          attempt + 1 == maxAttempts ||
          failure is! RssRequestFailure ||
          !failure.retryable) {
        return response;
      }
      var delay =
          failure.retryAfter ??
          Duration(milliseconds: 1000 * (2 << attempt) + Random().nextInt(300));
      if (clock.elapsed + delay >= refreshTimeout) return response;
      await _wait(delay, cancelToken);
    }
    return response;
  }

  Future<void> _wait(Duration delay, CancelToken cancelToken) async {
    var ready = Completer<void>();
    var timer = Timer(delay, ready.complete);
    var cancellation = cancelToken.whenCancel.asStream().listen((_) {
      if (!ready.isCompleted) {
        ready.completeError(const RequestPoolCancelled());
      }
    });
    try {
      await ready.future;
    } finally {
      timer.cancel();
      await cancellation.cancel();
    }
  }
}
