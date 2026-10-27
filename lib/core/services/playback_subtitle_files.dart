// Dart imports:
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import '../../domain/repositories/playback_settings.dart';
import '../../models/playback/playback_item.dart';
import '../../models/playback/playback_subtitle.dart';
import '../utils/playback_episode_number.dart';

class PlaybackSubtitleImport {
  const PlaybackSubtitleImport({required this.files, required this.matches});

  final List<String> files;
  final Map<String, List<String>> matches;

  int get matchedFiles =>
      matches.values.fold(0, (sum, files) => sum + files.length);
  int get unmatchedFiles => files.length - matchedFiles;
}

/// External subtitle associations survive episode changes and player windows.
class PlaybackSubtitleFiles {
  const PlaybackSubtitleFiles(this.settings);

  final PlaybackSettingsStore settings;

  static const extensions = ['ass', 'ssa', 'srt', 'vtt', 'sub'];
  static const settingsKeyPrefix = 'playbackSubtitles:';

  static bool isSubtitle(String file) {
    var extension = path.extension(file).toLowerCase();
    return extension.isNotEmpty && extensions.contains(extension.substring(1));
  }

  String _key(PlaybackItem item) => '$settingsKeyPrefix${item.key}';

  Future<List<String>> read(PlaybackItem item) async {
    var value = await settings.read(_key(item));
    return value == null || value.isEmpty
        ? []
        : (jsonDecode(value) as List).cast<String>();
  }

  Future<PlaybackSubtitleImport> importDirectory(
    String directory,
    List<PlaybackItem> items,
  ) async {
    var files = await Directory(directory)
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File && isSubtitle(entity.path))
        .map((entity) => entity.path)
        .toList();
    files.sort();
    var result = match(files, items);
    for (var item in items) {
      var matched = result.matches[item.key];
      if (matched == null) continue;
      var combined = <String, String>{
        for (var file in [...await read(item), ...matched])
          PlaybackItem.pathKey(file): file,
      };
      await settings.write(_key(item), jsonEncode(combined.values.toList()));
    }
    return result;
  }

  /// Prefer complete basenames. Numbers must identify exactly one video.
  static PlaybackSubtitleImport match(
    Iterable<String> files,
    List<PlaybackItem> items,
  ) {
    var subtitles = <String, String>{
      for (var file in files.where(isSubtitle))
        PlaybackItem.pathKey(file): file,
    }.values.toList();
    var videos = {for (var item in items) item.key: item}.values.toList();
    var matches = <String, List<String>>{};
    for (var file in subtitles) {
      var name = path.basenameWithoutExtension(file).toLowerCase();
      var stems = _withoutLanguage(name).toList();
      var candidates = videos.where((item) {
        var video = path.basenameWithoutExtension(item.filePath).toLowerCase();
        return stems.contains(video);
      }).toList();
      if (candidates.isNotEmpty) {
        // A language word can be part of the video title itself.
        var longest = candidates
            .map((item) => path.basenameWithoutExtension(item.filePath).length)
            .reduce((a, b) => a > b ? a : b);
        candidates.removeWhere(
          (item) =>
              path.basenameWithoutExtension(item.filePath).length != longest,
        );
      } else {
        var stem = stems.last;
        var episode = PlaybackEpisodeNumber.parse(stem);
        if (episode == null) continue;
        var title = _title(stem, episode);
        candidates = videos.where((item) {
          var video = path.basenameWithoutExtension(item.filePath);
          var number = PlaybackEpisodeNumber.fromPath(item.filePath);
          if (number == null || number.number != episode.number) return false;
          if (number.season != null &&
              episode.season != null &&
              number.season != episode.season) {
            return false;
          }
          var videoTitle = _title(video, number);
          return title.isEmpty || videoTitle.isEmpty || title == videoTitle;
        }).toList();
      }
      if (candidates.length != 1) continue;
      matches.putIfAbsent(candidates.single.key, () => []).add(file);
    }
    return PlaybackSubtitleImport(files: subtitles, matches: matches);
  }

  static Iterable<String> _withoutLanguage(String name) sync* {
    var separators = RegExp(r'[ ._\-\[【(]+');
    while (true) {
      yield name;
      var last = separators.allMatches(name).lastOrNull;
      if (last == null) return;
      var suffix = name.substring(last.end).replaceAll(RegExp(r'[\]】)]+$'), '');
      if (playbackSubtitlePriority(title: suffix) == null) return;
      name = name.substring(0, last.start);
    }
  }

  static String _title(String name, PlaybackEpisodeNumber episode) => name
      .substring(0, episode.start)
      .replaceAll(RegExp(r'\[[^\]]*\]|【[^】]*】|\([^)]*\)'), '')
      .replaceAll(RegExp(r'[\s._\-]+'), '')
      .toLowerCase();
}
