// Dart imports:
import 'dart:async';
import 'dart:collection';

class RequestPoolCancelled implements Exception {
  const RequestPoolCancelled();
}

class _Request<T> {
  _Request(this.key, this.action);
  final String key;
  final Future<T> Function() action;
  final Completer<T> result = Completer<T>();
}

/// All callers share a concurrency budget and requests with the same key.
class KeyedRequestPool<T> {
  KeyedRequestPool({required this.maxConcurrent}) {
    if (maxConcurrent < 1) throw ArgumentError.value(maxConcurrent);
  }

  final int maxConcurrent;
  final Map<String, _Request<T>> _requests = {};
  final Queue<_Request<T>> _queue = Queue();
  int _active = 0;

  Future<T> run(String key, Future<T> Function() action) {
    var existing = _requests[key];
    if (existing != null) return existing.result.future;
    var request = _Request(key, action);
    _requests[key] = request;
    _queue.add(request);
    _pump();
    return request.result.future;
  }

  /// Active operations finish normally; queued operations can be retried later.
  void cancelPending() {
    while (_queue.isNotEmpty) {
      var request = _queue.removeFirst();
      _requests.remove(request.key);
      request.result.completeError(const RequestPoolCancelled());
    }
  }

  void _pump() {
    while (_active < maxConcurrent && _queue.isNotEmpty) {
      _active++;
      unawaited(_execute(_queue.removeFirst()));
    }
  }

  Future<void> _execute(_Request<T> request) async {
    try {
      request.result.complete(await request.action());
    } catch (error, stack) {
      request.result.completeError(error, stack);
    } finally {
      _requests.remove(request.key);
      _active--;
      _pump();
    }
  }
}
