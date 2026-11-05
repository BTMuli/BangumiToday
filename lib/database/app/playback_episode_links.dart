// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:drift/drift.dart';

// Project imports:
import '../../core/utils/playback_paths.dart';
import '../../domain/repositories/playback_episode_links.dart';
import '../../models/playback/playback_episode_link.dart';
import '../../models/playback/playback_episode_rule.dart';
import '../bt_sqlite.dart';
import '../drift/bt_database.dart';

/// Drift-backed chapter associations and filename rules.
///
/// Schema owned by `BtDatabase` (v5+). Hive boxes are imported once during
/// migration and are no longer opened here.
class PlaybackEpisodeLinksStorage implements PlaybackEpisodeLinks {
  PlaybackEpisodeLinksStorage({BtDatabase? database}) : _database = database;

  final BtDatabase? _database;

  BtDatabase get db => _database ?? BTSqlite().db;

  @override
  Future<List<PlaybackEpisodeRule>> readRules() async {
    var rows = await db.select(db.appPlaybackEpisodeRule).get();
    return List.unmodifiable([for (var row in rows) _ruleFromRow(row)]);
  }

  @override
  Stream<List<PlaybackEpisodeRule>> watchRules() {
    return db
        .select(db.appPlaybackEpisodeRule)
        .watch()
        .distinct()
        .map(
          (rows) =>
              List.unmodifiable([for (var row in rows) _ruleFromRow(row)]),
        );
  }

  @override
  Future<void> writeRule(PlaybackEpisodeRule rule) async {
    if (rule.subject <= 0 ||
        rule.id.isEmpty ||
        rule.pattern.isEmpty ||
        !rule.offset.isFinite ||
        rule.type < 0 ||
        rule.type > 6 ||
        rule.numberFor(rule.exampleFile) == null) {
      throw ArgumentError('请提供有效的匹配规则和样例文件名');
    }
    await db
        .into(db.appPlaybackEpisodeRule)
        .insertOnConflictUpdate(_ruleCompanion(rule));
  }

  @override
  Future<void> removeRule(PlaybackEpisodeRule rule) async {
    var query = db.select(db.appPlaybackEpisodeRule)
      ..where((table) => table.id.equals(rule.id));
    var row = await query.getSingleOrNull();
    if (row == null) return;
    if (jsonEncode(_ruleFromRow(row).toJson()) == jsonEncode(rule.toJson())) {
      var delete = db.delete(db.appPlaybackEpisodeRule)
        ..where((table) => table.id.equals(rule.id));
      await delete.go();
    }
  }

  @override
  Future<Map<String, PlaybackEpisodeLink>> readAll() async {
    var rows = await db.select(db.appPlaybackEpisodeLink).get();
    return Map.unmodifiable({
      for (var row in rows) row.pathKey: _linkFromRow(row),
    });
  }

  @override
  Stream<Map<String, PlaybackEpisodeLink>> watchAll() {
    return db
        .select(db.appPlaybackEpisodeLink)
        .watch()
        .distinct()
        .map(
          (rows) => Map.unmodifiable({
            for (var row in rows) row.pathKey: _linkFromRow(row),
          }),
        );
  }

  @override
  Future<void> write(PlaybackEpisodeLink link) async {
    if (link.subject <= 0 ||
        (link.episode != null && link.episode! <= 0) ||
        !PlaybackPaths.isVideo(link.filePath)) {
      throw ArgumentError('请选择视频文件和有效章节');
    }
    await db
        .into(db.appPlaybackEpisodeLink)
        .insertOnConflictUpdate(_linkCompanion(link));
  }

  @override
  Future<void> remove(PlaybackEpisodeLink link) async {
    var query = db.select(db.appPlaybackEpisodeLink)
      ..where((table) => table.pathKey.equals(link.key));
    var row = await query.getSingleOrNull();
    if (row == null) return;
    var current = _linkFromRow(row);
    if (current.subject == link.subject && current.episode == link.episode) {
      var delete = db.delete(db.appPlaybackEpisodeLink)
        ..where((table) => table.pathKey.equals(link.key));
      await delete.go();
    }
  }

  PlaybackEpisodeLink _linkFromRow(PlaybackEpisodeLinkRow row) =>
      PlaybackEpisodeLink(
        filePath: row.filePath,
        subject: row.subject,
        episode: row.episode,
      );

  AppPlaybackEpisodeLinkCompanion _linkCompanion(PlaybackEpisodeLink link) =>
      AppPlaybackEpisodeLinkCompanion(
        pathKey: Value(link.key),
        filePath: Value(link.filePath),
        subject: Value(link.subject),
        episode: Value(link.episode),
      );

  PlaybackEpisodeRule _ruleFromRow(PlaybackEpisodeRuleRow row) =>
      PlaybackEpisodeRule(
        id: row.id,
        subject: row.subject,
        pattern: row.pattern,
        offset: _decodeOffset(row.offset),
        type: row.type,
        exampleFile: row.exampleFile,
      );

  AppPlaybackEpisodeRuleCompanion _ruleCompanion(PlaybackEpisodeRule rule) =>
      AppPlaybackEpisodeRuleCompanion(
        id: Value(rule.id),
        subject: Value(rule.subject),
        pattern: Value(rule.pattern),
        offset: Value(_encodeOffset(rule.offset)),
        type: Value(rule.type),
        exampleFile: Value(rule.exampleFile),
      );
}

String _encodeOffset(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

double _decodeOffset(String value) {
  var parsed = double.tryParse(value);
  if (parsed == null || !parsed.isFinite) {
    throw FormatException('无效的剧集规则偏移', value);
  }
  return parsed;
}
