// Project imports:
import '../../core/services/playback_window_protocol.dart';
import '../../domain/repositories/playback_cover.dart';
import '../../domain/repositories/playback_history.dart';
import '../../domain/repositories/playback_library.dart';
import '../../domain/repositories/playback_settings.dart';
import '../../domain/repositories/playback_subjects.dart';
import '../../models/playback/playback_item.dart';

typedef PlaybackWindowCall =
    Future<Object?> Function(String method, Map<String, Object?> body);

class RemotePlaybackLibrary implements PlaybackLibrary {
  RemotePlaybackLibrary(this.call);
  final PlaybackWindowCall call;
  @override
  Future<void> ensureReady(String filePath) async {
    await call('library.ready', {'filePath': filePath});
  }

  @override
  Future<List<PlaybackItem>> discover(String directory, {int? subject}) async {
    var result = await call('library.discover', {
      'directory': directory,
      'subject': subject,
    });
    return (result as List).map(decodePlaybackItem).toList();
  }
}

class RemotePlaybackHistory implements PlaybackHistoryStore {
  RemotePlaybackHistory(this.call);
  final PlaybackWindowCall call;
  @override
  Future<PlaybackItem?> read(String filePath) async {
    var result = await call('history.read', {'filePath': filePath});
    return result == null ? null : decodePlaybackItem(result);
  }

  @override
  Future<List<PlaybackItem>> readAll() async {
    var result = await call('history.all', {});
    return (result as List).map(decodePlaybackItem).toList();
  }

  @override
  Future<void> write(PlaybackItem item) async {
    await call('history.write', {'item': item.toRow()});
  }

  @override
  Future<void> delete(String filePath) async {
    await call('history.delete', {'filePath': filePath});
  }
}

class RemotePlaybackSettings implements PlaybackSettingsStore {
  RemotePlaybackSettings(this.call);
  final PlaybackWindowCall call;
  @override
  Future<String?> read(String key) async {
    return await call('settings.read', {'key': key}) as String?;
  }

  @override
  Future<void> write(String key, String value) async {
    await call('settings.write', {'key': key, 'value': value});
  }
}

class RemotePlaybackSubjects implements PlaybackSubjectResolver {
  RemotePlaybackSubjects(this.call);
  final PlaybackWindowCall call;
  @override
  Future<int?> subjectForFile(String filePath) async {
    return await call('subjects.resolve', {'filePath': filePath}) as int?;
  }
}

class RemotePlaybackCover implements PlaybackCoverResolver {
  RemotePlaybackCover(this.call);
  final PlaybackWindowCall call;
  final _cache = <int, Map<String, Object?>>{};
  final _pending = <int, Future<String?>>{};
  @override
  bool contains(int subject) => _cache.containsKey(subject);
  @override
  String? coverOf(int subject) => _cache[subject]?['url'] as String?;
  @override
  String? nameOf(int subject) => _cache[subject]?['name'] as String?;
  @override
  Future<String?> resolve(int subject) {
    if (contains(subject)) return Future.value(coverOf(subject));
    return _pending.putIfAbsent(subject, () async {
      try {
        _cache[subject] = playbackMap(
          await call('cover.resolve', {'subject': subject}),
        );
        return coverOf(subject);
      } finally {
        await _pending.remove(subject);
      }
    });
  }
}
