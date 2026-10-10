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
import '../utils/keyed_request_pool.dart';
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

  static const defaultFreshnessWindow = Duration(minutes: 15);
  // Check deadlines often enough that a slow fetch cannot cost another cycle.
  static const defaultCheckInterval = Duration(minutes: 1);
  static const defaultConcurrency = 4;
  static const defaultTimeout = Duration(seconds: 15);
  static const defaultMaxAttempts = 4;

  final BtrMikanApi _api = BtrMikanApi();
  final AsyncSingleFlight _startGuard = AsyncSingleFlight();
  final AsyncSingleFlight _bulkRefreshGuard = AsyncSingleFlight();
  final AsyncSingleFlight _forcedRefreshGuard = AsyncSingleFlight();
  final KeyedRequestPool<BTResponse> _requests = KeyedRequestPool(
    maxConcurrent: defaultConcurrency,
  );
  final StreamController<BmfRssUpdateEvent> _updateController =
      StreamController<BmfRssUpdateEvent>.broadcast();
  final StreamController<BmfRssStatusEvent> _statusController =
      StreamController<BmfRssStatusEvent>.broadcast();
  Timer? _refreshTimer;
  bool _isInitialized = false;
  bool _cancelRequested = false;
  int _refreshEpoch = 0;
  Duration _freshnessWindow = defaultFreshnessWindow;
  RssRefreshMetrics? lastRefreshMetrics;

  SubscriptionStorage get _storage => appSubscriptionStorage;
  Stream<BmfRssUpdateEvent> get updateStream => _updateController.stream;
  Stream<BmfRssStatusEvent> get statusStream => _statusController.stream;
  bool get isInitialized => _isInitialized;

  Future<void> start({
    Duration refreshInterval = defaultFreshnessWindow,
    Duration checkInterval = defaultCheckInterval,
  }) async {
    if (_isInitialized) return;
    await _startGuard.run(() async {
      _freshnessWindow = refreshInterval;
      await _refreshAll(respectAutoUpdate: true);
      _refreshTimer = Timer.periodic(
        checkInterval,
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
    cancelPendingRefresh();
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
      var parsedCaches = <String, RssFeed>{};
      var groups = <String, List<AppSubscriptionModel>>{};
      var cacheHits = 0;
      var backoff = 0;
      var freshness = RssFreshness(window: _freshnessWindow);
      for (var subscription in subscriptions) {
        var cache = caches[subscription.feedKey];
        if (!force && freshness.isFresh(cache, started)) {
          if (subscription.hasBaseline) {
            cacheHits++;
            continue;
          }
          try {
            await _apply(
              subscription.feedKey,
              cache!.requestUrl,
              [subscription.id],
              cache.data!,
              cache.lastSuccessAt,
              fromCache: true,
              parsedFeed: parsedCaches.putIfAbsent(
                subscription.feedKey,
                () => RssFeed.parse(cache.data!),
              ),
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
      if (successes + failures > 0) {
        BTLogTool.info(
          'BMF RSS 刷新：${subscriptions.length} 个订阅，'
          '缓存 $cacheHits，退避 $backoff，请求 ${successes + failures} 个 feed，'
          '成功 $successes，失败 $failures，峰值并发 $peak',
        );
      }
    });
  }

  Future<bool> _refreshGroup(List<AppSubscriptionModel> group) async {
    if (group.isEmpty) return false;
    var first = group.first;
    var ids = group.map((s) => s.id).toList();
    try {
      var epoch = _refreshEpoch;
      var response = await _requests.run(
        first.feedKey,
        () => _fetchWithRetry(first.url, epoch),
      );
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
    } on RequestPoolCancelled {
      return false;
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
    int at, {
    bool fromCache = false,
    RssFeed? parsedFeed,
  }) async {
    var feed = parsedFeed ?? RssFeed.parse(xml);
    var updates = await _storage.applyFeed(
      feedKey: feedKey,
      requestUrl: url,
      subscriptionIds: ids,
      xml: xml,
      at: at,
      fromCache: fromCache,
      parsedFeed: feed,
    );
    var items = feed.items;
    var notifications = <int, String>{};
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
        notifications[bmf.subject] = bmf.title ?? '动画 ${bmf.subject}';
        itemCount += update.newItems.length;
      }
    }
    if (notifications.isNotEmpty) {
      try {
        await BTNotifierTool.showMini(
          title: 'RSS 订阅更新',
          body: '${notifications.values.join('、')} 有 $itemCount 条更新',
          onClick: () {
            var navigation = globalContainer.read(
              bmfNavigationProvider.notifier,
            );
            if (notifications.length == 1) {
              navigation.selectSubject(notifications.keys.single);
            } else {
              navigation.openPendingUpdates();
            }
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

  Future<BTResponse> _fetchWithRetry(String url, int epoch) async {
    if (epoch != _refreshEpoch) throw const RequestPoolCancelled();
    var response = await _api.getCustomRSS(
      url,
      preserveRequestUrl: true,
      connectTimeout: defaultTimeout,
      receiveTimeout: defaultTimeout,
    );
    for (
      var attempt = 1;
      response.code != 0 && attempt < defaultMaxAttempts;
      attempt++
    ) {
      if (epoch != _refreshEpoch) throw const RequestPoolCancelled();
      await Future<void>.delayed(
        Duration(milliseconds: 1000 * (1 << attempt) + Random().nextInt(300)),
      );
      if (epoch != _refreshEpoch) throw const RequestPoolCancelled();
      response = await _api.getCustomRSS(
        url,
        preserveRequestUrl: true,
        connectTimeout: defaultTimeout,
        receiveTimeout: defaultTimeout,
      );
    }
    if (response.code != 0 && epoch != _refreshEpoch) {
      throw const RequestPoolCancelled();
    }
    return response;
  }

  /// 立即刷新自动更新的订阅；[includeManual] 为 true 时包含手动更新的订阅。
  Future<void> refreshNow({bool includeManual = false}) =>
      _forcedRefreshGuard.run(() async {
        // A forced refresh must not be swallowed by an in-flight cache check.
        if (_bulkRefreshGuard.isRunning) {
          await _bulkRefreshGuard.run(() async {});
        }
        await _refreshAll(respectAutoUpdate: !includeManual, force: true);
      });
  void cancelPendingRefresh() {
    _cancelRequested = true;
    _refreshEpoch++;
    _requests.cancelPending();
  }

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
