// Dart imports:
import 'dart:async';
import 'dart:math';

// Project imports:
import '../../database/app/app_bmf.dart';
import '../../database/app/app_subscription.dart';
import '../../database/drift/subscription_storage.dart';
import '../../models/app/response.dart';
import '../../models/database/app_bmf_model.dart';
import '../../models/database/app_subscription_model.dart';
import '../../models/rss/rss.dart';
import '../../request/mikan/mikan_api.dart';
import '../../store/bmf_store.dart';
import '../../store/nav_store.dart';
import '../../tools/log_tool.dart';
import '../container.dart';
import '../utils/async_pool.dart';
import 'notification_service.dart';
import 'rss_freshness.dart';

class BmfRssUpdateEvent {
  const BmfRssUpdateEvent({
    required this.subscriptionId,
    required this.subject,
    required this.rssData,
    required this.items,
    required this.updated,
    required this.pendingItemKeys,
  });
  final int subscriptionId;
  final int subject;
  String get key => subscriptionId.toString();
  final String rssData;
  final List<RssItem> items;
  final DateTime updated;
  final Set<String> pendingItemKeys;
}

class BmfRssStatusEvent {
  const BmfRssStatusEvent({
    required this.subject,
    required this.pendingCount,
    this.subscriptionId,
  });
  final int subject;
  final int pendingCount;
  final int? subscriptionId;
}

class RssRefreshMetrics {
  const RssRefreshMetrics({
    required this.total,
    required this.cacheHits,
    required this.requested,
    required this.successes,
    required this.failures,
    required this.backoffSkips,
    required this.peakConcurrency,
    required this.elapsedMs,
  });
  final int total;
  final int cacheHits;
  final int requested;
  final int successes;
  final int failures;
  final int backoffSkips;
  final int peakConcurrency;
  final int elapsedMs;
}

class BmfRssService {
  BmfRssService._();
  static final BmfRssService instance = BmfRssService._();
  factory BmfRssService() => instance;

  static const defaultFreshnessWindow = Duration(minutes: 30);
  static const defaultConcurrency = 4;
  static const defaultTimeout = Duration(seconds: 15);
  static const defaultMaxAttempts = 4;

  final BtrMikanApi _api = BtrMikanApi();
  final AsyncSingleFlight _startGuard = AsyncSingleFlight();
  final AsyncSingleFlight _bulkRefreshGuard = AsyncSingleFlight();
  final Map<String, Future<BTResponse>> _requests = {};
  final StreamController<BmfRssUpdateEvent> _updateController =
      StreamController<BmfRssUpdateEvent>.broadcast();
  final StreamController<BmfRssStatusEvent> _statusController =
      StreamController<BmfRssStatusEvent>.broadcast();
  Timer? _refreshTimer;
  bool _isInitialized = false;
  bool _cancelRequested = false;
  RssRefreshMetrics? lastRefreshMetrics;

  SubscriptionStorage get _storage => appSubscriptionStorage;
  Stream<BmfRssUpdateEvent> get updateStream => _updateController.stream;
  Stream<BmfRssStatusEvent> get statusStream => _statusController.stream;
  bool get isInitialized => _isInitialized;

  Future<void> start({
    Duration refreshInterval = const Duration(minutes: 15),
  }) async {
    if (_isInitialized) return;
    await _startGuard.run(() async {
      await _refreshAll(respectAutoUpdate: true);
      _refreshTimer = Timer.periodic(
        refreshInterval,
        (_) => unawaited(_timerRefresh()),
      );
      _isInitialized = true;
    });
  }

  Future<void> _timerRefresh() async {
    try {
      await _refreshAll(respectAutoUpdate: true);
    } catch (error) {
      BTLogTool.warn('BMF RSS 定时刷新失败：${error.runtimeType}');
    }
  }

