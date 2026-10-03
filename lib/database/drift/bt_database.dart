// Dart imports:
import 'dart:io';

// Package imports:
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

// Project imports:
import '../../tools/log_tool.dart';
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
  BtDatabase(super.executor);

  /// 打开指定路径的数据库文件。
  factory BtDatabase.open(String path) {
    return BtDatabase(_openConnection(File(path)));
  }

  static QueryExecutor _openConnection(File file) {
    return NativeDatabase.createInBackground(file);
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      // 只有全新安装才会走到这里：一次性建出全部表。
      await m.createAll();
    },
    beforeOpen: (details) async {
      // 旧库由 sqflite 建立，可能缺少后加的列。版本号相同不代表结构一致，
      // 所以每次打开都按目标结构补齐一次，替代原来的 static bool 缓存。
      await _ensureSchema();
      BTLogTool.info(
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
    for (var table in allTables) {
      var actual = await customSelect(
        'PRAGMA table_info(${table.actualTableName})',
      ).get();
      var existing = actual.map((row) => row.read<String>('name')).toSet();
      for (var column in table.$columns) {
        if (existing.contains(column.$name)) continue;
        await customStatement(
          'ALTER TABLE ${table.actualTableName} '
          'ADD COLUMN ${column.$name} ${_columnDefinition(column)}',
        );
        BTLogTool.info(
          'Update table ${table.actualTableName} add ${column.$name}',
        );
      }
    }
  }

  /// 拼出 `ALTER TABLE ... ADD COLUMN` 需要的类型片段。
  ///
  /// 新列只在结构补齐时使用：非空列必须带缺省值，否则既有行无法填充。
  static String _columnDefinition(GeneratedColumn column) {
    var type = switch (column.type) {
      DriftSqlType.int || DriftSqlType.bool => 'INTEGER',
      DriftSqlType.string || DriftSqlType.dateTime => 'TEXT',
      DriftSqlType.double => 'REAL',
      DriftSqlType.blob => 'BLOB',
      _ => 'TEXT',
    };
    if (column.defaultValue != null) {
      var literal = _sqlLiteral(column.defaultValue!.toString());
      return '$type DEFAULT $literal';
    }
    return column.$nullable ? type : '$type NOT NULL DEFAULT 0';
  }

  /// 把 Drift 的缺省值表达式转成 SQL 字面量。
  ///
  /// `Constant(1)` 要变成 `1`，`Constant('[]')` 要变成 `'[]'`；无法识别的
  /// 表达式原样返回，避免把 Dart 对象 toString 写进 DDL。
  static String _sqlLiteral(String value) {
    var match = RegExp(r'^Constant\((.*)\)$').firstMatch(value.trim());
    var inner = match?.group(1) ?? value;
    if (num.tryParse(inner) != null) return inner;
    if (inner == 'true') return '1';
    if (inner == 'false') return '0';
    if (inner.startsWith("'") && inner.endsWith("'")) return inner;
    return "'${inner.replaceAll("'", "''")}'";
  }
}
