// Dart imports:
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' as sqlite;

// Project imports:
import 'package:bangumi_today/database/app/playback_episode_links.dart';
import 'package:bangumi_today/database/bt_hive.dart';
import 'package:bangumi_today/database/drift/bt_database.dart';
import 'package:bangumi_today/models/playback/playback_episode_link.dart';
import 'package:bangumi_today/models/playback/playback_episode_rule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('playback_episode_v5_');
    BTHiveTool.debugHiveRootOverride = path.join(tempDir.path, 'hive');
  });

  tearDown(() async {
    for (var name in const [
      'playback_episode_links',
      'playback_episode_rules',
    ]) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box<String>(name).close();
      }
    }
    try {
      await Hive.close();
    } catch (_) {}
    BTHiveTool.debugResetHiveRoot();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Drift 读写关联与规则，并保留条件删除语义', () async {
    var db = BtDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    var storage = PlaybackEpisodeLinksStorage(database: db);
    var video = path.join(tempDir.path, 'ep01.mkv');
    await File(video).create(recursive: true);
    var link = PlaybackEpisodeLink(filePath: video, subject: 42, episode: 1);
    var rule = PlaybackEpisodeRule(
      id: 'rule-1',
      subject: 42,
      pattern: r'ep(\d+)',
      offset: 0,
      type: 0,
      exampleFile: 'ep01.mkv',
    );

    await storage.write(link);
    await storage.writeRule(rule);
    var stored = await storage.readAll();
    expect(stored.keys, [link.key]);
    expect(stored[link.key]?.subject, 42);
    expect(stored[link.key]?.episode, 1);
    expect((await storage.readRules()).single.id, rule.id);

    await storage.remove(
      PlaybackEpisodeLink(filePath: video, subject: 42, episode: 2),
    );
    expect((await storage.readAll())[link.key]?.episode, 1);
    await storage.remove(link);
    expect(await storage.readAll(), isEmpty);

    await storage.removeRule(
      PlaybackEpisodeRule(
        id: rule.id,
        subject: rule.subject,
        pattern: rule.pattern,
        offset: 1,
        type: rule.type,
        exampleFile: rule.exampleFile,
      ),
    );
    expect((await storage.readRules()).single.id, rule.id);
    await storage.removeRule(rule);
    expect(await storage.readRules(), isEmpty);
  });

  test('v4 升级至 v5 时导入并删除 Hive 剧集盒', () async {
    var raw = sqlite.sqlite3.openInMemory();
    var old = BtDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    await old.customSelect('SELECT 1').get();
    await old.close();
    raw.execute('DROP TABLE AppPlaybackEpisodeLink');
    raw.execute('DROP TABLE AppPlaybackEpisodeRule');
    raw.execute('PRAGMA user_version = 4');

    var hiveDir = Directory(BTHiveTool.debugHiveRootOverride!);
    await hiveDir.create(recursive: true);
    BTHiveTool.debugResetHiveRoot();
    BTHiveTool.debugHiveRootOverride = hiveDir.path;
    await BTHiveTool.ensureHiveRoot();

    var video = path.join(tempDir.path, 'show', 'S01E02.mkv');
    await File(video).create(recursive: true);
    var link = PlaybackEpisodeLink(filePath: video, subject: 7, episode: 2);
    var rule = PlaybackEpisodeRule(
      id: 'r7',
      subject: 7,
      pattern: r'E(\d+)',
      offset: -1,
      type: 0,
      exampleFile: 'S01E02.mkv',
    );

    var linksBox = await Hive.openBox<String>('playback_episode_links');
    await linksBox.put(link.key, jsonEncode(link.toJson()));
    await linksBox.close();
    var rulesBox = await Hive.openBox<String>('playback_episode_rules');
    await rulesBox.put(rule.id, jsonEncode(rule.toJson()));
    await rulesBox.close();

    var db = BtDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      5,
    );
    var storage = PlaybackEpisodeLinksStorage(database: db);
    expect((await storage.readAll())[link.key]?.episode, 2);
    expect((await storage.readRules()).single.offset, -1);
    expect(await Hive.boxExists('playback_episode_links'), isFalse);
    expect(await Hive.boxExists('playback_episode_rules'), isFalse);
  });
}