  void stop() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _cancelRequested = true;
    _isInitialized = false;
  }

  Future<void> _refreshAll({
    required bool respectAutoUpdate,
    bool force = false,
  }) async {
    await _bulkRefreshGuard.run(() async {
      var started = DateTime.now();
      var subscriptions = (await _storage.readAll())
          .where((s) => s.canRefresh && (!respectAutoUpdate || s.autoUpdate))
          .toList();
      var caches = await _storage.readCaches();
      var groups = <String, List<AppSubscriptionModel>>{};
      var cacheHits = 0;
      var backoff = 0;
      var freshness = const RssFreshness(window: defaultFreshnessWindow);
      for (var subscription in subscriptions) {
        var cache = caches[subscription.feedKey];
        if (!force && freshness.isFresh(cache, started)) {
          try {
            await _apply(
              subscription.feedKey,
              cache!.requestUrl,
              [subscription.id],
              cache.data!,
              cache.lastSuccessAt,
            );
            cacheHits++;
            continue;
          } on FormatException {
            // Invalid XML is rebuilt by the normal request path.
          }
        }
        if (!force &&
            cache != null &&
            cache.lastFailedAt > 0 &&
            started.millisecondsSinceEpoch - cache.lastFailedAt >= 0 &&
            started.millisecondsSinceEpoch - cache.lastFailedAt <
                const Duration(minutes: 5).inMilliseconds) {
          backoff++;
          continue;
        }
        groups.putIfAbsent(subscription.feedKey, () => []).add(subscription);
      }
      _cancelRequested = false;
      var successes = 0;
      var failures = 0;
      var active = 0;
      var peak = 0;
      await forEachConcurrent(
        groups.values,
        maxConcurrent: defaultConcurrency,
        action: (group) async {
          if (_cancelRequested) return;
          active++;
          if (active > peak) peak = active;
          try {
            if (await _refreshGroup(group)) {
              successes++;
            } else {
              failures++;
            }
          } finally {
            active--;
          }
        },
      );
      lastRefreshMetrics = RssRefreshMetrics(
        total: subscriptions.length,
        cacheHits: cacheHits,
        requested: successes + failures,
        successes: successes,
        failures: failures,
        backoffSkips: backoff,
        peakConcurrency: peak,
        elapsedMs: DateTime.now().difference(started).inMilliseconds,
      );
      BTLogTool.info(
        'BMF RSS 刷新：${subscriptions.length} 个订阅，'
        '缓存 $cacheHits，退避 $backoff，请求 ${successes + failures} 个 feed，'
        '成功 $successes，失败 $failures，峰值并发 $peak',
      );
    });
  }

  Future<bool> _refreshGroup(List<AppSubscriptionModel> group) async {
    if (group.isEmpty) return false;
    var first = group.first;
    var ids = group.map((s) => s.id).toList();
    try {
      var request = _requests[first.feedKey];
      if (request == null) {
        request = _fetchWithRetry(first.url);
        _requests[first.feedKey] = request;
        request = request.whenComplete(() => _requests.remove(first.feedKey));
        _requests[first.feedKey] = request;
      }
      var response = await request;
      if (response.code != 0 || response.data is! String) {
        throw const FormatException('RSS request failed');
      }
      await _apply(
        first.feedKey,
        first.url,
        ids,
        response.data as String,
        DateTime.now().millisecondsSinceEpoch,
      );
      return true;
    } catch (error) {
      BTLogTool.warn(
        'RSS 刷新失败：subscription=${first.id}，'
        '${error.runtimeType}',
      );
      await _storage.recordFailure(
        first.feedKey,
        first.url,
        ids,
        DateTime.now().millisecondsSinceEpoch,
      );
      return false;
    }
  }

  Future<void> _apply(
    String feedKey,
    String url,
    List<int> ids,
    String xml,
    int at,
  ) async {
    var updates = await _storage.applyFeed(
      feedKey: feedKey,
      requestUrl: url,
      subscriptionIds: ids,
      xml: xml,
      at: at,
    );
    var items = RssFeed.parse(xml).items;
    var notifications = <String>[];
    var itemCount = 0;
    for (var update in updates) {
      var bmf = await _bmfFor(update.subscription);
      if (bmf == null) continue;
      _updateController.add(
        BmfRssUpdateEvent(
          subscriptionId: update.subscription.id,
          subject: bmf.subject,
          rssData: xml,
          items: items,
          updated: DateTime.fromMillisecondsSinceEpoch(at),
          pendingItemKeys: update.subscription.pendingItemKeys,
        ),
      );
      await notifySubscriptionStateChanged(update.subscription.id);
      if (update.newItems.isNotEmpty) {
        notifications.add(bmf.title ?? '动画 ${bmf.subject}');
        itemCount += update.newItems.length;
      }
    }
    if (notifications.isNotEmpty) {
      try {
        await BTNotifierTool.showMini(
          title: 'RSS 订阅更新',
          body: '${notifications.join('、')} 有 $itemCount 条更新',
          onClick: () {
            globalContainer
                .read(bmfNavigationProvider.notifier)
                .openWorkspace();
            globalContainer.read(navStoreProvider.notifier).setCurIndex(1);
          },
        );
      } catch (error) {
        BTLogTool.warn('RSS 通知失败：${error.runtimeType}');
      }
    }
  }

  Future<AppBmfModel?> _bmfFor(AppSubscriptionModel subscription) async {
    var query = _storage.db.select(_storage.db.appBmf)
      ..where((b) => b.id.equals(subscription.bmfId));
    var row = await query.getSingleOrNull();
    return row == null ? null : BtsAppBmf().read(row.subject);
  }

  Future<void> notifySubscriptionStateChanged(int id) async {
    var subscription = await _storage.read(id);
    if (subscription == null) return;
    var bmf = await _bmfFor(subscription);
    if (bmf == null) return;
    var count = bmf.subscriptions.fold<int>(
      0,
      (sum, s) => sum + s.pendingItemKeys.length,
    );
    _statusController.add(
      BmfRssStatusEvent(
        subject: bmf.subject,
        subscriptionId: id,
        pendingCount: count,
      ),
    );
  }

  Future<BTResponse> _fetchWithRetry(String url) async {
    var response = await _api.getCustomRSS(
      url,
      preserveRequestUrl: true,
      connectTimeout: defaultTimeout,
      receiveTimeout: defaultTimeout,
    );
    for (
      var attempt = 1;
      response.code != 0 && attempt < defaultMaxAttempts && !_cancelRequested;
      attempt++
    ) {
      await Future<void>.delayed(
        Duration(milliseconds: 1000 * (1 << attempt) + Random().nextInt(300)),
      );
      if (_cancelRequested) break;
      response = await _api.getCustomRSS(
        url,
        preserveRequestUrl: true,
        connectTimeout: defaultTimeout,
        receiveTimeout: defaultTimeout,
      );
    }
    return response;
  }

  Future<void> refreshNow() =>
      _refreshAll(respectAutoUpdate: false, force: true);
  void cancelPendingRefresh() => _cancelRequested = true;

  Future<bool> refreshSubscription(int id) async {
    var subscription = await _storage.read(id);
    if (subscription == null || !subscription.canRefresh) return false;
    return _refreshGroup([subscription]);
  }

  Future<bool> refreshBmf(AppBmfModel bmf) async {
    var current = await BtsAppBmf().read(bmf.subject);
    if (current == null) return false;
    var results = await Future.wait(
      current.subscriptions
          .where((s) => s.canRefresh)
          .map((s) => refreshSubscription(s.id)),
    );
    return results.isNotEmpty && results.every((r) => r);
  }

  bool willRefreshOnWrite(AppBmfModel bmf) =>
      _isInitialized &&
      bmf.subscriptions.any((s) => s.canRefresh && s.autoUpdate);

  Future<bool> onBmfWritten(AppBmfModel bmf) async {
    if (!willRefreshOnWrite(bmf)) return false;
    var subscriptions = bmf.subscriptions
        .where((s) => s.canRefresh && s.autoUpdate)
        .toList();
    var results = await Future.wait(
      subscriptions.map((s) => refreshSubscription(s.id)),
    );
    return results.every((r) => r);
  }

  Future<void> onBmfDeleted(int subject) async {
    _statusController.add(BmfRssStatusEvent(subject: subject, pendingCount: 0));
  }
}
