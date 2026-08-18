// Package imports:
import 'package:dio/dio.dart';

class _DeduplicatedRequest {
  final Future<dynamic> future;

  const _DeduplicatedRequest(this.future);
}

class RequestManager {
  RequestManager._();

  static final RequestManager instance = RequestManager._();

  factory RequestManager() => instance;

  final Map<String, CancelToken> _pendingRequests = {};

  final Map<String, _DeduplicatedRequest> _deduplicationMap = {};

  bool cancel(String key) {
    var token = _pendingRequests[key];
    if (token != null && !token.isCancelled) {
      token.cancel('Request cancelled');
      _pendingRequests.remove(key);
      _deduplicationMap.remove(key);
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
    if (cancelPrevious) {
      cancel(key);
    } else if (deduplicate && _deduplicationMap.containsKey(key)) {
      return await (_deduplicationMap[key]!.future as Future<T>);
    }

    _deduplicationMap.remove(key);

    var token = CancelToken();
    _pendingRequests[key] = token;

    var requestFuture = _executeRequest(key, token, request);
    if (deduplicate) {
      _deduplicationMap[key] = _DeduplicatedRequest(requestFuture);
    }

    return await requestFuture;
  }

  Future<T> _executeRequest<T>(
    String key,
    CancelToken token,
    Future<T> Function(CancelToken token) request,
  ) async {
    try {
      return await Future<T>.microtask(() => request(token));
    } finally {
      if (identical(_pendingRequests[key], token)) {
        _pendingRequests.remove(key);
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

  static String subjectEpisodes(int id, {int? offset, int? limit}) {
    if (offset == null && limit == null) {
      return 'subject_episodes_$id';
    }
    return 'subject_episodes_${id}_${offset ?? 0}_${limit ?? 0}';
  }

  static String userCollection(String username, int subjectId) =>
      'user_collection_${username}_$subjectId';

  static String userCollectionEpisodes(
    int subjectId, {
    int? offset,
    int? limit,
  }) {
    return 'user_collection_episodes_${subjectId}_'
        '${offset ?? 0}_${limit ?? 0}';
  }

  static String userCollections(String username) =>
      'user_collections_$username';

  static String search(String keyword, int offset, {List<String>? tag}) {
    if (tag == null || tag.isEmpty) return 'search_${keyword}_$offset';
    return 'search_${keyword}_${offset}_tag_${tag.join('|')}';
  }

  static String rss(String source) => 'rss_$source';
}
