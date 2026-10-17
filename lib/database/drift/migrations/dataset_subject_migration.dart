part of '../bt_database.dart';

extension _DatasetSubjectMigration on BtDatabase {
  Future<void> _migrateDatasetSubjects({bool backup = false}) async {
    await _validateV3();
    if ((await _rows('PRAGMA table_info(BangumiDataSubject)')).isNotEmpty) {
      throw StateError('旧版本号下存在 v4 数据集投影表，已停止迁移');
    }
    var digest = await _inputDigest();
    if (backup) await _backupMigration();
    await transaction(() async {
      if (await _inputDigest() != digest) {
        throw StateError('备份期间数据库已变化，请关闭其他客户端后重试');
      }
      var migrator = Migrator(this);
      await migrator.createTable(bangumiDataSubject);
      await migrator.createIndex(
        allSchemaEntities.whereType<Index>().singleWhere(
          (index) => index.entityName == 'BangumiDataSubject_itemId',
        ),
      );
      await rebuildDatasetSubjects(this);
      await _validateV4();
      onMigration?.call('SQLite v4 dataset projection: complete');
    });
  }

  Future<void> _validateV4() async {
    await _validateV3(includeDatasetSubjects: true);
    var columns = await _rows('PRAGMA table_info(BangumiDataSubject)');
    if (columns.length != 2 ||
        columns[0]['name'] != 'subjectId' ||
        columns[0]['pk'] != 1 ||
        columns[1]['name'] != 'itemId' ||
        columns[1]['pk'] != 2) {
      throw StateError('v4 数据集投影主键异常');
    }
    var keys = await _rows('PRAGMA foreign_key_list(BangumiDataSubject)');
    if (keys.length != 1 ||
        keys.single['table'] != 'BangumiDataItem' ||
        keys.single['from'] != 'itemId' ||
        keys.single['to'] != 'id' ||
        keys.single['on_delete'] != 'CASCADE') {
      throw StateError('v4 数据集投影外键异常');
    }
    var index = await _rows('PRAGMA index_info(BangumiDataSubject_itemId)');
    if (index.length != 1 || index.single['name'] != 'itemId') {
      throw StateError('v4 数据集投影索引异常');
    }
  }
}
