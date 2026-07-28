import 'dart:async';

import 'package:dart_rss/domain/rss_feed.dart';
import 'package:dart_rss/domain/rss_item.dart';

import '../../database/app/app_bmf.dart';
import '../../database/app/app_config.dart';
import '../../database/app/app_rss.dart';
import '../../main.dart';
import '../../models/database/app_bmf_model.dart';
import '../../models/database/app_rss_model.dart';
import '../../plugins/mikan/mikan_api.dart';
import '../../store/bmf_store.dart';
import '../../store/nav_store.dart';
import '../../tools/log_tool.dart';
import '../../tools/notifier_tool.dart';

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

class BmfRssService {
  BmfRssService._();

  static final BmfRssService instance = BmfRssService._();

  factory BmfRssService() => instance;

  final BtsAppBmf _bmfDb = BtsAppBmf();
  final BtsAppRss _rssDb = BtsAppRss();
  final BtsAppConfig _configDb = BtsAppConfig();
  final BtrMikanApi _api = BtrMikanApi();

  Timer? _refreshTimer;
  final Map<String, Set<String>> _knownItems = {};
  bool _isInitialized = false;

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

    BTLogTool.info('BMF RSS 服务启动');
    await _loadKnownItems();
    await _refreshAllRss();

    _refreshTimer = Timer.periodic(refreshInterval, (timer) async {
      await _refreshAllRss();
    });

    _isInitialized = true;
    BTLogTool.info('BMF RSS 服务初始化完成');
  }

  void stop() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _isInitialized = false;
    _updateController.close();
    _statusController.close();
    BTLogTool.info('BMF RSS 服务已停止');
  }

  Future<void> _loadKnownItems() async {
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

  Future<void> _refreshAllRss() async {
    var bmfList = await _bmfDb.readAll();
    if (bmfList.isEmpty) {
      BTLogTool.info('没有 BMF 订阅需要刷新');
      return;
    }

    BTLogTool.info('开始刷新 ${bmfList.length} 个 BMF RSS 订阅');

    var mikanUrl = await _configDb.readMikanUrl();

    var futures = bmfList
        .where((bmf) => bmf.rss != null && bmf.rss!.isNotEmpty)
        .map((bmf) => _refreshSingleRss(bmf, mikanUrl))
        .toList();

    await Future.wait(futures);
  }

  Future<_RssRefreshResult> _refreshSingleRssInternal(
    AppBmfModel bmf,
    String? mikanUrl,
  ) async {
    var url = _getRssUrl(bmf, mikanUrl);
    var key = _keyForBmf(bmf, url);

    try {
      var existingModel = bmf.mkBgmId != null && bmf.mkBgmId!.isNotEmpty
          ? await _rssDb.readByMkId(bmf.mkBgmId!)
          : await _rssDb.read(url);
      var rssGet = await _api.getCustomRSS(url);
      var tryTimes = 0;
      while (rssGet.code != 0 && tryTimes < 3) {
        rssGet = await _api.getCustomRSS(url);
        tryTimes++;
      }

      if (rssGet.code != 0 || rssGet.data == null) {
        BTLogTool.warn('刷新 RSS 失败: ${bmf.subject}');
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
        updated: DateTime.now().millisecondsSinceEpoch,
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
          updated: DateTime.now(),
          pendingItemKeys: pendingItemKeys,
        ),
      );
      notifyPendingStateChanged(bmf, pendingItemKeys.length);

      if (newItems.isNotEmpty && knownKeys.isNotEmpty) {
        await _notifyNewItems(bmf, newItems);
        BTLogTool.info(
          '发现 ${newItems.length} 条新 RSS 更新: ${bmf.title ?? bmf.subject}',
        );
      }

      return _RssRefreshResult(success: true, newItems: newItems);
    } catch (e) {
      BTLogTool.error(['刷新 RSS 异常', 'Subject: ${bmf.subject}', 'Error: $e']);
      return const _RssRefreshResult(success: false);
    }
  }

  Future<void> _refreshSingleRss(AppBmfModel bmf, String? mikanUrl) async {
    await _refreshSingleRssInternal(bmf, mikanUrl);
  }

  String _getRssUrl(AppBmfModel bmf, String? mikanUrl) {
    if (bmf.mkBgmId == null || bmf.mkBgmId!.isEmpty) {
      return bmf.rss!;
    }
    var baseUrl = mikanUrl ?? 'https://mikanani.me';
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

  Future<void> _notifyNewItems(AppBmfModel bmf, List<RssItem> newItems) async {
    var title = bmf.title ?? '动画 ${bmf.subject}';

    void onClick() {
      globalContainer.read(bmfNavigationProvider).selectSubject(bmf.subject);
      globalContainer.read(navStoreProvider).setCurIndex(1);
    }

    if (newItems.length > 1) {
      await BTNotifierTool.showMini(
        title: 'RSS 订阅更新',
        body: '$title 有 ${newItems.length} 条更新',
        onClick: onClick,
      );
    } else if (newItems.length == 1) {
      await BTNotifierTool.showMini(
        title: 'RSS 订阅更新',
        body: '${newItems[0].title}',
        onClick: onClick,
      );
    }
  }

  Future<void> refreshNow() async {
    BTLogTool.info('手动刷新所有 BMF RSS');
    await _refreshAllRss();
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
    if (bmf.rss == null || bmf.rss!.isEmpty) return false;

    var mikanUrl = await _configDb.readMikanUrl();
    var key = _keyForBmf(bmf, _getRssUrl(bmf, mikanUrl));

    _knownItems.remove(key);

    var result = await _refreshSingleRssAndGetResult(bmf, mikanUrl);
    if (result) {
      BTLogTool.info('BMF 订阅已更新: ${bmf.title ?? bmf.subject}');
    }
    return result;
  }

  Future<bool> _refreshSingleRssAndGetResult(
    AppBmfModel bmf,
    String? mikanUrl,
  ) async {
    var result = await _refreshSingleRssInternal(bmf, mikanUrl);
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
