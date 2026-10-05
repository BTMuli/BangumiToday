part of '../bt_database.dart';

extension _CatalogMigration on BtDatabase {
  Future<void> _migrateCatalog({required bool backup}) async {
    await _validateV2();
    for (var entry in const {
      'BangumiCollection': ['name', 'nameCn'],
      'BangumiDataItem': ['itemKey'],
    }.entries) {
      var columns = await _rows('PRAGMA table_info("${entry.key}")');
      if (columns.any((c) => entry.value.contains(c['name']))) {
        throw StateError('旧版本号下存在 v3 投影字段，已停止迁移');
      }
    }
    var digest = await _inputDigest();
    if (backup) await _backupMigration();
    await transaction(() async {
      if (await _inputDigest() != digest) {
        throw StateError('备份期间数据库已变化，请关闭其他客户端后重试');
      }
      onMigration?.call('SQLite v3 migration phase: begin');
      var migrator = Migrator(this);
      await migrator.addColumn(bangumiCollection, bangumiCollection.name);
      await migrator.addColumn(bangumiCollection, bangumiCollection.nameCn);
      await migrator.addColumn(bangumiDataItem, bangumiDataItem.itemKey);
      var collections = await _rows(
        'SELECT subjectId, subject FROM BangumiCollection',
      );
      var items = await _rows('SELECT * FROM BangumiDataItem ORDER BY id');
      var keys = <String>{};
      await batch((batch) {
        for (var row in collections) {
          var (name, nameCn) = collectionTitles(row['subject'] as String?);
          batch.customStatement(
            'UPDATE BangumiCollection SET name = ?, nameCn = ? '
            'WHERE subjectId = ?',
            [name, nameCn, row['subjectId']],
          );
        }
        for (var row in items) {
          var key = dataItemKey(row);
          // Preserve malformed or duplicate rows, including their original IDs.
          if (key == null || !keys.add(key)) key = 'legacy:${row['id']}';
          batch.customStatement(
            'UPDATE BangumiDataItem SET itemKey = ? WHERE id = ?',
            [key, row['id']],
          );
        }
      });
      for (var index in allSchemaEntities.whereType<Index>().where(
        (index) => index.entityName != 'AppSubscription_feedKey',
      )) {
        await migrator.createIndex(index);
      }
      await _validateV3();
      if ((await _rows('PRAGMA integrity_check')).single.values.single !=
          'ok') {
        throw StateError('v3 迁移后数据库完整性校验失败');
      }
      onMigration?.call('SQLite v3 migration phase: beforeVersion');
      await customStatement('PRAGMA user_version = 3');
      onMigration?.call('SQLite v3 migration phase: beforeCommit');
    });
    onMigration?.call('SQLite v3 migration phase: committed');
  }

  Future<void> _validateV3() async {
    await _validateV2(includeProjections: true);
    for (var entry in const {
      'BangumiCollection': ['name', 'nameCn'],
      'BangumiDataItem': ['itemKey'],
    }.entries) {
      var columns = await _rows('PRAGMA table_info("${entry.key}")');
      for (var name in entry.value) {
        var column = columns.singleWhere((c) => c['name'] == name);
        if (column['notnull'] != 1 || column['dflt_value'] != "''") {
          throw StateError('v3 投影字段约束异常：${entry.key}.$name');
        }
      }
    }
    for (var spec in const [
      (
        'BangumiCollection',
        'BangumiCollection_search',
        ['collectionType', 'name', 'nameCn'],
        0,
      ),
      ('BangumiDataItem', 'BangumiDataItem_title', ['title'], 0),
      ('BangumiDataItem', 'BangumiDataItem_itemKey', ['itemKey'], 1),
    ]) {
      var indexes = await _rows('PRAGMA index_list("${spec.$1}")');
      var columns = await _rows('PRAGMA index_info("${spec.$2}")');
      var details = await _rows('PRAGMA index_xinfo("${spec.$2}")');
      if (!indexes.any(
            (i) =>
                i['name'] == spec.$2 &&
                i['unique'] == spec.$4 &&
                i['partial'] == 0,
          ) ||
          jsonEncode(columns.map((c) => c['name']).toList()) !=
              jsonEncode(spec.$3) ||
          details
              .where((c) => c['key'] == 1)
              .any((c) => c['coll'] != 'BINARY')) {
        throw StateError('v3 投影索引异常：${spec.$2}');
      }
    }
    if ((await _rows(
      "SELECT 1 FROM BangumiDataItem WHERE itemKey = '' LIMIT 1",
    )).isNotEmpty) {
      throw StateError('数据集条目身份缺失');
    }
  }
}
