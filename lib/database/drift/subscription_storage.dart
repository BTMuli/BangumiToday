// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

// Project imports:
import '../../data/parsers/rss_parser.dart';
import '../../domain/rss/feed_identity.dart';
import '../../domain/rss/rss_item_key.dart';
import '../../models/database/app_rss_cache_model.dart';
import '../../models/database/app_subscription_model.dart';
import 'bt_database.dart';

class SubscriptionFeedUpdate {
  const SubscriptionFeedUpdate(this.subscription, this.newItems);
  final AppSubscriptionModel subscription;
  final List<RssItem> newItems;
}

/// Transactional state transitions, usable without Flutter or singleton state.
class SubscriptionStorage {
  const SubscriptionStorage(this.db);
  final BtDatabase db;

  Future<List<AppSubscriptionModel>> readAll({int? bmfId}) async {
    var query = db.select(db.appSubscription)
      ..orderBy([(s) => OrderingTerm.asc(s.id)]);
    if (bmfId != null) query.where((s) => s.bmfId.equals(bmfId));
    return (await query.get())
        .map((r) => AppSubscriptionModel.fromJson(r.toJson()))
        .toList();
  }

  Future<AppSubscriptionModel?> read(int id) async {
    var query = db.select(db.appSubscription)..where((s) => s.id.equals(id));
    var row = await query.getSingleOrNull();
    return row == null ? null : AppSubscriptionModel.fromJson(row.toJson());
  }

  Future<Map<String, AppRssCacheModel>> readCaches() async => {
    for (var row in await db.select(db.appRssCache).get())
      row.feedKey: AppRssCacheModel.fromJson(row.toJson()),
  };

  Future<AppRssCacheModel?> readCache(String feedKey) async {
    var query = db.select(db.appRssCache)
      ..where((c) => c.feedKey.equals(feedKey));
    var row = await query.getSingleOrNull();
    return row == null ? null : AppRssCacheModel.fromJson(row.toJson());
  }

  Future<void> saveSubscriptions(
    int bmfId,
    List<AppSubscriptionModel> desired,
  ) async {
    await db.transaction(() async {
      var existing = await readAll(bmfId: bmfId);
      var byId = {for (var s in existing) s.id: s};
      var keys = <String>{};
      var requestedIds = <int>{};
      for (var draft in desired) {
        var identity = FeedIdentity.fromUrl(
          draft.url,
          legacyBmfId: bmfId,
          config: RssSourceConfig.decode(draft.sourceConfig),
        );
        if (!keys.add(identity.feedKey)) {
          throw StateError('同一番剧不能重复添加相同的 RSS 请求');
        }
        if (draft.id != -1 &&
            (!byId.containsKey(draft.id) || !requestedIds.add(draft.id))) {
          throw StateError('订阅已变化，请重新打开编辑窗口');
        }
      }
      for (var old in existing.where((s) => !requestedIds.contains(s.id))) {
        await _archiveState(old, 'subscriptionRemoved');
        await (db.delete(
          db.appSubscription,
        )..where((s) => s.id.equals(old.id))).go();
      }
      // Temporary keys make URL swaps possible without violating uniqueness.
      for (var id in requestedIds) {
        await (db.update(db.appSubscription)..where((s) => s.id.equals(id)))
            .write(AppSubscriptionCompanion(feedKey: Value('editing:$id')));
      }
      for (var draft in desired) {
        var config = RssSourceConfig.decode(draft.sourceConfig);
        var identity = FeedIdentity.fromUrl(
          draft.url,
          legacyBmfId: bmfId,
          config: config,
        );
        var old = byId[draft.id];
        var changed = old != null && old.feedKey != identity.feedKey;
        if (changed) await _archiveState(old, 'requestIdentityChanged');
        var state = !identity.isValid || !config.isSupported
            ? 'needsReview'
            : changed || old == null
            ? 'active'
            : old.status;
        var values = AppSubscriptionCompanion(
          bmfId: Value(bmfId),
          provider: Value(identity.provider),
          url: Value(identity.url),
          feedKey: Value(identity.feedKey),
          sourceConfig: Value(draft.sourceConfig),
          autoUpdate: Value(draft.autoUpdate ? 1 : 0),
          status: Value(state),
          pendingItems: Value(changed ? '[]' : old?.pendingItems ?? '[]'),
          knownItems: Value(changed ? '[]' : old?.knownItems ?? '[]'),
          hasBaseline: Value(
            changed
                ? 0
                : old?.hasBaseline == true
                ? 1
                : 0,
          ),
          itemKeyVersion: Value(old?.itemKeyVersion ?? rssItemKeyVersion),
        );
        if (old == null) {
          await db.into(db.appSubscription).insert(values);
        } else {
          await (db.update(
            db.appSubscription,
          )..where((s) => s.id.equals(old.id))).write(values);
        }
      }
      await pruneUnusedCaches();
    });
  }

