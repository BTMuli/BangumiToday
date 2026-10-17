// Dart imports:
import 'dart:async';
import 'dart:collection';

class RequestPoolCancelled implements Exception {
  const RequestPoolCancelled();
}

class _Request<T> {
  _Request(this.key, this.action, this.group);
  final String key;
  final Future<T> Function() action;
  final String? group;
  final Completer<T> result = Completer<T>();
}

/// All callers share a concurrency budget and requests with the same key.
class KeyedRequestPool<T> {
  KeyedRequestPool({required this.maxConcurrent, int? maxConcurrentPerGroup})
    : maxConcurrentPerGroup = maxConcurrentPerGroup ?? maxConcurrent {
    if (maxConcurrent < 1) throw ArgumentError.value(maxConcurrent);
    if (this.maxConcurrentPerGroup < 1) {
      throw ArgumentError.value(maxConcurrentPerGroup);
    }
  }

  final int maxConcurrent;
  final int maxConcurrentPerGroup;
  final Map<String, int> _activeGroups = {};
  final Map<String, _Request<T>> _requests = {};
  final Queue<_Request<T>> _queue = Queue();
  int _active = 0;
  int _peakConcurrency = 0;

  int get peakConcurrency => _peakConcurrency;
  void resetPeakConcurrency() => _peakConcurrency = _active;

  Future<T> run(String key, Future<T> Function() action, {String? group}) {
    var existing = _requests[key];
    if (existing != null) return existing.result.future;
    var request = _Request(key, action, group);
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
      var request = _queue.where((request) {
        var group = request.group;
        return group == null ||
            (_activeGroups[group] ?? 0) < maxConcurrentPerGroup;
      }).firstOrNull;
      if (request == null) return;
      _queue.remove(request);
      var group = request.group;
      if (group != null) {
        _activeGroups.update(group, (count) => count + 1, ifAbsent: () => 1);
      }
      _active++;
      if (_active > _peakConcurrency) _peakConcurrency = _active;
      unawaited(_execute(request));
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
      var group = request.group;
      if (group != null &&
          _activeGroups.update(group, (count) => count - 1) == 0) {
        _activeGroups.remove(group);
      }
      _pump();
    }
  }
}
