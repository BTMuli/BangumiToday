// Dart imports:
import 'dart:io';

// Package imports:
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;

// Project imports:
import 'tables/app_bmf.dart';
import 'tables/app_config.dart';
import 'tables/app_playback.dart';
import 'tables/app_rss.dart';
import 'tables/bangumi_collection.dart';
import 'tables/bangumi_data_item.dart';
import 'tables/bangumi_data_site.dart';
import 'tables/bangumi_user.dart';

part 'bt_database.g.dart';

/// 应用 SQLite 数据库。
///
/// 接管既有 `BangumiToday.db`：表名、列名、类型与缺省值都与迁移前的建表语句
/// 一致，因此不需要重建或搬迁数据。
///
/// 版本策略：**保持 `schemaVersion = 1`**。迁移前 sqflite 用
/// `OpenDatabaseOptions(version: 1)` 打开，写入的 `user_version` 就是 1；
/// 结构演进当时完全靠 `preCheck()` + `PRAGMA table_info` 补列，所以版本号不能
/// 用来推断结构。Drift 接管时如果改版本号，既有库会走进 `onUpgrade`，而它其实
/// 已经是目标结构。保持 1 可让旧版本客户端仍能打开同一文件（回退安全），
/// 后续真正的结构演进再从 1 开始按步升级。
@DriftDatabase(
  tables: [
    AppBmf,
    AppRss,
    AppConfig,
    AppPlayback,
    BangumiUser,
    BangumiCollection,
    BangumiDataSite,
    BangumiDataItem,
  ],
)
class BtDatabase extends _$BtDatabase {
  /// 构造函数
  BtDatabase(super.executor, {String? databasePath, this.onMigration})
    : _databasePath = databasePath;

  final String? _databasePath;

  /// Optional application logging, without coupling schema logic to Flutter.
  final void Function(String message)? onMigration;

  /// 打开指定路径的数据库文件。
  factory BtDatabase.open(
    String databasePath, {
    void Function(String message)? onMigration,
  }) {
    return BtDatabase(
      _openConnection(File(databasePath)),
      databasePath: databasePath,
      onMigration: onMigration,
    );
  }

  static QueryExecutor _openConnection(File file) {
    return NativeDatabase.createInBackground(file);
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // A version-zero database can also contain legacy tables. Inspect actual
    // structure instead of treating every onCreate as an empty installation.
    onCreate: (_) => _ensureSchema(),
    beforeOpen: (details) async {
      // 旧库由 sqflite 建立，可能缺少后加的列。版本号相同不代表结构一致，
      // 所以每次打开都按目标结构补齐一次，替代原来的 static bool 缓存。
      await _ensureSchema();
      onMigration?.call(
        'SQLite opened: ${details.wasCreated ? "created" : "existing"}',
      );
    },
  );

  /// 逐表比对目标结构，补齐缺失的列。
  ///
  /// 与 `preCheck()` 时代的语义一致，但放进单次迁移流程里：不再用进程内
  /// 静态标志缓存判定结果，避免两套连接对同一列给出不同结论。
  ///
  /// 注意 Drift 默认把 Dart getter 名转成 snake_case（`mkBgmId` →
  /// `mk_bgm_id`），本项目的列名是 camelCase，所以比对必须用
  /// `$name`（SQL 列名）而不是 getter 名，否则会误判缺失列并重复 ALTER。
  Future<void> _ensureSchema() async {
    var missingTables = <TableInfo>[];
    var missingColumns = <(TableInfo, GeneratedColumn)>[];
    for (var table in allTables) {
      var actual = await customSelect(
        'PRAGMA table_info(${table.actualTableName})',
      ).get();
      var existing = actual.map((row) => row.read<String>('name')).toSet();
      if (existing.isEmpty) {
        missingTables.add(table);
        continue;
      }
      for (var key in table.$primaryKey) {
        if (!actual.any(
          (row) =>
              row.read<String>('name') == key.$name && row.read<int>('pk') > 0,
        )) {
          throw StateError(
            '数据库结构异常：${table.actualTableName}.${key.$name} 主键缺失；'
            '请关闭应用并从备份恢复，不能自动重建',
          );
        }
      }
      for (var column in table.$columns) {
        if (existing.contains(column.$name)) continue;
        if (!column.$nullable && column.defaultValue == null) {
          throw StateError(
            '数据库结构异常：${table.actualTableName}.${column.$name} '
            '缺失且没有安全默认值；请关闭应用并从备份恢复',
          );
        }
        missingColumns.add((table, column));
      }
    }
    if (missingTables.isEmpty && missingColumns.isEmpty) return;
    await _backupBeforeMigration();
    await transaction(() async {
      var migrator = Migrator(this);
      for (var table in missingTables) {
        await migrator.createTable(table);
      }
      for (var (table, column) in missingColumns) {
        // Drift renders the real SQL type, nullability and default expression.
        // Do not derive DDL from a Dart expression's toString().
        await migrator.addColumn(table, column);
      }
    });
    onMigration?.call(
      'SQLite schema updated: ${missingTables.length} tables, '
      '${missingColumns.length} columns',
    );
  }

  /// VACUUM INTO reads a consistent SQLite snapshot, including committed WAL
  /// content. Run before the schema transaction; a failed backup blocks changes.
  Future<void> _backupBeforeMigration() async {
    var databasePath = _databasePath;
    if (databasePath == null) return;
    var tables = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%'",
    ).get();
    if (tables.isEmpty) return;
    var directory = Directory(path.join(path.dirname(databasePath), 'backups'));
    await directory.create(recursive: true);
    var backup = path.join(
      directory.path,
      'BangumiToday.pre-migration-'
      '${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await customStatement('VACUUM INTO ?', [backup]);
    onMigration?.call('SQLite migration backup: $backup');
  }
}
