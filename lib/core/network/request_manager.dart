import 'dart:async';

import 'package:dio/dio.dart';

class RequestManager {
  RequestManager._();

  static final RequestManager instance = RequestManager._();

  factory RequestManager() => instance;

  final Map<String, CancelToken> _pendingRequests = {};

  final Map<String, Completer> _deduplicationMap = {};

  bool cancel(String key) {
    var token = _pendingRequests[key];
    if (token != null && !token.isCancelled) {
      token.cancel('Request cancelled');
      _pendingRequests.remove(key);
      return true;
    }
    return false;
  }

  void cancelAll() {
    for (var entry in _pendingRequests.entries) {
      if (!entry.value.isCancelled) {
        entry.value.cancel('All requests cancelled');
      }
    }
    _pendingRequests.clear();
    _deduplicationMap.clear();
  }

  Future<T> request<T>({
    required String key,
    required Future<T> Function(CancelToken token) request,
    bool deduplicate = true,
    bool cancelPrevious = false,
  }) async {
    if (deduplicate && _deduplicationMap.containsKey(key)) {
      return await (_deduplicationMap[key]!.future as Future<T>);
    }

    if (cancelPrevious) {
      cancel(key);
    }

    var token = CancelToken();
    _pendingRequests[key] = token;

    var completer = Completer<T>();
    if (deduplicate) {
      _deduplicationMap[key] = completer;
    }

    try {
      var result = await request(token);
      if (!token.isCancelled) {
        completer.complete(result);
      }
      return result;
    } catch (e) {
      if (!token.isCancelled) {
        completer.completeError(e);
      }
      rethrow;
    } finally {
      _pendingRequests.remove(key);
      if (deduplicate) {
        _deduplicationMap.remove(key);
      }
    }
  }

  Future<T> withRetry<T>({
    required Future<T> Function() request,
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
    bool Function(Exception)? shouldRetry,
  }) async {
    Exception? lastError;

    for (var i = 0; i < maxRetries; i++) {
      try {
        return await request();
      } on DioException catch (e) {
        lastError = e;

        if (e.type == DioExceptionType.cancel) {
          rethrow;
        }

        if (shouldRetry != null && !shouldRetry(e)) {
          rethrow;
        }

        if (i < maxRetries - 1) {
          await Future.delayed(delay * (i + 1));
        }
      } on Exception catch (e) {
        lastError = e;

        if (shouldRetry != null && !shouldRetry(e)) {
          rethrow;
        }

        if (i < maxRetries - 1) {
          await Future.delayed(delay * (i + 1));
        }
      }
    }

    throw lastError ?? Exception('Retry failed');
  }

  bool isPending(String key) {
    return _pendingRequests.containsKey(key) &&
        !_pendingRequests[key]!.isCancelled;
  }

  List<String> get pendingKeys => _pendingRequests.keys.toList();
}

class RequestKey {
  static String calendar() => 'bangumi_calendar';

  static String subjectDetail(int id) => 'subject_detail_$id';

  static String subjectEpisodes(int id) => 'subject_episodes_$id';

  static String userCollection(String username, int subjectId) =>
      'user_collection_${username}_$subjectId';

  static String userCollections(String username) =>
      'user_collections_$username';

  static String search(String keyword, int offset) =>
      'search_${keyword}_$offset';

  static String rss(String source) => 'rss_$source';
}
