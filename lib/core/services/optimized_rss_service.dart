import 'dart:async';

import 'package:dart_rss/dart_rss.dart';
import 'package:dio/dio.dart';

import '../../core/cache/lru_cache_manager.dart';
import '../../core/network/request_manager.dart';
import '../../models/app/response.dart';
import '../../request/core/client.dart';
import '../../tools/log_tool.dart';

class RssCacheEntry {
  final List<RssItem> items;
  final DateTime fetchTime;
  final String? etag;
  final String? lastModified;
  final int ttl;

  RssCacheEntry({
    required this.items,
    required this.fetchTime,
    this.etag,
    this.lastModified,
    this.ttl = 3600,
  });

  bool get isExpired {
    var expiresAt = fetchTime.add(Duration(seconds: ttl));
    return DateTime.now().isAfter(expiresAt);
  }

  Map<String, dynamic> toJson() => {
        'items': items
            .map((e) => {
                  'title': e.title,
                  'link': e.link,
                  'description': e.description,
                  'pubDate': e.pubDate,
                  'author': e.author,
                })
            .toList(),
        'fetchTime': fetchTime.toIso8601String(),
        'etag': etag,
        'lastModified': lastModified,
        'ttl': ttl,
      };

  static RssCacheEntry? fromJson(Map<String, dynamic> json) {
    try {
      var items = (json['items'] as List).map((e) {
        var itemMap = e as Map<String, dynamic>;
        return RssItem(
          title: itemMap['title'] as String?,
          link: itemMap['link'] as String?,
          description: itemMap['description'] as String?,
          pubDate: itemMap['pubDate'] as String?,
          author: itemMap['author'] as String?,
        );
      }).toList();

      return RssCacheEntry(
        items: items,
        fetchTime: DateTime.parse(json['fetchTime']),
        etag: json['etag'],
        lastModified: json['lastModified'],
        ttl: json['ttl'] ?? 3600,
      );
    } catch (_) {
      return null;
    }
  }
}

class IncrementalRssResult {
  final List<RssItem> newItems;
  final List<RssItem> allItems;
  final bool hasNewItems;
  final DateTime lastFetchTime;

  IncrementalRssResult({
    required this.newItems,
    required this.allItems,
    required this.hasNewItems,
    required this.lastFetchTime,
  });
}

class OptimizedRssService {
  OptimizedRssService._();

  static final OptimizedRssService instance = OptimizedRssService._();

  factory OptimizedRssService() => instance;

  final LRUCacheManager _cacheManager = LRUCacheManager.instance;
  final RequestManager _requestManager = RequestManager.instance;

  final Duration _defaultCacheDuration = const Duration(minutes: 15);
  final Duration _maxCacheDuration = const Duration(hours: 6);

  Future<BTResponse<IncrementalRssResult>> fetchRssIncremental(
    String url, {
    bool forceRefresh = false,
    Duration? cacheDuration,
  }) async {
    var cacheKey = 'rss_${url.hashCode}';
    var effectiveCacheDuration = cacheDuration ?? _defaultCacheDuration;

    if (!forceRefresh) {
      var cachedEntry = await _cacheManager.getJson<RssCacheEntry>(
        cacheKey,
        fromJson: (json) => RssCacheEntry.fromJson(json)!,
        maxAge: effectiveCacheDuration,
      );

      if (cachedEntry != null && !cachedEntry.isExpired) {
        return BTResponse.success(
          data: IncrementalRssResult(
            newItems: [],
            allItems: cachedEntry.items,
            hasNewItems: false,
            lastFetchTime: cachedEntry.fetchTime,
          ),
        );
      }
    }

    var cachedEntry = await _cacheManager.getJson<RssCacheEntry>(
      cacheKey,
      fromJson: (json) => RssCacheEntry.fromJson(json)!,
      maxAge: _maxCacheDuration,
    );

    var headers = <String, String>{};
    if (cachedEntry?.etag != null) {
      headers['If-None-Match'] = cachedEntry!.etag!;
    }
    if (cachedEntry?.lastModified != null) {
      headers['If-Modified-Since'] = cachedEntry!.lastModified!;
    }

    try {
      var client = BtrClient();
      var response = await client.dio.get(
        url,
        options: Options(headers: headers),
      );

      if (response.statusCode == 304) {
        if (cachedEntry != null) {
          await _cacheManager.setJson(
            cacheKey,
            cachedEntry,
            toJson: (e) => e.toJson(),
          );

          return BTResponse.success(
            data: IncrementalRssResult(
              newItems: [],
              allItems: cachedEntry.items,
              hasNewItems: false,
              lastFetchTime: cachedEntry.fetchTime,
            ),
          );
        }
      }

      var feed = RssFeed.parse(response.data.toString());
      var newItems = feed.items;

      var etag = response.headers.value('etag');
      var lastModified = response.headers.value('last-modified');
      var ttl = feed.ttl > 0 ? feed.ttl : 3600;

      var newEntry = RssCacheEntry(
        items: newItems,
        fetchTime: DateTime.now(),
        etag: etag,
        lastModified: lastModified,
        ttl: ttl,
      );

      await _cacheManager.setJson(
        cacheKey,
        newEntry,
        toJson: (e) => e.toJson(),
      );

      var oldItems = cachedEntry?.items ?? [];
      var oldLinks = oldItems.map((e) => e.link).toSet();
      var actualNewItems =
          newItems.where((e) => !oldLinks.contains(e.link)).toList();

      return BTResponse.success(
        data: IncrementalRssResult(
          newItems: actualNewItems,
          allItems: newItems,
          hasNewItems: actualNewItems.isNotEmpty,
          lastFetchTime: newEntry.fetchTime,
        ),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return BTResponse.error(
          code: -1,
          message: 'Request cancelled',
          data: null,
        );
      }

      if (cachedEntry != null) {
        BTLogTool.warn('RSS fetch failed, returning cached data: $url');
        return BTResponse.success(
          data: IncrementalRssResult(
            newItems: [],
            allItems: cachedEntry.items,
            hasNewItems: false,
            lastFetchTime: cachedEntry.fetchTime,
          ),
        );
      }

      return BTResponse.error(
        code: e.response?.statusCode ?? 500,
        message: 'Failed to fetch RSS: ${e.message}',
        data: null,
      );
    } catch (e) {
      if (cachedEntry != null) {
        BTLogTool.warn('RSS fetch failed, returning cached data: $url');
        return BTResponse.success(
          data: IncrementalRssResult(
            newItems: [],
            allItems: cachedEntry.items,
            hasNewItems: false,
            lastFetchTime: cachedEntry.fetchTime,
          ),
        );
      }

      return BTResponse.error(
        code: 500,
        message: 'Failed to fetch RSS: $e',
        data: null,
      );
    }
  }

