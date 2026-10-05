part of '../bt_database.dart';

extension _SubscriptionMigration on BtDatabase {
  Future<List<Map<String, dynamic>>> _rows(String sql) async =>
      (await customSelect(sql).get()).map((row) => row.data).toList();

  Future<Map<String, List<Map<String, dynamic>>>> _legacyStructure() async {
    var structure = <String, List<Map<String, dynamic>>>{};
    for (var entry in legacyV1Tables.entries) {
      var table = entry.key;
      var actual = await _rows('PRAGMA table_info("$table")');
      structure[table] = actual;
      if (actual.isEmpty) continue;
      var expected = (entry.value['columns'] as List).cast<Map>();
      for (var column in expected) {
        var matches = actual.where((c) => c['name'] == column['name']);
        if (matches.isEmpty) {
          if (column['safeMissing'] != true) {
            throw StateError('旧数据库缺少必需列：$table.${column['name']}');
          }
        } else if (column['primaryKey'] == true && matches.single['pk'] == 0) {
          throw StateError('旧数据库主键异常：$table.${column['name']}');
        }
      }
      if (table == 'AppBmf' || table == 'AppRss') {
        var known = expected.map((c) => c['name']).toSet();
        if (actual.any((c) => !known.contains(c['name']))) {
          throw StateError('旧订阅表含有未支持的字段，已停止迁移');
        }
      }
    }
    var schemas = await _rows(
      'SELECT type, name, tbl_name, sql '
      'FROM sqlite_master WHERE sql IS NOT NULL',
    );
    for (var object in schemas) {
      var type = object['type'];
      var sql = object['sql'] as String;
      var dependent = RegExp(
        r'\b(AppBmf|AppRss)\b',
        caseSensitive: false,
      ).hasMatch(sql);
      if (dependent &&
          (type == 'trigger' || type == 'view' || type == 'index')) {
        throw StateError('旧订阅表存在未支持的索引、触发器或视图依赖');
      }
      if (type == 'table') {
        var name = (object['name'] as String).replaceAll('"', '""');
        var foreignKeys = await _rows('PRAGMA foreign_key_list("$name")');
        if (foreignKeys.any(
          (f) => const {'AppBmf', 'AppRss'}.contains(f['table']),
        )) {
          throw StateError('旧订阅表存在未支持的外键依赖');
        }
      }
    }
    for (var table in const [
      'AppSubscription',
      'AppRssCache',
      'AppMigrationRecovery',
      'AppBmf_v2',
    ]) {
      if ((await _rows('PRAGMA table_info("$table")')).isNotEmpty) {
        throw StateError('旧版本号下存在新版或残留迁移表，已停止迁移');
      }
    }
    return structure;
  }

  Future<String> _inputDigest() async {
    var schemas = await _rows(
      'SELECT type, name, tbl_name, sql '
      'FROM sqlite_master ORDER BY type, name',
    );
    var contents = <String, dynamic>{'schema': schemas};
    for (var table in schemas.where((s) => s['type'] == 'table')) {
      var name = table['name'] as String;
      var quoted = name.replaceAll('"', '""');
      contents[name] = (await _rows(
        'SELECT * FROM "$quoted"',
      )).map(jsonEncode).toList()..sort();
    }
    return sha256.convert(utf8.encode(jsonEncode(contents))).toString();
  }

