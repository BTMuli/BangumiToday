// Dart imports:
import 'dart:async';

// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import '../../database/app/app_bmf.dart';
import '../../database/app/app_subscription.dart';
import '../../database/drift/subscription_storage.dart';
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
import 'rss_fetch_scheduler.dart';
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
  late final RssFetchScheduler _requests = RssFetchScheduler(
    maxConcurrent: defaultConcurrency,
    maxAttempts: defaultMaxAttempts,
    request: (url, token, timeout) => _api.getCustomRSS(
      url,
      preserveRequestUrl: true,
      connectTimeout: defaultTimeout,
      receiveTimeout: defaultTimeout,
      requestTimeout: timeout,
      cancelToken: token,
    ),
  );
  final StreamController<BmfRssUpdateEvent> _updateController =
      StreamController<BmfRssUpdateEvent>.broadcast();
  final StreamController<BmfRssStatusEvent> _statusController =
      StreamController<BmfRssStatusEvent>.broadcast();
  Timer? _refreshTimer;
  bool _isInitialized = false;
  bool _stopped = false;
  Future<void>? _stopFuture;
  final Set<Future<Object?>> _operations = {};
  CancelToken _cancelToken = CancelToken();
  int _refreshEpoch = 0;
  Duration _freshnessWindow = defaultFreshnessWindow;
  RssRefreshMetrics? lastRefreshMetrics;

  SubscriptionStorage get _storage => appSubscriptionStorage;
  Stream<BmfRssUpdateEvent> get updateStream => _updateController.stream;
  Stream<BmfRssStatusEvent> get statusStream => _statusController.stream;
  bool get isInitialized => _isInitialized;

  bool _isCurrent(int epoch) => !_stopped && epoch == _refreshEpoch;

  Future<T> _track<T>(Future<T> Function() action) {
    late Future<T> operation;
    operation = Future<T>.sync(action).whenComplete(() {
      _operations.remove(operation);
    });
    _operations.add(operation);
    return operation;
  }

  Future<void> start({
    Duration refreshInterval = defaultFreshnessWindow,
    Duration checkInterval = defaultCheckInterval,
  }) async {
    if (_isInitialized || _stopped) return;
    await _track(
      () => _startGuard.run(() async {
        var epoch = _refreshEpoch;
        _freshnessWindow = refreshInterval;
        await _refreshAll(respectAutoUpdate: true, epoch: epoch);
        if (!_isCurrent(epoch)) return;
        _refreshTimer = Timer.periodic(
          checkInterval,
          (_) => unawaited(_timerRefresh()),
        );
        _isInitialized = true;
      }),
    );
  }

  Future<void> _timerRefresh() async {
    if (_stopped) return;
    try {
      await _track(() => _refreshAll(respectAutoUpdate: true));
    } catch (error) {
      BTLogTool.warn('BMF RSS 定时刷新失败：${error.runtimeType}');
    }
  }

  /// 永久停止此应用级服务；关闭数据库前等待已接受的操作排空。
  Future<void> stop() => _stopFuture ??= _stop();

  Future<void> _stop() async {
    _stopped = true;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    cancelPendingRefresh();
    _isInitialized = false;
    await Future.wait(
      _operations.toList().map(
        (operation) => operation.then<void>(
          (_) {},
          onError: (Object error, StackTrace _) {
            BTLogTool.warn('RSS 停止时结束刷新：${error.runtimeType}');
          },
        ),
      ),
    );
    _api.client.dispose();
  }

  Future<void> _refreshAll({
    required bool respectAutoUpdate,
    bool force = false,
    int? epoch,
  }) async {
    var refreshEpoch = epoch ?? _refreshEpoch;
    if (!_isCurrent(refreshEpoch)) return;
    await _bulkRefreshGuard.run(() async {
      if (!_isCurrent(refreshEpoch)) return;
      var started = DateTime.now();
      var subscriptions = (await _storage.readAll())
          .where((s) => s.canRefresh && (!respectAutoUpdate || s.autoUpdate))
          .toList();
      if (!_isCurrent(refreshEpoch)) return;
      var caches = await _storage.readCacheMetadata();
      if (!_isCurrent(refreshEpoch)) return;
      var groups = <String, List<AppSubscriptionModel>>{};
      var cacheHits = 0;
      var backoff = 0;
      var freshness = RssFreshness(window: _freshnessWindow);
      var byFeed = <String, List<AppSubscriptionModel>>{};
      for (var subscription in subscriptions) {
        byFeed.putIfAbsent(subscription.feedKey, () => []).add(subscription);
      }
      for (var entry in byFeed.entries) {
        if (!_isCurrent(refreshEpoch)) return;
        var cache = caches[entry.key];
        if (!force && freshness.isMetadataFresh(cache, started)) {
          var withoutBaseline = entry.value.where((s) => !s.hasBaseline);
          if (withoutBaseline.isEmpty) {
            cacheHits += entry.value.length;
            continue;
          }
          try {
            var cachedFeed = await _storage.readCache(entry.key);
            if (!_isCurrent(refreshEpoch)) return;
            if (freshness.isFresh(cachedFeed, started)) {
              await _apply(
                entry.key,
                cachedFeed!.requestUrl,
                withoutBaseline.map((s) => s.id).toList(),
                cachedFeed.data!,
                cachedFeed.lastSuccessAt,
                epoch: refreshEpoch,
                fromCache: true,
              );
              cacheHits += entry.value.length;
              continue;
            }
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
          backoff += entry.value.length;
          continue;
        }
        groups[entry.key] = entry.value;
      }
      var successes = 0;
      var failures = 0;
      _requests.resetPeakConcurrency();
      await Future.wait(
        groups.values.map((group) async {
          if (!_isCurrent(refreshEpoch)) return;
          if (await _refreshGroup(group, refreshEpoch)) {
            successes++;
          } else {
            failures++;
          }
        }),
      );
      lastRefreshMetrics = RssRefreshMetrics(
        total: subscriptions.length,
        cacheHits: cacheHits,
        requested: successes + failures,
        successes: successes,
        failures: failures,
        backoffSkips: backoff,
        peakConcurrency: _requests.peakConcurrency,
        elapsedMs: DateTime.now().difference(started).inMilliseconds,
      );
      if (successes + failures > 0) {
        BTLogTool.info(
          'BMF RSS 刷新：${subscriptions.length} 个订阅，'
          '缓存 $cacheHits，退避 $backoff，请求 ${successes + failures} 个 feed，'
          '成功 $successes，失败 $failures，'
          '峰值并发 ${_requests.peakConcurrency}，'
          '耗时 ${lastRefreshMetrics!.elapsedMs} ms',
        );
      }
    });
  }

  Future<bool> _refreshGroup(
    List<AppSubscriptionModel> group,
    int epoch,
  ) async {
    if (group.isEmpty || !_isCurrent(epoch)) return false;
    var first = group.first;
    var ids = group.map((s) => s.id).toList();
    try {
      var response = await _requests.fetch(
        '$epoch:${first.feedKey}',
        first.url,
        _cancelToken,
      );
      if (!_isCurrent(epoch)) return false;
      if (response.code != 0 || response.data is! String) {
        throw const FormatException('RSS request failed');
      }
      await _apply(
        first.feedKey,
        first.url,
        ids,
        response.data as String,
        DateTime.now().millisecondsSinceEpoch,
        epoch: epoch,
      );
      return true;
    } on RequestPoolCancelled {
      return false;
    } catch (error) {
      if (!_isCurrent(epoch)) return false;
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
    required int epoch,
    bool fromCache = false,
  }) async {
    if (!_isCurrent(epoch)) return;
    var feed = await parseRssFeed(xml);
    if (!_isCurrent(epoch)) return;
    var updates = await _storage.applyFeed(
      feedKey: feedKey,
      requestUrl: url,
      subscriptionIds: ids,
      xml: xml,
      at: at,
      fromCache: fromCache,
      parsedFeed: feed,
    );
    if (!_isCurrent(epoch)) return;
    var summaries = await _storage.readBmfSummaries(
      updates.map((update) => update.subscription.bmfId),
    );
    if (!_isCurrent(epoch)) return;
    var items = feed.items;
    var notifications = <int, String>{};
    var itemCount = 0;
    for (var update in updates) {
      var bmf = summaries[update.subscription.bmfId];
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
      if (update.newItems.isNotEmpty) {
        notifications[bmf.subject] = bmf.title ?? '动画 ${bmf.subject}';
        itemCount += update.newItems.length;
      }
    }
    for (var bmf in summaries.values) {
      _statusController.add(
        BmfRssStatusEvent(subject: bmf.subject, pendingCount: bmf.pendingCount),
      );
    }
    if (notifications.isNotEmpty) {
      try {
        await BTNotifierTool.showMini(
          title: 'RSS 订阅更新',
          body: '${notifications.values.join('、')} 有 $itemCount 条更新',
          onClick: () {
            if (_stopped) return;
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

  Future<void> notifySubscriptionStateChanged(int id) async {
    if (_stopped) return;
    var epoch = _refreshEpoch;
    await _track(() async {
      var subscription = await _storage.read(id);
      if (subscription == null || !_isCurrent(epoch)) return;
      var summaries = await _storage.readBmfSummaries([subscription.bmfId]);
      var bmf = summaries[subscription.bmfId];
      if (bmf == null || !_isCurrent(epoch)) return;
      _statusController.add(
        BmfRssStatusEvent(
          subject: bmf.subject,
          subscriptionId: id,
          pendingCount: bmf.pendingCount,
        ),
      );
    });
  }

  /// 立即刷新自动更新的订阅；[includeManual] 为 true 时包含手动更新的订阅。
  Future<void> refreshNow({bool includeManual = false}) async {
    if (_stopped) return;
    var epoch = _refreshEpoch;
    await _track(
      () => _forcedRefreshGuard.run(() async {
        // A forced refresh must not be swallowed by an in-flight cache check.
        if (_bulkRefreshGuard.isRunning) {
          await _bulkRefreshGuard.run(() async {});
        }
        await _refreshAll(
          respectAutoUpdate: !includeManual,
          force: true,
          epoch: epoch,
        );
      }),
    );
  }

  void cancelPendingRefresh() {
    _refreshEpoch++;
    _cancelToken.cancel('RSS 刷新已取消');
    _cancelToken = CancelToken();
    _requests.cancelPending();
  }

  Future<bool> refreshSubscription(int id) async {
    if (_stopped) return false;
    var epoch = _refreshEpoch;
    return _track(() async {
      var subscription = await _storage.read(id);
      if (subscription == null || !subscription.canRefresh) return false;
      return _refreshGroup([subscription], epoch);
    });
  }

  Future<bool> refreshBmf(AppBmfModel bmf) async {
    if (_stopped) return false;
    var epoch = _refreshEpoch;
    return _track(() async {
      var current = await BtsAppBmf().read(bmf.subject);
      if (current == null || !_isCurrent(epoch)) return false;
      var results = await Future.wait(
        current.subscriptions
            .where((s) => s.canRefresh)
            .map((s) => _refreshGroup([s], epoch)),
      );
      return results.isNotEmpty && results.every((r) => r);
    });
  }

  bool willRefreshOnWrite(AppBmfModel bmf) =>
      !_stopped &&
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
    if (_stopped) return;
    _statusController.add(BmfRssStatusEvent(subject: subject, pendingCount: 0));
  }
}