  Future<BTResponse<List<RssItem>>> fetchMultipleRss(
    List<String> urls, {
    bool parallel = true,
    void Function(String url, int completed, int total)? onProgress,
  }) async {
    var allItems = <RssItem>[];
    int completed = 0;

    if (parallel) {
      var futures = urls.map((url) async {
        var result = await fetchRssIncremental(url);
        completed++;
        onProgress?.call(url, completed, urls.length);
        return result;
      });

      var results = await Future.wait(futures);

      for (var result in results) {
        if (result.code == 0 && result.data != null) {
          allItems.addAll(result.data!.allItems);
        }
      }
    } else {
      for (var url in urls) {
        var result = await fetchRssIncremental(url);
        completed++;
        onProgress?.call(url, completed, urls.length);

        if (result.code == 0 && result.data != null) {
          allItems.addAll(result.data!.allItems);
        }
      }
    }

    allItems.sort((a, b) {
      var dateA = a.pubDate != null ? DateTime.tryParse(a.pubDate!) : null;
      var dateB = b.pubDate != null ? DateTime.tryParse(b.pubDate!) : null;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    return BTResponse.success(data: allItems);
  }

  void cancelRequest(String url) {
    var cacheKey = 'rss_${url.hashCode}';
    _requestManager.cancel(cacheKey);
  }

  void cancelAllRequests() {
    _requestManager.cancelAll();
  }

  Future<void> clearCache() async {
    await _cacheManager.clearExpired();
  }

  Future<void> clearAllCache() async {
    await _cacheManager.clear();
  }

  Future<Map<String, dynamic>> getCacheStats() async {
    return _cacheManager.getCacheStats();
  }
}

class RssSubscriptionManager {
  RssSubscriptionManager._();

  static final RssSubscriptionManager instance = RssSubscriptionManager._();

  factory RssSubscriptionManager() => instance;

  final OptimizedRssService _rssService = OptimizedRssService.instance;
  final Map<String, Timer> _refreshTimers = {};
  final StreamController<RssUpdateEvent> _updateController =
      StreamController<RssUpdateEvent>.broadcast();

  Stream<RssUpdateEvent> get updateStream => _updateController.stream;

  final Map<String, List<RssItem>> _subscriptions = {};

  List<RssItem> getSubscriptionItems(String url) {
    return _subscriptions[url] ?? [];
  }

  Future<void> subscribe(
    String url, {
    Duration refreshInterval = const Duration(minutes: 30),
    bool fetchImmediately = true,
  }) async {
    if (_refreshTimers.containsKey(url)) return;

    if (fetchImmediately) {
      await _refreshSubscription(url);
    }

    _refreshTimers[url] = Timer.periodic(refreshInterval, (_) async {
      await _refreshSubscription(url);
    });
  }

  Future<void> _refreshSubscription(String url) async {
    var result = await _rssService.fetchRssIncremental(url);

    if (result.code == 0 && result.data != null) {
      _subscriptions[url] = result.data!.allItems;

      _updateController.add(RssUpdateEvent(
        url: url,
        newItems: result.data!.newItems,
        allItems: result.data!.allItems,
        hasNewItems: result.data!.hasNewItems,
      ));
    }
  }

  void unsubscribe(String url) {
    _refreshTimers[url]?.cancel();
    _refreshTimers.remove(url);
    _subscriptions.remove(url);
  }

  void unsubscribeAll() {
    for (var timer in _refreshTimers.values) {
      timer.cancel();
    }
    _refreshTimers.clear();
    _subscriptions.clear();
  }

  Future<void> refreshAll() async {
    for (var url in _refreshTimers.keys) {
      await _refreshSubscription(url);
    }
  }

  List<String> get subscribedUrls => _refreshTimers.keys.toList();

  void dispose() {
    unsubscribeAll();
    _updateController.close();
  }
}

class RssUpdateEvent {
  final String url;
  final List<RssItem> newItems;
  final List<RssItem> allItems;
  final bool hasNewItems;

  RssUpdateEvent({
    required this.url,
    required this.newItems,
    required this.allItems,
    required this.hasNewItems,
  });
}
