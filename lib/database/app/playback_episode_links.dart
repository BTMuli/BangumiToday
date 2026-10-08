// Dart imports:
import 'dart:async';
import 'dart:convert';

// Package imports:
import 'package:hive_ce/hive_ce.dart';

// Project imports:
import '../../core/utils/playback_paths.dart';
import '../../domain/repositories/playback_episode_links.dart';
import '../../models/playback/playback_episode_link.dart';
import '../../models/playback/playback_episode_rule.dart';

/// Opened only by the main engine, like download subject associations.
class PlaybackEpisodeLinksStorage implements PlaybackEpisodeLinks {
  Future<Box<String>>? _opening;
  Future<Box<String>>? _openingRules;

  Future<Box<String>> _openRules() async {
    var opening = _openingRules ??= Hive.openBox<String>(
      'playback_episode_rules',
    );
    try {
      return await opening;
    } catch (_) {
      if (identical(_openingRules, opening)) _openingRules = null;
      rethrow;
    }
  }

  List<PlaybackEpisodeRule> _rules(Box<String> box) => List.unmodifiable([
    for (var value in box.values)
      PlaybackEpisodeRule.fromJson(jsonDecode(value) as Map<String, dynamic>),
  ]);

  @override
  Future<List<PlaybackEpisodeRule>> readRules() async =>
      _rules(await _openRules());

  @override
  Stream<List<PlaybackEpisodeRule>> watchRules() async* {
    var box = await _openRules();
    yield* Stream<List<PlaybackEpisodeRule>>.multi((controller) {
      var subscription = box.watch().listen(
        (_) => controller.add(_rules(box)),
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
      controller.add(_rules(box));
    });
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
    await (await _openRules()).put(rule.id, jsonEncode(rule.toJson()));
  }

  @override
  Future<void> removeRule(PlaybackEpisodeRule rule) async {
    var box = await _openRules();
    if (box.get(rule.id) == jsonEncode(rule.toJson())) {
      await box.delete(rule.id);
    }
  }

  Future<Box<String>> _open() async {
    var opening = _opening ??= Hive.openBox<String>('playback_episode_links');
    try {
      return await opening;
    } catch (_) {
      if (identical(_opening, opening)) _opening = null;
      rethrow;
    }
  }

  Map<String, PlaybackEpisodeLink> _snapshot(Box<String> box) =>
      Map.unmodifiable({
        for (var key in box.keys)
          key as String: PlaybackEpisodeLink.fromJson(
            jsonDecode(box.get(key)!) as Map<String, dynamic>,
          ),
      });

  @override
  Future<Map<String, PlaybackEpisodeLink>> readAll() async =>
      _snapshot(await _open());

  @override
  Stream<Map<String, PlaybackEpisodeLink>> watchAll() async* {
    var box = await _open();
    yield* Stream<Map<String, PlaybackEpisodeLink>>.multi((controller) {
      var subscription = box.watch().listen(
        (_) => controller.add(_snapshot(box)),
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
      controller.add(_snapshot(box));
    });
  }

  @override
  Future<void> write(PlaybackEpisodeLink link) async {
    if (link.subject <= 0 ||
        (link.episode != null && link.episode! <= 0) ||
        !PlaybackPaths.isVideo(link.filePath)) {
      throw ArgumentError('请选择视频文件和有效章节');
    }
    await (await _open()).put(link.key, jsonEncode(link.toJson()));
  }

  @override
  Future<void> remove(PlaybackEpisodeLink link) async {
    var box = await _open();
    var value = box.get(link.key);
    if (value == null) return;
    var current = PlaybackEpisodeLink.fromJson(
      jsonDecode(value) as Map<String, dynamic>,
    );
    if (current.subject == link.subject && current.episode == link.episode) {
      await box.delete(link.key);
    }
  }
}
