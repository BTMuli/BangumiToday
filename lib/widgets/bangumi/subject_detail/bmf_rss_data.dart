// Flutter imports:
import 'package:flutter/foundation.dart';

// Project imports:
import '../../../core/constants/app_constants.dart';
import '../../../core/services/bmf_rss_service.dart';
import '../../../database/app/app_rss.dart';
import '../../../models/database/app_bmf_model.dart';
import '../../../models/database/app_rss_model.dart';
import '../../../models/rss/rss.dart';

/// 单个 BMF 的 RSS 订阅数据与待处理状态。
///
/// 负责从数据库读取/写入订阅缓存、解析条目、维护待处理集合，并在
/// 服务推送更新时同步数据；UI 通过监听本对象刷新。
class BmfRssData extends ChangeNotifier {
  BmfRssData({required this.sqlite, required this.bmf, this.mikanRss});

  final BtsAppRss sqlite;
  AppBmfModel bmf;
  String? mikanRss;

  AppRssModel? appRssModel;
  Set<String> rssItemsKey = {};
  Set<String> pendingItemKeys = {};
  List<RssItem> rssItems = [];
  int _loadGeneration = 0;

  /// Mikan 完整订阅地址；非 Mikan 条目直接返回配置的 RSS。
  String get rssUrl {
    var base = BTAppConstants.normalizeMikanUrl(mikanRss);
    if (bmf.mkBgmId == null || bmf.mkBgmId!.isEmpty) {
      return BTAppConstants.rewriteMikanUrl(bmf.rss!, base);
    }
    var url = '$base/RSS/Bangumi?bangumiId=${bmf.mkBgmId}';
    if (bmf.mkGroupId != null) url += '&subgroupid=${bmf.mkGroupId}';
    return url;
  }

  String itemKey(RssItem item) {
    return '${item.title ?? ''}|${item.pubDate ?? ''}';
  }

  /// 切换关联的 BMF 并重新加载；配置为空时仅清空旧数据。
  void updateBmf(AppBmfModel value, {String? mikanRss}) {
    bmf = value;
    this.mikanRss = mikanRss;
    _loadGeneration++;
    rssItems.clear();
    rssItemsKey.clear();
    pendingItemKeys.clear();
    appRssModel = null;
    if (bmf.rss == null || bmf.rss!.isEmpty) return;
    Future.microtask(load);
  }

  /// 从数据库读取订阅缓存并解析条目。
  Future<void> load() async {
    if (bmf.rss == null || bmf.rss!.isEmpty) return;
    var generation = ++_loadGeneration;
    var currentBmf = bmf;
    var rssUrl = this.rssUrl;
    var model = currentBmf.mkBgmId == null || currentBmf.mkBgmId!.isEmpty
        ? await sqlite.read(currentBmf.rss!)
        : await sqlite.readByMkId(currentBmf.mkBgmId!);
    if (generation != _loadGeneration) return;

    if (model == null) {
      model = AppRssModel(
        rss: rssUrl,
        data: '',
        ttl: 0,
        updated: 0,
        mkBgmId: currentBmf.mkBgmId,
        mkGroupId: currentBmf.mkGroupId,
      );
      await sqlite.write(model);
      if (generation != _loadGeneration) return;
    }

    var items = model.data.isEmpty
        ? <RssItem>[]
        : RssFeed.parse(model.data).items;
    var itemKeys = items
        .map((item) => '${item.title ?? ''}|${item.pubDate ?? ''}')
        .toSet();
    var pendingKeys = Set<String>.from(model.pendingItemKeys);
    if (generation != _loadGeneration) return;
    appRssModel = model;
    rssItems = items;
    rssItemsKey = itemKeys;
    pendingItemKeys = pendingKeys;
    notifyListeners();
  }

  /// 应用服务推送的订阅更新，替换缓存与待处理集合。
  void applyUpdate(BmfRssUpdateEvent event) {
    _loadGeneration++;
    var items = List<RssItem>.from(event.items);
    var itemKeys = items
        .map((e) => '${e.title ?? ''}|${e.pubDate ?? ''}')
        .toSet();
    var pendingKeys = Set<String>.from(event.pendingItemKeys);
    var model = AppRssModel(
      mkBgmId: bmf.mkBgmId,
      mkGroupId: bmf.mkGroupId,
      rss: rssUrl,
      data: event.rssData,
      ttl: 0,
      updated: event.updated.millisecondsSinceEpoch,
    );
    model.setPendingItemKeys(pendingKeys);
    appRssModel = model;
    rssItems = items;
    rssItemsKey = itemKeys;
    pendingItemKeys = pendingKeys;
    notifyListeners();
  }

  Future<void> markItemHandled(RssItem item) async {
    if (appRssModel == null) return;
    var key = itemKey(item);
    if (!pendingItemKeys.remove(key)) return;
    appRssModel!.setPendingItemKeys(pendingItemKeys);
    await sqlite.updatePendingItems(appRssModel!);
    BmfRssService.instance.notifyPendingStateChanged(
      bmf,
      pendingItemKeys.length,
    );
    notifyListeners();
  }

  Future<void> markAllHandled() async {
    if (appRssModel == null || pendingItemKeys.isEmpty) return;
    pendingItemKeys.clear();
    appRssModel!.setPendingItemKeys(pendingItemKeys);
    await sqlite.updatePendingItems(appRssModel!);
    BmfRssService.instance.notifyPendingStateChanged(bmf, 0);
    notifyListeners();
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }
}
