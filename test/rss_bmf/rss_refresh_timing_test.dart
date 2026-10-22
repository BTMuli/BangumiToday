// Dart imports:
import 'dart:async';
import 'dart:typed_data';

// Package imports:
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/bmf_rss_service.dart';
import 'package:bangumi_today/database/drift/bt_database.dart';
import 'package:bangumi_today/database/drift/subscription_storage.dart';
import 'package:bangumi_today/domain/rss/feed_identity.dart';
import 'package:bangumi_today/request/mikan/mikan_api.dart';

const _url = 'https://example.invalid/rss';
const _xml = '<rss><channel/></rss>';
final _feedKey = FeedIdentity.fromUrl(_url).feedKey;

class _RssAdapter implements HttpClientAdapter {
  final requests = <DateTime>[];
  final requested = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(DateTime.now());
    if (!requested.isCompleted) requested.complete();
    return ResponseBody.fromString(_xml, 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late BtDatabase db;
  late SubscriptionStorage storage;
  late BmfRssService service;
  late _RssAdapter adapter;
  late int subscriptionId;

  setUp(() async {
    db = BtDatabase(NativeDatabase.memory());
    storage = SubscriptionStorage(db);
    var bmfId = await db
        .into(db.appBmf)
        .insert(AppBmfCompanion.insert(subject: 1));
    subscriptionId = await db
        .into(db.appSubscription)
        .insert(
          AppSubscriptionCompanion.insert(
            bmfId: bmfId,
            url: _url,
            feedKey: _feedKey,
          ),
        );
    expect((await storage.read(subscriptionId))!.canRefresh, isTrue);
    var api = BtrMikanApi();
    adapter = _RssAdapter();
    api.client.dio.httpClientAdapter = adapter;
    service = BmfRssService.forTesting(storage: storage, api: api);
  });

  tearDown(() async {
    await service.stop();
    await db.close();
  });

  Future<DateTime> seedCache() async {
    var at = DateTime.now().subtract(const Duration(milliseconds: 500));
    await storage.applyFeed(
      feedKey: _feedKey,
      requestUrl: _url,
      subscriptionIds: [subscriptionId],
      xml: _xml,
      at: at.millisecondsSinceEpoch,
    );
    return DateTime.fromMillisecondsSinceEpoch(at.millisecondsSinceEpoch);
  }

  test('缓存到期立即抓取，不等待下一个检查周期', () async {
    var cachedAt = await seedCache();
    var due = cachedAt.add(const Duration(seconds: 2));
    var updated = service.updateStream.first;
    await service.start(
      refreshInterval: const Duration(seconds: 2),
      checkInterval: const Duration(seconds: 1),
    );
    expect(adapter.requests, isEmpty);

    await adapter.requested.future.timeout(const Duration(seconds: 3));
    var requestedAt = adapter.requests.single;
    expect(requestedAt.isBefore(due), isFalse);
    expect(
      requestedAt.difference(due),
      lessThan(const Duration(milliseconds: 300)),
    );
    await updated.timeout(const Duration(seconds: 3));
  });

  test('失败退避到期立即重试，不等待下一个检查周期', () async {
    var failedAt = DateTime.now()
        .subtract(const Duration(minutes: 5))
        .add(const Duration(milliseconds: 1500));
    await storage.recordFailure(_feedKey, _url, [
      subscriptionId,
    ], failedAt.millisecondsSinceEpoch);
    var due = DateTime.fromMillisecondsSinceEpoch(
      failedAt.millisecondsSinceEpoch,
    ).add(const Duration(minutes: 5));
    var updated = service.updateStream.first;
    await service.start(checkInterval: const Duration(seconds: 1));
    expect(adapter.requests, isEmpty);

    await adapter.requested.future.timeout(const Duration(seconds: 3));
    var requestedAt = adapter.requests.single;
    expect(requestedAt.isBefore(due), isFalse);
    expect(
      requestedAt.difference(due),
      lessThan(const Duration(milliseconds: 300)),
    );
    await updated.timeout(const Duration(seconds: 3));
  });

  test('停止服务取消已经安排的到期抓取', () async {
    await seedCache();
    await service.start(
      refreshInterval: const Duration(seconds: 1),
      checkInterval: const Duration(milliseconds: 100),
    );
    await service.stop();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(adapter.requests, isEmpty);
  });
}
