part of '../bt_database.dart';

extension _PlaybackEpisodeMigration on BtDatabase {
  Future<void> _migratePlaybackEpisodes({bool backup = false}) async {
    await _validateV4();
    for (var table in const [
      'AppPlaybackEpisodeLink',
      'AppPlaybackEpisodeRule',
    ]) {
      if ((await _rows('PRAGMA table_info("$table")')).isNotEmpty) {
        throw StateError('旧版本号下存在 v5 剧集关联表，已停止迁移');
      }
    }
    var links = await _readHiveEpisodeLinks();
    var rules = await _readHiveEpisodeRules();
    var digest = await _inputDigest();
    if (backup) await _backupMigration();
    await transaction(() async {
      if (await _inputDigest() != digest) {
        throw StateError('备份期间数据库已变化，请关闭其他客户端后重试');
      }
      var migrator = Migrator(this);
      await migrator.createTable(appPlaybackEpisodeLink);
      await migrator.createTable(appPlaybackEpisodeRule);
      if (links.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(appPlaybackEpisodeLink, links);
        });
      }
      if (rules.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(appPlaybackEpisodeRule, rules);
        });
      }
      await _validateV5();
      onMigration?.call(
        'SQLite v5 playback episodes: '
        '${links.length} links, ${rules.length} rules',
      );
    });
    await _deleteHiveEpisodeBoxes();
  }

  Future<List<AppPlaybackEpisodeLinkCompanion>> _readHiveEpisodeLinks() async {
    if (!await _prepareHiveRoot()) return const [];
    if (!await Hive.boxExists('playback_episode_links')) {
      return const [];
    }
    var box = await Hive.openBox<String>('playback_episode_links');
    try {
      var rows = <AppPlaybackEpisodeLinkCompanion>[];
      for (var key in box.keys) {
        var raw = box.get(key);
        if (raw == null) continue;
        var json = jsonDecode(raw) as Map<String, dynamic>;
        var link = PlaybackEpisodeLink.fromJson(json);
        if (link.key != key) {
          throw StateError('Hive 剧集关联主键与路径不一致');
        }
        rows.add(
          AppPlaybackEpisodeLinkCompanion.insert(
            pathKey: link.key,
            filePath: link.filePath,
            subject: link.subject,
            episode: Value(link.episode),
          ),
        );
      }
      return rows;
    } finally {
      await box.close();
    }
  }

  Future<List<AppPlaybackEpisodeRuleCompanion>> _readHiveEpisodeRules() async {
    if (!await _prepareHiveRoot()) return const [];
    if (!await Hive.boxExists('playback_episode_rules')) {
      return const [];
    }
    var box = await Hive.openBox<String>('playback_episode_rules');
    try {
      var rows = <AppPlaybackEpisodeRuleCompanion>[];
      for (var key in box.keys) {
        var raw = box.get(key);
        if (raw == null) continue;
        var json = jsonDecode(raw) as Map<String, dynamic>;
        var rule = PlaybackEpisodeRule.fromJson(json);
        if (rule.id != key) {
          throw StateError('Hive 剧集规则主键与 id 不一致');
        }
        rows.add(
          AppPlaybackEpisodeRuleCompanion.insert(
            id: rule.id,
            subject: rule.subject,
            pattern: rule.pattern,
            offset: _encodeOffset(rule.offset),
            type: rule.type,
            exampleFile: rule.exampleFile,
          ),
        );
      }
      return rows;
    } finally {
      await box.close();
    }
  }

  Future<bool> _prepareHiveRoot() async {
    try {
      await BTHiveTool.ensureHiveRoot();
      return true;
    } catch (error) {
      onMigration?.call('Hive root unavailable during v5 migration: $error');
      return false;
    }
  }

  Future<void> _deleteHiveEpisodeBoxes() async {
    if (!await _prepareHiveRoot()) return;
    for (var name in const [
      'playback_episode_links',
      'playback_episode_rules',
    ]) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box<String>(name).close();
      }
      if (await Hive.boxExists(name)) {
        await Hive.deleteBoxFromDisk(name);
        onMigration?.call('Hive box removed: $name');
      }
    }
  }

  Future<void> _validateV5() async {
    await _validateV4(includePlaybackEpisodes: true);
    var linkPk = await _rows('PRAGMA table_info(AppPlaybackEpisodeLink)');
    if (linkPk.singleWhere((c) => c['name'] == 'pathKey')['pk'] != 1) {
      throw StateError('v5 AppPlaybackEpisodeLink 主键异常');
    }
    var rulePk = await _rows('PRAGMA table_info(AppPlaybackEpisodeRule)');
    if (rulePk.singleWhere((c) => c['name'] == 'id')['pk'] != 1) {
      throw StateError('v5 AppPlaybackEpisodeRule 主键异常');
    }
  }
}

String _encodeOffset(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}
