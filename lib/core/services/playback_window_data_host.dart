// Dart imports:
import 'dart:async';
import 'dart:convert';

// Project imports:
import '../../domain/repositories/playback_cover.dart';
import '../../domain/repositories/playback_history.dart';
import '../../domain/repositories/playback_library.dart';
import '../../domain/repositories/playback_settings.dart';
import '../../domain/repositories/playback_subjects.dart';
import '../../models/playback/playback_item.dart';
import 'playback_window_protocol.dart';

/// A generation owns its requests until all writes settle. A timeout on the
/// transport cannot cancel a durable write or authorize a second writer.
class PlaybackWindowDataHost {
  PlaybackWindowDataHost({
    required this.identity,
    required this.library,
    required this.history,
    required this.settings,
    required this.subjects,
    required this.cover,
    required this.onHistoryChanged,
  });

  final PlaybackWindowIdentity identity;
  final PlaybackLibrary library;
  final PlaybackHistoryStore history;
  final PlaybackSettingsStore settings;
  final PlaybackSubjectResolver subjects;
  final PlaybackCoverResolver cover;
  final void Function() onHistoryChanged;
  static const allowedSettings = {
    'playbackHiResEnabled',
    'playbackUpscaleMode',
    'playbackRememberedRate',
    'playbackLoudnessEnabled',
    'playbackWindowBounds',
    'playbackEpisodeLayout',
    'playbackOnTop',
  };
  final _requests = <int, (String, String, Future<Object?>)>{};
  final _revisions = <String, int>{};
  Future<void> _writes = Future.value();
  bool _active = true;
  bool _accepting = true;

  Future<Object?> handle(String method, Object? arguments) {
    if (!_accepting) throw StateError('播放器窗口会话已经关闭');
    var request = identity.read(arguments);
    var fingerprint = jsonEncode(request.body);
    var previous = _requests[request.sequence];
    if (previous != null) {
      if (previous.$1 != method || previous.$2 != fingerprint) {
        throw const FormatException('播放器请求编号重复');
      }
      return previous.$3;
    }
    var future = Future<Object?>.sync(() => _dispatch(method, request));
    _requests[request.sequence] = (method, fingerprint, future);
    // Keep in-flight requests even when the completed reply cache is full.
    unawaited(
      future.then(
        (_) => _trim(request.sequence),
        onError: (Object _) => _trim(request.sequence),
      ),
    );
    return future;
  }

  final _settled = <int>{};
  void _trim(int sequence) {
    _settled.add(sequence);
    while (_requests.length > 256 && _settled.isNotEmpty) {
      var oldest = _settled.first;
      _settled.remove(oldest);
      _requests.remove(oldest);
    }
  }

  Future<Object?> _dispatch(
    String method,
    PlaybackWindowRequest request,
  ) async {
    var body = request.body;
    switch (method) {
      case 'library.ready':
        await library.ensureReady(playbackString(body, 'filePath'));
        return null;
      case 'library.discover':
        var items = await library.discover(
          playbackString(body, 'directory'),
          subject: playbackSubject(body),
        );
        return [
          for (var item in items)
            {...item.toRow(), 'sizeBytes': item.sizeBytes},
        ];
      case 'subjects.resolve':
        return subjects.subjectForFile(playbackString(body, 'filePath'));
      case 'library.nextEpisode':
        return library.nextEpisodeIndex(
          (body['items'] as List).map(decodePlaybackItem).toList(),
          playbackInt(body, 'index'),
        );
      case 'cover.resolve':
        var subject = playbackInt(body, 'subject', minimum: 1);
        await cover.resolve(subject);
        return {'url': cover.coverOf(subject), 'name': cover.nameOf(subject)};
      case 'history.read':
        await _writes;
        return (await history.read(playbackString(body, 'filePath')))?.toRow();
      case 'history.all':
        await _writes;
        return [for (var item in await history.readAll()) item.toRow()];
      case 'history.write':
        var item = decodePlaybackItem(body['item']);
        await _mutate('history:${item.key}', request.sequence, () async {
          await history.write(item);
          onHistoryChanged();
        });
        return null;
      case 'history.delete':
        var file = playbackString(body, 'filePath');
        await _mutate(
          'history:${PlaybackItem.pathKey(file)}',
          request.sequence,
          () async {
            await history.delete(file);
            onHistoryChanged();
          },
        );
        return null;
      case 'settings.read':
        var key = _settingKey(body);
        await _writes;
        return settings.read(key);
      case 'settings.write':
        var key = _settingKey(body);
        var value = body['value'];
        if (value is! String) throw const FormatException('无效的配置值');
        await _mutate('settings:$key', request.sequence, () {
          return settings.write(key, value);
        });
        return null;
      default:
        throw FormatException('不支持的播放器数据请求：$method');
    }
  }

  String _settingKey(Map<String, Object?> body) {
    var key = playbackString(body, 'key');
    if (!allowedSettings.contains(key)) throw StateError('不可访问的配置：$key');
    return key;
  }

  Future<void> _mutate(
    String key,
    int sequence,
    Future<void> Function() action,
  ) {
    var operation = _writes.then((_) async {
      if (!_active) throw StateError('播放器窗口会话已经关闭');
      if (sequence <= (_revisions[key] ?? 0)) return;
      await action();
      _revisions[key] = sequence;
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> close() async {
    // Refuse new requests, but allow already accepted mutations to drain.
    _accepting = false;
    await _writes;
    _active = false;
    _requests.clear();
    _settled.clear();
  }
}
