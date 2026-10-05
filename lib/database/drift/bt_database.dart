// Dart imports:
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' as sqlite;

// Project imports:
import '../database_process_lock.dart';
import 'migrations/legacy_subscription_converter.dart';
import 'migrations/schema_v1.dart';
import 'tables/app_bmf.dart';
import 'tables/app_config.dart';
import 'tables/app_migration_recovery.dart';
import 'tables/app_playback.dart';
import 'tables/app_rss_cache.dart';
import 'tables/app_subscription.dart';
import 'tables/bangumi_collection.dart';
import 'tables/bangumi_data_item.dart';
import 'tables/bangumi_data_site.dart';
import 'tables/bangumi_user.dart';

part 'bt_database.g.dart';
part 'migrations/subscription_migration.dart';

/// Schema owner. Conversion completes before business queries run.
@DriftDatabase(
  tables: [
    AppBmf,
    AppSubscription,
    AppRssCache,
    AppMigrationRecovery,
    AppConfig,
    AppPlayback,
    BangumiUser,
    BangumiCollection,
    BangumiDataSite,
    BangumiDataItem,
  ],
)
class BtDatabase extends _$BtDatabase {
  BtDatabase(super.executor, {String? databasePath, this.onMigration})
    : _databasePath = databasePath;

  final String? _databasePath;
  final void Function(String message)? onMigration;
  DatabaseProcessLock? _processLock;

  factory BtDatabase.open(
    String databasePath, {
    void Function(String message)? onMigration,
  }) {
    late BtDatabase database;
    database = BtDatabase(
      LazyDatabase(() async {
        database._processLock = await DatabaseProcessLock.acquire(databasePath);
        return NativeDatabase.createInBackground(File(databasePath));
      }),
      databasePath: databasePath,
      onMigration: onMigration,
    );
    return database;
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => _migrateSubscriptions(),
    onUpgrade: (_, from, to) async {
      if (from != 1 || to != 2) {
        throw StateError('不支持的数据库版本，请使用匹配的客户端或迁移前快照');
      }
      await _migrateSubscriptions();
    },
    beforeOpen: (_) async {
      await _validateV2();
      await customStatement('PRAGMA foreign_keys = ON');
      var enabled = await customSelect('PRAGMA foreign_keys').getSingle();
      if (enabled.read<int>('foreign_keys') != 1) {
        throw StateError('无法开启数据库外键约束');
      }
      await _resolveNoRssRecovery();
      onMigration?.call('SQLite opened: schema v2');
    },
  );

  @override
  Future<void> close() async {
    try {
      await super.close();
    } finally {
      var lock = _processLock;
      _processLock = null;
      await lock?.release();
    }
  }
}
