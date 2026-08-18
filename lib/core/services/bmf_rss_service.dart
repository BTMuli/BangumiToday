// Dart imports:
import 'dart:async';
import 'dart:math';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Project imports:
import '../../database/app/app_bmf.dart';
import '../../database/app/app_config.dart';
import '../../database/app/app_rss.dart';
import '../../main.dart';
import '../../models/app/response.dart';
import '../../models/database/app_bmf_model.dart';
import '../../models/database/app_rss_model.dart';
import '../../models/rss/rss.dart';
import '../../plugins/mikan/mikan_api.dart';
import '../../store/bmf_store.dart';
import '../../store/nav_store.dart';
import '../../tools/log_tool.dart';
import '../../tools/notifier_tool.dart';
import '../constants/app_constants.dart';
import '../utils/async_pool.dart';
import 'rss_freshness.dart';

class BmfRssUpdateEvent {
  final String key;
  final String rssData;
  final List<RssItem> items;
  final DateTime updated;
  final Set<String> pendingItemKeys;

  BmfRssUpdateEvent({
    required this.key,
    required this.rssData,
    required this.items,
    required this.updated,
    required this.pendingItemKeys,
  });
}

class BmfRssStatusEvent {
  final int subject;
  final int pendingCount;

  const BmfRssStatusEvent({required this.subject, required this.pendingCount});
}

class _RssRefreshResult {
  final bool success;
  final List<RssItem> newItems;

  const _RssRefreshResult({required this.success, this.newItems = const []});
}

class _RssSubscriptionUpdate {
  final AppBmfModel bmf;
  final List<RssItem> newItems;

  const _RssSubscriptionUpdate({required this.bmf, required this.newItems});
}

/// 一次全量 RSS 刷新的请求与命中指标。
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

  /// 候选订阅总数。
  final int total;

  /// 命中 freshness 缓存、未发起请求的订阅数。
  final int cacheHits;

  /// 实际发起网络请求的订阅数。
  final int requested;

  /// 本次刷新成功的订阅数。
  final int successes;

  /// 本次刷新失败的订阅数。
  final int failures;

  /// 处于退避窗口内被跳过的订阅数。
  final int backoffSkips;

  /// 刷新期间的峰值并发数。
  final int peakConcurrency;

  /// 全量刷新耗时（毫秒）。
  final int elapsedMs;
}

class BmfRssService {
  BmfRssService._({
    BtrMikanApi? api,
    DateTime Function()? now,
    Duration freshnessWindow = defaultFreshnessWindow,
    int concurrency = defaultConcurrency,
    Duration connectTimeout = defaultTimeout,
    Duration receiveTimeout = defaultTimeout,
    int maxAttempts = defaultMaxAttempts,
    Duration retryBaseDelay = const Duration(seconds: 1),
    Duration maxBackoffDelay = const Duration(minutes: 2),
    Duration recoveryWindow = const Duration(minutes: 5),
    Duration Function()? jitter,
  }) : _api = api ?? BtrMikanApi(),
       _now = now ?? DateTime.now,
       _freshness = RssFreshness(window: freshnessWindow),
       _concurrency = concurrency,
       _connectTimeout = connectTimeout,
       _receiveTimeout = receiveTimeout,
       _maxAttempts = maxAttempts,
       _retryBaseDelay = retryBaseDelay,
       _maxBackoffDelay = maxBackoffDelay,
       _recoveryWindow = recoveryWindow,
       _jitter = jitter ?? _defaultJitter;

  /// 仅供测试注入下载引擎 API、时钟与 freshness 窗口。
  @visibleForTesting
  BmfRssService.forTesting({
    BtrMikanApi? api,
    DateTime Function()? now,
    Duration freshnessWindow = defaultFreshnessWindow,
    int concurrency = defaultConcurrency,
    Duration connectTimeout = defaultTimeout,
    Duration receiveTimeout = defaultTimeout,
    int maxAttempts = defaultMaxAttempts,
    Duration retryBaseDelay = const Duration(seconds: 1),
    Duration maxBackoffDelay = const Duration(minutes: 2),
    Duration recoveryWindow = const Duration(minutes: 5),
    Duration Function()? jitter,
  }) : this._(
         api: api,
         now: now,
         freshnessWindow: freshnessWindow,
         concurrency: concurrency,
         connectTimeout: connectTimeout,
         receiveTimeout: receiveTimeout,
         maxAttempts: maxAttempts,
         retryBaseDelay: retryBaseDelay,
         maxBackoffDelay: maxBackoffDelay,
         recoveryWindow: recoveryWindow,
         jitter: jitter,
       );

