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
import '../../store/nav_store.dart';
import '../../tools/log_tool.dart';
import '../../tools/notifier_tool.dart';

class BmfRssUpdateEvent {
  final String key;
  final String rssData;
  final List<RssItem> items;
  final DateTime updated;

  BmfRssUpdateEvent({
    required this.key,
    required this.rssData,
    required this.items,
    required this.updated,
  });
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

  Stream<BmfRssUpdateEvent> get updateStream => _updateController.stream;

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
    BTLogTool.info('BMF RSS 服务已停止');
  }

  Future<void> _loadKnownItems() async {
    var rssModels = await _rssDb.readAll();
    for (var model in rssModels) {
      if (model.data.isNotEmpty) {
        try {
          var items = RssFeed.parse(model.data).items;
          var key = model.mkBgmId ?? model.rss;
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

    for (var bmf in bmfList) {
      if (bmf.rss == null || bmf.rss!.isEmpty) continue;
      await _refreshSingleRss(bmf, mikanUrl);
    }
  }

  Future<void> _refreshSingleRss(AppBmfModel bmf, String? mikanUrl) async {
    var url = _getRssUrl(bmf, mikanUrl);
    var key = bmf.mkBgmId ?? url;

    try {
      var rssGet = await _api.getCustomRSS(url);
      var tryTimes = 0;
      while (rssGet.code != 0 && tryTimes < 3) {
        rssGet = await _api.getCustomRSS(url);
        tryTimes++;
      }

      if (rssGet.code != 0 || rssGet.data == null) {
        BTLogTool.warn('刷新 RSS 失败: ${bmf.subject}');
        return;
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

      _knownItems[key] = currentKeys;

      var appRssModel = AppRssModel(
        rss: url,
        data: rssGet.data,
        ttl: feed.ttl,
        updated: DateTime.now().millisecondsSinceEpoch,
        mkBgmId: bmf.mkBgmId,
        mkGroupId: bmf.mkGroupId,
      );
      await _rssDb.write(appRssModel);

      _updateController.add(BmfRssUpdateEvent(
        key: key,
        rssData: rssGet.data,
        items: currentItems,
        updated: DateTime.now(),
      ));

      if (newItems.isNotEmpty && knownKeys.isNotEmpty) {
        await _notifyNewItems(bmf, newItems);
        BTLogTool.info(
          '发现 ${newItems.length} 条新 RSS 更新: ${bmf.title ?? bmf.subject}',
        );
      }
    } catch (e) {
      BTLogTool.error(['刷新 RSS 异常', 'Subject: ${bmf.subject}', 'Error: $e']);
    }
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

  Future<void> _notifyNewItems(AppBmfModel bmf, List<RssItem> newItems) async {
    var title = bmf.title ?? '动画 ${bmf.subject}';

    void onClick() {
      globalContainer.read(navStoreProvider.notifier).addNavItemB(
            subject: bmf.subject,
            type: '动画',
            paneTitle: bmf.title,
          );
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

  Future<void> onBmfWritten(AppBmfModel bmf) async {
    if (!_isInitialized) return;
    if (bmf.rss == null || bmf.rss!.isEmpty) return;

    var mikanUrl = await _configDb.readMikanUrl();
    var key = bmf.mkBgmId ?? _getRssUrl(bmf, mikanUrl);

    _knownItems.remove(key);

    await _refreshSingleRss(bmf, mikanUrl);
    BTLogTool.info('BMF 订阅已更新: ${bmf.title ?? bmf.subject}');
  }

  Future<void> onBmfDeleted(int subject, String? mkBgmId, String? rss) async {
    if (!_isInitialized) return;

    var key = mkBgmId ?? rss;
    if (key != null) {
      _knownItems.remove(key);
    }

    BTLogTool.info('BMF 订阅已移除: subject=$subject');
  }
}
