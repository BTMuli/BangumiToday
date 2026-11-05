// Package imports:
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/bmf_rss_service.dart';
import 'package:bangumi_today/database/drift/bt_database.dart';
import 'package:bangumi_today/database/drift/subscription_storage.dart';
import 'package:bangumi_today/models/database/app_bmf_model.dart';
import 'package:bangumi_today/models/database/app_subscription_model.dart';
import 'package:bangumi_today/request/mikan/mikan_api.dart';

void main() {
  late BtDatabase db;
  late BmfRssService service;

  setUp(() {
    db = BtDatabase(NativeDatabase.memory());
    service = BmfRssService.forTesting(
      storage: SubscriptionStorage(db),
      api: BtrMikanApi(),
    );
  });

  tearDown(() async {
    await service.stop();
    await db.close();
  });

  AppBmfModel bmf({required bool autoUpdate, String status = 'active'}) {
    var subscription = AppSubscriptionModel.forUrl(
      'https://mikanani.me/RSS/Bangumi?bangumiId=1',
      bmfId: 1,
      autoUpdate: autoUpdate,
    );
    if (status != subscription.status) {
      subscription = AppSubscriptionModel(
        id: 1,
        bmfId: 1,
        provider: subscription.provider,
        url: subscription.url,
        feedKey: subscription.feedKey,
        sourceConfig: subscription.sourceConfig,
        autoUpdate: autoUpdate,
        status: status,
      );
    }
    expect(subscription.canRefresh, status == 'active');
    return AppBmfModel(id: 1, subject: 100, subscriptions: [subscription]);
  }

  test('未 start 时 willRefreshOnWrite 为 false', () {
    expect(service.willRefreshOnWrite(bmf(autoUpdate: true)), isFalse);
  });

  test('已 start 且存在可自动刷新订阅时为 true', () async {
    await service.start();
    expect(service.willRefreshOnWrite(bmf(autoUpdate: true)), isTrue);
    expect(service.willRefreshOnWrite(bmf(autoUpdate: false)), isFalse);
    expect(
      service.willRefreshOnWrite(bmf(autoUpdate: true, status: 'paused')),
      isFalse,
    );
  });
}