  static final BmfRssService instance = BmfRssService._();

  /// 默认 freshness 窗口：窗口内热启动与定时刷新直接复用缓存。
  static const Duration defaultFreshnessWindow = Duration(minutes: 30);

  /// 默认并发上限。
  static const int defaultConcurrency = 4;

  /// 默认连接/读取超时。
  static const Duration defaultTimeout = Duration(seconds: 15);

  /// 默认单源最大请求次数（首次 + 重试）。
  static const int defaultMaxAttempts = 4;

  static Duration _defaultJitter() =>
      Duration(milliseconds: Random().nextInt(300));

  factory BmfRssService() => instance;

  final BtsAppBmf _bmfDb = BtsAppBmf();
  final BtsAppRss _rssDb = BtsAppRss();
  final BtsAppConfig _configDb = BtsAppConfig();
  final BtrMikanApi _api;
  final DateTime Function() _now;
  final RssFreshness _freshness;
  final int _concurrency;
  final Duration _connectTimeout;
  final Duration _receiveTimeout;
  final int _maxAttempts;
  final Duration _retryBaseDelay;
  final Duration _maxBackoffDelay;
  final Duration _recoveryWindow;
  final Duration Function() _jitter;

  /// 最近一次全量刷新的指标，用于热启动请求数与缓存命中验证。
  RssRefreshMetrics? lastRefreshMetrics;

  Timer? _refreshTimer;
  final AsyncSingleFlight _startGuard = AsyncSingleFlight();
  final AsyncSingleFlight _bulkRefreshGuard = AsyncSingleFlight();
  final KeyedAsyncSerialExecutor<String> _singleRefreshExecutor =
      KeyedAsyncSerialExecutor<String>();
  final Map<String, Set<String>> _knownItems = {};
  bool _isInitialized = false;
  bool _cancelRequested = false;

  final StreamController<BmfRssUpdateEvent> _updateController =
      StreamController<BmfRssUpdateEvent>.broadcast();
  final StreamController<BmfRssStatusEvent> _statusController =
      StreamController<BmfRssStatusEvent>.broadcast();

  Stream<BmfRssUpdateEvent> get updateStream => _updateController.stream;
  Stream<BmfRssStatusEvent> get statusStream => _statusController.stream;

  bool get isInitialized => _isInitialized;

  Future<void> start({
    Duration refreshInterval = const Duration(minutes: 15),
  }) async {
    if (_isInitialized) {
      BTLogTool.info('BMF RSS 服务已经在运行');
      return;
    }

    await _startGuard.run(() => _start(refreshInterval));
  }

  Future<void> _start(Duration refreshInterval) async {
    BTLogTool.info('BMF RSS 服务启动');
    await _loadKnownItems();
    await _refreshAllRss(respectAutoUpdate: true);

    _refreshTimer = Timer.periodic(refreshInterval, (_) {
      unawaited(_refreshFromTimer());
    });

    _isInitialized = true;
    BTLogTool.info('BMF RSS 服务初始化完成');
  }

  Future<void> _refreshFromTimer() async {
    try {
      await _refreshAllRss(respectAutoUpdate: true);
    } catch (error, stackTrace) {
      BTLogTool.error([
        'BMF RSS 定时刷新失败',
        error.toString(),
        stackTrace.toString(),
      ]);
    }
  }