  Future<void> _archiveState(
    AppSubscriptionModel subscription,
    String reason,
  ) async {
    if (subscription.pendingItemKeys.isEmpty) return;
    var row = subscription.toJson();
    var payload = jsonEncode({
      'row': row,
      'reasons': [reason],
    });
    var digest = sha256.convert(utf8.encode(payload)).toString();
    await db
        .into(db.appMigrationRecovery)
        .insert(
          AppMigrationRecoveryCompanion.insert(
            migrationVersion: 2,
            kind: 'subscriptionState',
            legacyKey: 'subscription:${subscription.id}:$digest',
            payload: payload,
            candidateBmfIds: Value(jsonEncode([subscription.bmfId])),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// Re-read current pending inside the same transaction as the cache update.
  Future<List<SubscriptionFeedUpdate>> applyFeed({
    required String feedKey,
    required String requestUrl,
    required Iterable<int> subscriptionIds,
    required String xml,
    required int at,
  }) async {
    var feed = RssFeed.parse(xml);
    var currentKeys = feed.items.map(rssItemKey).toSet();
    return db.transaction(() async {
      var updates = <SubscriptionFeedUpdate>[];
      for (var id in subscriptionIds.toSet()) {
        var current = await read(id);
        if (current == null ||
            current.feedKey != feedKey ||
            !current.canRefresh) {
          continue;
        }
        var pending = current.pendingItemKeys;
        var known = current.knownItemKeys;
        var newItems = current.hasBaseline
            ? feed.items
                  .where((item) => !known.contains(rssItemKey(item)))
                  .toList()
            : <RssItem>[];
        pending.addAll(newItems.map(rssItemKey));
        // Keep historical known keys even when the feed window rolls forward.
        known.addAll(currentKeys);
        await (db.update(
          db.appSubscription,
        )..where((s) => s.id.equals(id))).write(
          AppSubscriptionCompanion(
            pendingItems: Value(jsonEncode(pending.toList()..sort())),
            knownItems: Value(jsonEncode(known.toList()..sort())),
            hasBaseline: const Value(1),
          ),
        );
        updates.add(SubscriptionFeedUpdate((await read(id))!, newItems));
      }
      if (updates.isNotEmpty) {
        await db
            .into(db.appRssCache)
            .insertOnConflictUpdate(
              AppRssCacheCompanion.insert(
                feedKey: feedKey,
                requestUrl: requestUrl,
                data: Value(xml),
                ttlMinutes: Value(feed.ttl > 0 ? feed.ttl : 0),
                lastSuccessAt: Value(at),
                lastAttemptAt: Value(at),
                lastFailedAt: const Value(0),
                cacheVersion: const Value(1),
              ),
            );
      }
      return updates;
    });
  }

  Future<void> recordFailure(
    String feedKey,
    String requestUrl,
    Iterable<int> subscriptionIds,
    int at,
  ) async {
    await db.transaction(() async {
      var stillRelevant = false;
      for (var id in subscriptionIds) {
        var current = await read(id);
        if (current != null &&
            current.feedKey == feedKey &&
            current.canRefresh) {
          stillRelevant = true;
        }
      }
      if (!stillRelevant) return;
      await db
          .into(db.appRssCache)
          .insertOnConflictUpdate(
            AppRssCacheCompanion.insert(
              feedKey: feedKey,
              requestUrl: requestUrl,
              lastAttemptAt: Value(at),
              lastFailedAt: Value(at),
            ),
          );
    });
  }

  Future<AppSubscriptionModel?> markHandled(
    int subscriptionId, {
    Iterable<String>? itemKeys,
  }) async => db.transaction(() async {
    var current = await read(subscriptionId);
    if (current == null) return null;
    var pending = current.pendingItemKeys;
    if (itemKeys == null) {
      pending.clear();
    } else {
      pending.removeAll(itemKeys);
    }
    await (db.update(
      db.appSubscription,
    )..where((s) => s.id.equals(subscriptionId))).write(
      AppSubscriptionCompanion(
        pendingItems: Value(jsonEncode(pending.toList()..sort())),
      ),
    );
    return read(subscriptionId);
  });

  /// Clearing reconstructible XML never changes subscription state.
  Future<void> clearCaches() => db.delete(db.appRssCache).go();

  Future<void> pruneUnusedCaches() => db.customStatement(
    'DELETE FROM AppRssCache WHERE NOT EXISTS ('
    'SELECT 1 FROM AppSubscription s WHERE s.feedKey = AppRssCache.feedKey)',
  );

  Future<List<MigrationRecoveryRow>> unresolvedRecovery() async {
    var query = db.select(db.appMigrationRecovery)
      ..where((r) => r.resolvedAt.isNull())
      ..orderBy([(r) => OrderingTerm.asc(r.id)]);
    return query.get();
  }

  /// Explicit user decision; original payload is retained after resolution.
  Future<void> resolveRecovery(
    int recoveryId, {
    int? subscriptionId,
    bool discard = false,
  }) async {
    if (!discard && subscriptionId == null) {
      throw StateError('请选择订阅归属或明确放弃旧状态');
    }
    await db.transaction(() async {
      var row = await (db.select(
        db.appMigrationRecovery,
      )..where((r) => r.id.equals(recoveryId))).getSingle();
      if (row.resolvedAt != null) return;
      var candidates = (jsonDecode(row.candidateBmfIds) as List)
          .cast<int>()
          .toSet();
      if (!discard) {
        var target = await read(subscriptionId!);
        if (target == null) throw StateError('目标订阅已经删除');
        var payload = jsonDecode(row.payload) as Map;
        var original = payload['row'] as Map;
        var keys = AppSubscriptionModel.decodeKeys(
          original['pendingItems'] as String? ?? '[]',
        );
        var pending = target.pendingItemKeys..addAll(keys);
        await (db.update(
          db.appSubscription,
        )..where((s) => s.id.equals(target.id))).write(
          AppSubscriptionCompanion(
            pendingItems: Value(jsonEncode(pending.toList()..sort())),
          ),
        );
        candidates.add(target.bmfId);
      }
      await (db.update(
        db.appMigrationRecovery,
      )..where((r) => r.id.equals(recoveryId))).write(
        AppMigrationRecoveryCompanion(
          resolvedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      var remaining = await unresolvedRecovery();
      var blocked = remaining
          .expand((r) => (jsonDecode(r.candidateBmfIds) as List).cast<int>())
          .toSet();
      for (var candidate in candidates.difference(blocked)) {
        for (var target in await readAll(bmfId: candidate)) {
          var config = RssSourceConfig.decode(target.sourceConfig);
          if (!config.isSupported ||
              !FeedIdentity.fromUrl(
                target.url,
                legacyBmfId: candidate,
                config: config,
              ).isValid) {
            continue;
          }
          await (db.update(db.appSubscription)
                ..where((s) => s.id.equals(target.id)))
              .write(const AppSubscriptionCompanion(status: Value('active')));
        }
      }
    });
  }
}