  Future<void> _backupV2Migration() async {
    var filePath = _databasePath;
    if (filePath == null) return;
    var tables = await _rows(
      "SELECT name FROM sqlite_master WHERE "
      "type = 'table' AND name NOT LIKE 'sqlite_%'",
    );
    if (tables.isEmpty) return;
    var directory = Directory(path.join(path.dirname(filePath), 'backups'));
    await directory.create(recursive: true);
    var backup = path.join(
      directory.path,
      'BangumiToday.pre-migration-'
      '${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await customStatement('VACUUM INTO ?', [backup]);
    var snapshot = sqlite.sqlite3.open(backup, mode: sqlite.OpenMode.readOnly);
    try {
      var check = snapshot.select('PRAGMA integrity_check');
      if (check.length != 1 || check.single.values.single != 'ok') {
        throw StateError('迁移前数据库快照完整性校验失败');
      }
    } finally {
      snapshot.close();
    }
    onMigration?.call('SQLite migration backup: $backup');
  }

  Future<void> _insertConverted(String table, List<LegacyRow> rows) async {
    for (var row in rows) {
      var columns = row.keys.map((c) => '"$c"').join(', ');
      var placeholders = List.filled(row.length, '?').join(', ');
      await customStatement(
        'INSERT INTO "$table" ($columns) '
        'VALUES ($placeholders)',
        row.values.toList(),
      );
    }
  }

  Future<void> _migrateSubscriptions() async {
    var structure = await _legacyStructure();
    var bmfRows = structure['AppBmf']!.isEmpty
        ? <LegacyRow>[]
        : await _rows('SELECT * FROM AppBmf');
    var rssRows = structure['AppRss']!.isEmpty
        ? <LegacyRow>[]
        : await _rows('SELECT * FROM AppRss');
    var conversion =
        LegacySubscriptionConverter(
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ).convert(
          bmfRows: bmfRows,
          rssRows: rssRows,
          bmfColumns: structure['AppBmf']!
              .map((c) => c['name'] as String)
              .toSet(),
          rssColumns: structure['AppRss']!
              .map((c) => c['name'] as String)
              .toSet(),
        );
    var hasSequence = (await _rows(
      "SELECT name FROM sqlite_master "
      "WHERE name = 'sqlite_sequence'",
    )).isNotEmpty;
    var sequence = hasSequence
        ? await _rows("SELECT seq FROM sqlite_sequence WHERE name = 'AppBmf'")
        : <LegacyRow>[];
    var oldSequence = sequence.isEmpty ? 0 : sequence.single['seq'] as int;
    var digest = await _inputDigest();
    var untouched = <String, (List<String>, List<String>)>{};
    for (var table in await _rows(
      "SELECT name FROM sqlite_master WHERE "
      "type = 'table' AND name NOT IN ('AppBmf', 'AppRss', 'sqlite_sequence')",
    )) {
      var name = table['name'] as String;
      var quoted = name.replaceAll('"', '""');
      var columns = (await _rows(
        'PRAGMA table_info("$quoted")',
      )).map((c) => c['name'] as String).toList();
      untouched[name] = (
        columns,
        (await _rows('SELECT * FROM "$quoted"')).map(jsonEncode).toList()
          ..sort(),
      );
    }
    var untouchedSequences = hasSequence
        ? await _rows(
            "SELECT name, seq FROM sqlite_sequence "
            "WHERE name != 'AppBmf' ORDER BY name",
          )
        : <LegacyRow>[];
    await _backupV2Migration();
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        if (await _inputDigest() != digest) {
          throw StateError('备份期间数据库已变化，请关闭其他客户端后重试');
        }
        onMigration?.call('SQLite migration phase: begin');
        var migrator = Migrator(this);
        await customStatement(
          'CREATE TABLE "AppBmf_v2" ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          "subject INTEGER NOT NULL UNIQUE, title TEXT DEFAULT '', "
          "airDate TEXT DEFAULT '', download TEXT)",
        );
        await _insertConverted('AppBmf_v2', conversion.bmf);
        var copied = await _rows('SELECT * FROM AppBmf_v2 ORDER BY id');
        if (jsonEncode(copied) != jsonEncode(conversion.bmf)) {
          throw StateError('BMF 保留字段核对失败');
        }
        onMigration?.call('SQLite migration phase: copied');
        if (structure['AppBmf']!.isNotEmpty) {
          await customStatement('DROP TABLE AppBmf');
        }
        await customStatement('ALTER TABLE AppBmf_v2 RENAME TO AppBmf');
        var maxId = conversion.bmf.fold<int>(
          0,
          (value, row) => (row['id'] as int) > value ? row['id'] as int : value,
        );
        var highWater = oldSequence > maxId ? oldSequence : maxId;
        await customStatement(
          "DELETE FROM sqlite_sequence WHERE name = 'AppBmf'",
        );
        await customStatement(
          'INSERT INTO sqlite_sequence(name, seq) '
          'VALUES (?, ?)',
          ['AppBmf', highWater],
        );
        for (var table in <TableInfo>[
          appSubscription,
          appRssCache,
          appMigrationRecovery,
        ]) {
          await migrator.createTable(table);
        }
        for (var entity in allSchemaEntities.whereType<Index>()) {
          await migrator.createIndex(entity);
        }
        await _insertConverted('AppSubscription', conversion.subscriptions);
        await _insertConverted('AppRssCache', conversion.caches);
        await _insertConverted('AppMigrationRecovery', conversion.recovery);
        onMigration?.call('SQLite migration phase: statesWritten');
        for (var entry in legacyV1Tables.entries) {
          var name = entry.key;
          if (name == 'AppBmf' || name == 'AppRss') continue;
          if (structure[name]!.isEmpty) {
            await customStatement(entry.value['sql'] as String);
          } else {
            var actualNames = structure[name]!.map((c) => c['name']).toSet();
            for (var column in entry.value['columns'] as List) {
              if (!actualNames.contains(column['name'])) {
                await customStatement(
                  'ALTER TABLE "$name" ADD COLUMN '
                  '"${column['name']}" ${column['ddl']}',
                );
              }
            }
          }
        }
        if (conversion.rssDisposition.length != rssRows.length ||
            conversion.bmf.length != bmfRows.length) {
          throw StateError('旧数据去向核对失败');
        }
        if (structure['AppRss']!.isNotEmpty) {
          await customStatement('DROP TABLE AppRss');
        }
        for (var entry in untouched.entries) {
          var name = entry.key.replaceAll('"', '""');
          var columns = entry.value.$1
              .map((c) => '"${c.replaceAll('"', '""')}"')
              .join(',');
          var after = (await _rows(
            'SELECT $columns FROM "$name"',
          )).map(jsonEncode).toList()..sort();
          if (jsonEncode(after) != jsonEncode(entry.value.$2)) {
            throw StateError('迁移改变了其他业务表的数据：${entry.key}');
          }
        }
        for (var sequence in untouchedSequences) {
          var after = await customSelect(
            'SELECT seq FROM sqlite_sequence WHERE name = ?',
            variables: [Variable<String>(sequence['name'] as String)],
          ).getSingleOrNull();
          if (after?.read<int>('seq') != sequence['seq']) {
            throw StateError('迁移改变了其他业务表的自增序号');
          }
        }
        await _validateV2();
        if ((await _rows('PRAGMA foreign_key_check')).isNotEmpty ||
            (await _rows('PRAGMA integrity_check')).single.values.single !=
                'ok') {
          throw StateError('迁移后数据库完整性校验失败');
        }
        onMigration?.call('SQLite migration phase: beforeVersion');
        await customStatement('PRAGMA user_version = 2');
        onMigration?.call('SQLite migration phase: beforeCommit');
      });
      onMigration?.call('SQLite migration phase: committed');
      onMigration?.call(
        'SQLite v2 conversion: '
        '${conversion.subscriptions.length} subscriptions, '
        '${conversion.recovery.length} recovery records, '
        '${conversion.discardedEmptyCaches} discarded empty caches',
      );
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> _validateV2() async {
    for (var stale in const ['AppRss', 'AppBmf_v2']) {
      if ((await _rows('PRAGMA table_info("$stale")')).isNotEmpty) {
        throw StateError('新版数据库存在旧表或残留迁移表');
      }
    }
    for (var table in allTables) {
      var actual = await _rows('PRAGMA table_info("${table.actualTableName}")');
      if (actual.isEmpty) throw StateError('新版数据库缺表，拒绝自动修复');
      if (const {
            'AppBmf',
            'AppSubscription',
            'AppRssCache',
            'AppMigrationRecovery',
          }.contains(table.actualTableName) &&
          actual.length != table.$columns.length) {
        throw StateError('新版订阅表含有未支持的字段');
      }
      for (var column in table.$columns) {
        var matches = actual.where((c) => c['name'] == column.$name);
        if (matches.length != 1) throw StateError('新版数据库缺列，拒绝自动修复');
        var row = matches.single;
        var expectedType = column.type == DriftSqlType.int ? 'INTEGER' : 'TEXT';
        if ((row['type'] as String).toUpperCase() != expectedType ||
            (!column.$nullable && row['notnull'] != 1 && row['pk'] == 0) ||
            (table.$primaryKey.contains(column) && row['pk'] == 0)) {
          throw StateError('新版数据库列约束异常，拒绝写入');
        }
      }
    }
    const checks = {
      'AppSubscription': [
        "json_valid(sourceConfig) AND json_type(sourceConfig) = 'object'",
        'autoUpdate IN (0, 1)',
        "status IN ('active', 'needsReview')",
        "json_valid(pendingItems) AND json_type(pendingItems) = 'array'",
        "json_valid(knownItems) AND json_type(knownItems) = 'array'",
        'hasBaseline IN (0, 1)',
        'itemKeyVersion > 0',
      ],
      'AppRssCache': [
        'ttlMinutes >= 0',
        'lastSuccessAt >= 0',
        'lastAttemptAt >= 0',
        'lastFailedAt >= 0',
        'cacheVersion > 0',
      ],
      'AppMigrationRecovery': [
        "json_valid(payload) AND json_type(payload) = 'object'",
        "json_valid(candidateBmfIds) AND json_type(candidateBmfIds) = 'array'",
      ],
    };
    String normalized(String value) =>
        value.replaceAll(RegExp(r'[\s"`]'), '').toLowerCase();
    for (var entry in checks.entries) {
      var row = await customSelect(
        'SELECT sql FROM sqlite_master WHERE name = ?',
        variables: [Variable(entry.key)],
      ).getSingle();
      var sql = normalized(row.read<String>('sql'));
      if (entry.value.any(
        (check) => !sql.contains('check(${normalized(check)})'),
      )) {
        throw StateError('新版数据库 CHECK 约束缺失');
      }
    }
    var foreignKeys = await _rows('PRAGMA foreign_key_list(AppSubscription)');
    if (!foreignKeys.any(
      (f) =>
          f['table'] == 'AppBmf' &&
          f['from'] == 'bmfId' &&
          f['to'] == 'id' &&
          f['on_delete'] == 'CASCADE',
    )) {
      throw StateError('新版数据库订阅外键缺失');
    }
    for (var entry in const {
      'AppBmf': ['subject'],
      'AppSubscription': ['bmfId', 'feedKey'],
      'AppMigrationRecovery': ['migrationVersion', 'kind', 'legacyKey'],
    }.entries) {
      var indexes = await _rows('PRAGMA index_list("${entry.key}")');
      var found = false;
      for (var index in indexes.where((i) => i['unique'] == 1)) {
        var columns = await _rows('PRAGMA index_info("${index['name']}")');
        if (jsonEncode(columns.map((c) => c['name']).toList()) ==
            jsonEncode(entry.value)) {
          found = true;
        }
      }
      if (!found) throw StateError('新版数据库唯一约束缺失');
    }
    var feedIndex = await _rows('PRAGMA index_info(AppSubscription_feedKey)');
    if (feedIndex.length != 1 || feedIndex.single['name'] != 'feedKey') {
      throw StateError('新版数据库 feedKey 索引缺失');
    }
  }
}