  void stop() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _isInitialized = false;
    BTLogTool.info('BMF RSS 服务已停止');
  }

  Future<void> _loadKnownItems() async {
    _knownItems.clear();
    var rssModels = await _rssDb.readAll();
    for (var model in rssModels) {
      if (model.data.isNotEmpty) {
        try {
          var items = RssFeed.parse(model.data).items;
          var key = model.mkBgmId != null && model.mkBgmId!.isNotEmpty
              ? model.mkBgmId!
              : model.rss;
          _knownItems[key] = items
              .map((e) => '${e.title ?? ''}|${e.pubDate ?? ''}')
              .toSet();
        } catch (e) {
          BTLogTool.warn('解析 RSS 缓存失败: $e');
        }
      }
    }
  }

  Future<void> _refreshAllRss({
    required bool respectAutoUpdate,
    bool forceRefresh = false,
  }) async {
    await _bulkRefreshGuard.run(
      () => _performRefreshAllRss(
        respectAutoUpdate: respectAutoUpdate,
        forceRefresh: forceRefresh,
      ),
    );
  }

  Future<void> _performRefreshAllRss({
    required bool respectAutoUpdate,
    bool forceRefresh = false,
  }) async {
    var bmfList = await _bmfDb.readAll();
    if (bmfList.isEmpty) {
      BTLogTool.info('没有 BMF 订阅需要刷新');
      return;
    }

    var mikanUrl = await _configDb.readMikanUrl();

    var candidates = bmfList
        .where(
          (bmf) =>
              bmf.rss != null &&
              bmf.rss!.isNotEmpty &&
              (!respectAutoUpdate || bmf.autoUpdate),
        )
        .toList();

    var now = _now();
    _cancelRequested = false;
    var cacheHits = 0;
    var backoffSkips = 0;
    var subscriptions = <AppBmfModel>[];
    for (var bmf in candidates) {
      var url = _getRssUrl(bmf, mikanUrl);
      var cached = await _readCachedModel(bmf, url);
      if (!forceRefresh && _isCacheUsable(cached, now)) {
        cacheHits++;
        continue;
      }
      if (!forceRefresh && _isInBackoff(cached, now)) {
        backoffSkips++;
        continue;
      }
      subscriptions.add(bmf);
    }

    if (subscriptions.isEmpty) {
      lastRefreshMetrics = RssRefreshMetrics(
        total: candidates.length,
        cacheHits: candidates.length,
        requested: 0,
        successes: 0,
        failures: 0,
        backoffSkips: backoffSkips,
        peakConcurrency: 0,
        elapsedMs: 0,
      );
      BTLogTool.info(
        'BMF RSS 全量刷新：共 ${candidates.length} 个订阅，'
        '缓存命中 $cacheHits，退避跳过 $backoffSkips，请求 0，全部复用缓存',
      );
      return;
    }

    BTLogTool.info(
      '开始刷新 ${subscriptions.length} 个 BMF RSS 订阅'
      '（共 ${candidates.length} 个，缓存命中 $cacheHits，退避跳过 $backoffSkips）',
    );

    var startedAt = _now();
    var updates = <_RssSubscriptionUpdate>[];
    var successes = 0;
    var failures = 0;
    var active = 0;
    var peakConcurrency = 0;
    await forEachConcurrent(
      subscriptions,
      maxConcurrent: _concurrency,
      action: (bmf) async {
        if (_cancelRequested) return;
        active++;
        if (active > peakConcurrency) peakConcurrency = active;
        _RssRefreshResult result;
        try {
          result = await _refreshSingleRssInternal(bmf, mikanUrl);
          if (result.success) {
            successes++;
          } else {
            failures++;
          }
        } finally {
          active--;
        }
        if (result.newItems.isNotEmpty) {
          updates.add(
            _RssSubscriptionUpdate(bmf: bmf, newItems: result.newItems),
          );
        }
      },
    );
    await _notifyUpdates(updates);

    var elapsedMs = _now().difference(startedAt).inMilliseconds;
    lastRefreshMetrics = RssRefreshMetrics(
      total: candidates.length,
      cacheHits: cacheHits,
      requested: subscriptions.length,
      successes: successes,
      failures: failures,
      backoffSkips: backoffSkips,
      peakConcurrency: peakConcurrency,
      elapsedMs: elapsedMs,
    );
    BTLogTool.info(
      'BMF RSS 全量刷新完成：共 ${candidates.length} 个订阅，'
      '缓存命中 $cacheHits，退避跳过 $backoffSkips，'
      '成功 $successes，失败 $failures，峰值并发 $peakConcurrency，'
      '耗时 $elapsedMs ms',
    );
  }

  bool _isInBackoff(AppRssModel? cached, DateTime now) {
    if (cached == null || cached.lastFailed <= 0) return false;
    var ageMs = now.millisecondsSinceEpoch - cached.lastFailed;
    return ageMs >= 0 && ageMs < _recoveryWindow.inMilliseconds;
  }

  bool _isCacheUsable(AppRssModel? cached, DateTime now) {
    if (!_freshness.isFresh(cached, now)) return false;
    try {
      RssFeed.parse(cached!.data);
      return true;
    } catch (_) {
      // 缓存损坏按过期处理，重新拉取。
      return false;
    }
  }

  Future<AppRssModel?> _readCachedModel(AppBmfModel bmf, String url) async {
    if (bmf.mkBgmId != null && bmf.mkBgmId!.isNotEmpty) {
      return _rssDb.readByMkId(bmf.mkBgmId!);
    }
    return _rssDb.read(url);
  }

  Future<_RssRefreshResult> _refreshSingleRssInternal(
    AppBmfModel bmf,
    String? mikanUrl, {
    bool resetKnownItems = false,
  }) async {
    var url = _getRssUrl(bmf, mikanUrl);
    var key = _keyForBmf(bmf, url);

    return _singleRefreshExecutor.run(key, () async {
      if (resetKnownItems) _knownItems.remove(key);
      return await _performSingleRssRefresh(bmf, url, key);
    });
  }

  Future<_RssRefreshResult> _performSingleRssRefresh(
    AppBmfModel bmf,
    String url,
    String key,
  ) async {
    AppRssModel? existingModel;
    try {
      existingModel = await _readCachedModel(bmf, url);
      var rssGet = await _fetchWithRetry(url);

      if (rssGet.code != 0 || rssGet.data == null) {
        BTLogTool.warn('刷新 RSS 失败: ${bmf.subject}');
        await _persistRefreshFailure(existingModel, bmf);
        return const _RssRefreshResult(success: false);
      }

      var feed = RssFeed.parse(rssGet.data);
      var currentItems = feed.items;
      var currentKeys = currentItems
          .map((e) => '${e.title ?? ''}|${e.pubDate ?? ''}')
          .toSet();

      var knownKeys = _knownItems[key] ?? <String>{};
      var newItems = currentItems.where((item) {
        var itemKey = '${item.title ?? ""}|${item.pubDate ?? ""}';
        return !knownKeys.contains(itemKey);
      }).toList();
      var pendingItemKeys = existingModel?.pendingItemKeys ?? <String>{};
      if (knownKeys.isNotEmpty) {
        pendingItemKeys.addAll(
          newItems.map((item) => '${item.title ?? ''}|${item.pubDate ?? ''}'),
        );
      }

      _knownItems[key] = currentKeys;

      var appRssModel = AppRssModel(
        rss: url,
        data: rssGet.data,
        ttl: feed.ttl,
        updated: _now().millisecondsSinceEpoch,
        mkBgmId: bmf.mkBgmId,
        mkGroupId: bmf.mkGroupId,
      );
      appRssModel.setPendingItemKeys(pendingItemKeys);
      await _rssDb.write(appRssModel);

      _updateController.add(
        BmfRssUpdateEvent(
          key: key,
          rssData: rssGet.data,
          items: currentItems,
          updated: _now(),
          pendingItemKeys: pendingItemKeys,
        ),
      );
      notifyPendingStateChanged(bmf, pendingItemKeys.length);

      if (newItems.isNotEmpty && knownKeys.isNotEmpty) {
        BTLogTool.info(
          '发现 ${newItems.length} 条新 RSS 更新: ${bmf.title ?? bmf.subject}',
        );
      }

      return _RssRefreshResult(
        success: true,
        newItems: knownKeys.isEmpty ? const [] : newItems,
      );
    } catch (e) {
      BTLogTool.error(['刷新 RSS 异常', 'Subject: ${bmf.subject}', 'Error: $e']);
      await _persistRefreshFailure(existingModel, bmf);
      return const _RssRefreshResult(success: false);
    }
  }

  Future<void> _persistRefreshFailure(
    AppRssModel? existingModel,
    AppBmfModel bmf,
  ) async {
    existingModel ??= AppRssModel(
      rss: bmf.rss ?? '',
      data: '',
      ttl: 0,
      mkBgmId: bmf.mkBgmId,
      mkGroupId: bmf.mkGroupId,
    );
    await _rssDb.markRefreshFailure(existingModel);
  }

  Future<BTResponse> _fetchWithRetry(String url) async {
    var response = await _api.getCustomRSS(
      url,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
    );
    var attempt = 1;
    while (response.code != 0 && attempt < _maxAttempts) {
      if (_cancelRequested) break;
      await Future<void>.delayed(_retryDelay(attempt));
      if (_cancelRequested) break;
      response = await _api.getCustomRSS(
        url,
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
      );
      attempt++;
    }
    return response;
  }

  Duration _retryDelay(int attempt) {
    var baseMs = _retryBaseDelay.inMilliseconds * (1 << attempt);
    if (baseMs > _maxBackoffDelay.inMilliseconds) {
      baseMs = _maxBackoffDelay.inMilliseconds;
    }
    return Duration(milliseconds: baseMs + _jitter().inMilliseconds);
  }

  String _getRssUrl(AppBmfModel bmf, String? mikanUrl) {
    var baseUrl = BTAppConstants.normalizeMikanUrl(mikanUrl);
    if (bmf.mkBgmId == null || bmf.mkBgmId!.isEmpty) {
      return BTAppConstants.rewriteMikanUrl(bmf.rss!, baseUrl);
    }
    var url = '$baseUrl/RSS/Bangumi?bangumiId=${bmf.mkBgmId}';
    if (bmf.mkGroupId != null) {
      url += '&subgroupid=${bmf.mkGroupId}';
    }
    return url;
  }

  String _keyForBmf(AppBmfModel bmf, String fallbackUrl) {
    if (bmf.mkBgmId != null && bmf.mkBgmId!.isNotEmpty) {
      return bmf.mkBgmId!;
    }
    return fallbackUrl;
  }

  Future<void> _notifyUpdates(List<_RssSubscriptionUpdate> updates) async {
    if (updates.isEmpty) return;
    var itemCount = updates.fold<int>(
      0,
      (total, update) => total + update.newItems.length,
    );
    void onClick() {
      globalContainer.read(bmfNavigationProvider).openWorkspace();
      globalContainer.read(navStoreProvider).setCurIndex(1);
    }

    var body = updates.length == 1
        ? '${updates.single.bmf.title ?? '动画 ${updates.single.bmf.subject}'}'
              ' 有 $itemCount 条更新'
        : '${updates.length} 个订阅共有 $itemCount 条更新';
    await BTNotifierTool.showMini(
      title: 'RSS 订阅更新',
      body: body,
      onClick: onClick,
    );
  }

  Future<void> refreshNow() async {
    BTLogTool.info('手动刷新所有 BMF RSS');
    await _refreshAllRss(respectAutoUpdate: false, forceRefresh: true);
  }

  /// 取消当前批次剩余的刷新任务与重试。
  void cancelPendingRefresh() {
    _cancelRequested = true;
  }

  Future<bool> refreshBmf(AppBmfModel bmf) async {
    if (!_isInitialized) return false;
    if (bmf.rss == null || bmf.rss!.isEmpty) return false;
    var mikanUrl = await _configDb.readMikanUrl();
    return _refreshSingleRssAndGetResult(bmf, mikanUrl);
  }

  void notifyPendingStateChanged(AppBmfModel bmf, int pendingCount) {
    _statusController.add(
      BmfRssStatusEvent(subject: bmf.subject, pendingCount: pendingCount),
    );
  }

  Future<bool> onBmfWritten(AppBmfModel bmf) async {
    if (!_isInitialized) return false;
    if (!bmf.autoUpdate || bmf.rss == null || bmf.rss!.isEmpty) return false;

    var mikanUrl = await _configDb.readMikanUrl();

    var result = await _refreshSingleRssAndGetResult(
      bmf,
      mikanUrl,
      resetKnownItems: true,
    );
    if (result) {
      BTLogTool.info('BMF 订阅已更新: ${bmf.title ?? bmf.subject}');
    }
    return result;
  }

  Future<bool> _refreshSingleRssAndGetResult(
    AppBmfModel bmf,
    String? mikanUrl, {
    bool resetKnownItems = false,
  }) async {
    var result = await _refreshSingleRssInternal(
      bmf,
      mikanUrl,
      resetKnownItems: resetKnownItems,
    );
    return result.success;
  }

  Future<void> onBmfDeleted(int subject, String? mkBgmId, String? rss) async {
    if (!_isInitialized) return;

    var key = mkBgmId != null && mkBgmId.isNotEmpty ? mkBgmId : rss;
    if (key != null) {
      _knownItems.remove(key);
    }
    _statusController.add(BmfRssStatusEvent(subject: subject, pendingCount: 0));

    BTLogTool.info('BMF 订阅已移除: subject=$subject');
  }
}
