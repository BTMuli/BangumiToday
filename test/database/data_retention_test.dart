// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/database/app/playback_episode_links.dart';
import 'package:bangumi_today/database/drift/bt_database.dart';
import 'package:bangumi_today/database/drift/subscription_storage.dart';
import 'package:bangumi_today/domain/rss/feed_identity.dart';
import 'package:bangumi_today/domain/rss/rss_known_items.dart';
import 'package:bangumi_today/models/database/app_subscription_model.dart';
import 'package:bangumi_today/models/playback/playback_episode_link.dart';
import 'package:bangumi_today/models/playback/playback_episode_rule.dart';

const _url = 'https://example.invalid/feed';
final _feedKey = FeedIdentity.fromUrl(_url).feedKey;
final _start = DateTime.utc(2026, 10, 1);

String _feed(List<String> titles) =>
    '<rss><channel>'
    '${titles.map((title) => '<item><title>$title</title></item>').join()}'
    '</channel></rss>';

void main() {
  late BtDatabase db;
  late SubscriptionStorage storage;
  late int subscriptionId;

  setUp(() async {
    db = BtDatabase(NativeDatabase.memory());
    storage = SubscriptionStorage(db);
    var bmf = await db
        .into(db.appBmf)
        .insert(AppBmfCompanion.insert(subject: 42));
    subscriptionId = await db
        .into(db.appSubscription)
        .insert(
          AppSubscriptionCompanion.insert(
            bmfId: bmf,
            url: _url,
            feedKey: _feedKey,
          ),
        );
  });

  tearDown(() async => db.close());

  Future<List<SubscriptionFeedUpdate>> apply(List<String> titles, int day) =>
      storage.applyFeed(
        feedKey: _feedKey,
        requestUrl: _url,
        subscriptionIds: [subscriptionId],
        xml: _feed(titles),
        at: _start.add(Duration(days: day)).millisecondsSinceEpoch,
      );

  test('移除 BMF 同时删除其关联、排除与规则，保留其他条目和播放历史', () async {
    await db.into(db.appBmf).insert(AppBmfCompanion.insert(subject: 43));
    var links = PlaybackEpisodeLinksStorage(database: db);
    for (var subject in [42, 43]) {
      for (var episode in [1, null]) {
        await links.write(
          PlaybackEpisodeLink(
            filePath: 'D:/videos/$subject/ep${episode ?? 2}.mkv',
            subject: subject,
            episode: episode,
          ),
        );
      }
      await links.writeRule(
        PlaybackEpisodeRule(
          id: 'rule-$subject',
          subject: subject,
          pattern: r'ep(\d+)',
          offset: 0,
          type: 0,
          exampleFile: 'ep01.mkv',
        ),
      );
    }
    await db
        .into(db.appPlayback)
        .insert(
          AppPlaybackCompanion.insert(
            pathKey: 'history',
            filePath: 'D:/videos/42/ep1.mkv',
            title: 'ep1',
            subject: const Value(42),
          ),
        );

    await storage.deleteBmf(42);
    expect((await links.readAll()).values.map((link) => link.subject), [
      43,
      43,
    ]);
    expect((await links.readRules()).single.subject, 43);
    expect(await storage.read(subscriptionId), isNull);
    expect(await db.select(db.appPlayback).get(), hasLength(1));
    await storage.deleteBmf(42);
    expect((await links.readAll()).values, hasLength(2));
  });

  test('去重键按最后出现时间保留 14 天，过期清理不删除待处理状态', () async {
    await apply(['baseline'], 0);
    var update = await apply(['new'], 1);
    expect(update.single.newItems.map((item) => item.title), ['new']);
    await apply(['baseline'], 13);
    await storage.pruneKnownItems(now: _start.add(const Duration(days: 15)));
    var saved = (await storage.read(subscriptionId))!;
    expect(saved.knownItemKeys, {'baseline|'});
    expect(saved.pendingItemKeys, {'new|'});

    // Reappearing pending items must not notify again, even after dedup expiry.
    update = await apply(['new'], 15);
    expect(update.single.newItems, isEmpty);
    saved = (await storage.read(subscriptionId))!;
    expect(saved.knownItemKeys, {'baseline|', 'new|'});
    expect(saved.pendingItemKeys, {'new|'});
  });

  test('自动清理旧版遗留的无 BMF 关联和规则；BMF 为空时清理全部孤立项', () async {
    var links = PlaybackEpisodeLinksStorage(database: db);
    for (var subject in [42, 100]) {
      for (var episode in [1, null]) {
        await links.write(
          PlaybackEpisodeLink(
            filePath: 'D:/videos/$subject/ep${episode ?? 2}.mkv',
            subject: subject,
            episode: episode,
          ),
        );
      }
      await links.writeRule(
        PlaybackEpisodeRule(
          id: 'rule-$subject',
          subject: subject,
          pattern: r'ep(\d+)',
          offset: 0,
          type: 0,
          exampleFile: 'ep01.mkv',
        ),
      );
    }
    await storage.pruneOrphanedPlaybackData();
    expect((await links.readAll()).values.map((link) => link.subject), [
      42,
      42,
    ]);
    expect((await links.readRules()).single.subject, 42);
    // Reproduce a historical deletion that never cleaned associated rows.
    await db.delete(db.appSubscription).go();
    await db.delete(db.appBmf).go();
    await storage.pruneOrphanedPlaybackData();
    expect(await links.readAll(), isEmpty);
    expect(await links.readRules(), isEmpty);
  });

  test('已处理资源在 14 天内去重，超过窗口后可以作为新资源出现', () async {
    await apply([], 0);
    await apply(['release'], 1);
    await storage.markHandled(subscriptionId);
    expect((await apply(['release'], 14)).single.newItems, isEmpty);
    expect(
      (await apply(['release'], 28)).single.newItems.map((item) => item.title),
      ['release'],
    );
  });

  test('暂停订阅的旧字符串去重键从首次维护开始保留 14 天', () async {
    await (db.update(
      db.appSubscription,
    )..where((s) => s.id.equals(subscriptionId))).write(
      const AppSubscriptionCompanion(
        autoUpdate: Value(0),
        knownItems: Value('["legacy|"]'),
        pendingItems: Value('["pending|"]'),
      ),
    );
    await storage.pruneKnownItems(now: _start);
    var saved = (await storage.read(subscriptionId))!;
    expect(saved.knownItemKeys, {'legacy|'});
    var payload = jsonDecode(saved.knownItems) as List;
    expect(payload.single['lastSeenAt'], _start.millisecondsSinceEpoch);
    await storage.pruneKnownItems(
      now: _start.add(const Duration(days: 14) - const Duration(seconds: 1)),
    );
    expect((await storage.read(subscriptionId))!.knownItemKeys, {'legacy|'});
    await storage.pruneKnownItems(now: _start.add(const Duration(days: 14)));
    saved = (await storage.read(subscriptionId))!;
    expect(saved.knownItemKeys, isEmpty);
    expect(saved.pendingItemKeys, {'pending|'});
    expect(saved.autoUpdate, isFalse);
  });

  test('旧去重数组和带时间的数组均可读取，格式损坏时拒绝', () {
    var model = AppSubscriptionModel.forUrl(_url);
    var migrated = AppSubscriptionModel.fromJson({
      ...model.toJson(),
      'knownItems': '["old",{"key":"new","lastSeenAt":1}]',
    });
    expect(migrated.knownItemKeys, {'old', 'new'});
    expect(
      () => RssKnownItems.decode('[{"key":"invalid","lastSeenAt":-1}]'),
      throwsFormatException,
    );
    expect(() => RssKnownItems.decode('{}'), throwsFormatException);
    var roundTrip = RssKnownItems.decode('["old"]');
    expect(RssKnownItems.decode(roundTrip.encode()).keys, {'old'});
  });
}
