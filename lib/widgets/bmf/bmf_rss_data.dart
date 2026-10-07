// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Project imports:
import '../../core/services/bmf_rss_service.dart';
import '../../database/app/app_subscription.dart';
import '../../domain/rss/rss_item_key.dart';
import '../../models/database/app_bmf_model.dart';
import '../../models/database/app_subscription_model.dart';
import '../../models/rss/rss.dart';
import '../rss/rss_release_data.dart';

/// One selected subscription, with state loaded from transactional storage.
class BmfRssData extends ChangeNotifier {
  BmfRssData({required this.bmf, int? subscriptionId})
    : selectedSubscriptionId =
          subscriptionId ?? bmf.subscriptions.firstOrNull?.id;
  AppBmfModel bmf;
  int? selectedSubscriptionId;
  AppSubscriptionModel? subscription;
  Set<String> pendingItemKeys = {};
  List<RssItem> rssItems = [];
  List<RssReleaseData> rssReleases = [];
  List<RssReleaseGroup> rssGroups = [];
  DateTime? lastUpdated;
  int _generation = 0;
  bool _disposed = false;

  String get rssUrl =>
      subscription?.url ??
      bmf.subscriptions
          .where((s) => s.id == selectedSubscriptionId)
          .firstOrNull
          ?.url ??
      '';
  String itemKey(RssItem item) => rssItemKey(item);

  RssReleaseSource get source => RssReleaseSource.fromProvider(
    (subscription ??
            bmf.subscriptions
                .where((s) => s.id == selectedSubscriptionId)
                .firstOrNull)
        ?.provider,
  );

  void updateBmf(AppBmfModel model) {
    bmf = model;
    if (!model.subscriptions.any((s) => s.id == selectedSubscriptionId)) {
      selectedSubscriptionId = model.subscriptions.firstOrNull?.id;
    }
    _generation++;
    unawaited(load());
  }

  void selectSubscription(int id) {
    selectedSubscriptionId = id;
    subscription = null;
    rssItems = [];
    rssReleases = [];
    rssGroups = [];
    pendingItemKeys = {};
    lastUpdated = null;
    _generation++;
    unawaited(load());
  }

  Future<void> load() async {
    var generation = ++_generation;
    var id = selectedSubscriptionId;
    var model = id == null ? null : await appSubscriptionStorage.read(id);
    var cache = model == null
        ? null
        : await appSubscriptionStorage.readCache(model.feedKey);
    var items = <RssItem>[];
    if (cache?.data?.isNotEmpty ?? false) {
      try {
        items = RssFeed.parse(cache!.data!).items;
      } on FormatException {
        // A corrupt cache is rebuilt by refresh; persistent state is retained.
      }
    }
    if (_disposed || generation != _generation) return;
    subscription = model;
    lastUpdated = cache != null && cache.lastSuccessAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(cache.lastSuccessAt)
        : null;
    rssItems = items;
    rssReleases = items
        .map(
          (item) => RssReleaseData.fromItem(
            item,
            source,
            baseUrl: Uri.tryParse(rssUrl),
          ),
        )
        .toList(growable: false);
    rssGroups = isWholeAnimeRss(rssUrl, source)
        ? groupRssReleases(rssReleases, source)
        : [];
    pendingItemKeys = model?.pendingItemKeys ?? {};
    notifyListeners();
  }

  void applyUpdate(BmfRssUpdateEvent event) {
    if (event.subscriptionId == selectedSubscriptionId) unawaited(load());
  }

  Future<void> markItemHandled(RssItem item) async {
    var id = selectedSubscriptionId;
    if (id == null) return;
    _generation++;
    await appSubscriptionStorage.markHandled(id, itemKeys: [itemKey(item)]);
    await BmfRssService.instance.notifySubscriptionStateChanged(id);
    await load();
  }

  Future<void> markAllHandled() async {
    var id = selectedSubscriptionId;
    if (id == null) return;
    _generation++;
    await appSubscriptionStorage.markHandled(id);
    await BmfRssService.instance.notifySubscriptionStateChanged(id);
    await load();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
