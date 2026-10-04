// Dart imports:
import 'dart:convert';

// Project imports:
import '../../models/playback/playback_completion.dart';
import '../../models/playback/playback_item.dart';

/// Only codec values cross engines. Native handles and credentials stay local.
class PlaybackWindowIdentity {
  const PlaybackWindowIdentity(this.generation);

  static const version = 1;
  final String generation;
  String get hostChannel => 'bangumi_today.playback.$generation';

  String encode() => jsonEncode({
    'version': version,
    'role': 'playback',
    'generation': generation,
  });

  factory PlaybackWindowIdentity.decode(String arguments) {
    var value = playbackMap(jsonDecode(arguments));
    if (value['version'] != version || value['role'] != 'playback') {
      throw const FormatException('无法识别播放器窗口协议');
    }
    return PlaybackWindowIdentity(playbackString(value, 'generation'));
  }

  Map<String, Object?> request(int sequence, Map<String, Object?> body) => {
    'version': version,
    'generation': generation,
    'sequence': sequence,
    'body': body,
  };

  PlaybackWindowRequest read(Object? value) {
    var data = playbackMap(value);
    if (data['version'] != version || data['generation'] != generation) {
      throw StateError('播放器窗口会话已经失效');
    }
    return PlaybackWindowRequest(
      playbackInt(data, 'sequence', minimum: 1),
      playbackMap(data['body']),
    );
  }
}

class PlaybackWindowRequest {
  const PlaybackWindowRequest(this.sequence, this.body);
  final int sequence;
  final Map<String, Object?> body;
}

Map<String, Object?> playbackMap(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('无效的播放器消息');
  }
  return Map<String, Object?>.from(value);
}

String playbackString(Map<String, Object?> value, String key) {
  var result = value[key];
  if (result is! String || result.isEmpty || result.contains('\u0000')) {
    throw FormatException('无效的播放器字段：$key');
  }
  return result;
}

int playbackInt(Map<String, Object?> value, String key, {int minimum = 0}) {
  var result = value[key];
  if (result is! int || result < minimum) {
    throw FormatException('无效的播放器字段：$key');
  }
  return result;
}

int? playbackSubject(Map<String, Object?> value) =>
    value['subject'] == null ? null : playbackInt(value, 'subject', minimum: 1);

PlaybackItem decodePlaybackItem(Object? value, {bool includeSize = false}) {
  var data = playbackMap(value);
  var done = data['completed'];
  if (done != 0 && done != 1) {
    throw const FormatException('无效的播放完成状态');
  }
  return PlaybackItem(
    filePath: playbackString(data, 'filePath'),
    title: playbackString(data, 'title'),
    subject: playbackSubject(data),
    sizeBytes: includeSize ? playbackInt(data, 'sizeBytes', minimum: 1) : null,
    positionMs: playbackInt(data, 'positionMs'),
    durationMs: playbackInt(data, 'durationMs'),
    completed: done == 1,
    updatedAt: playbackInt(data, 'updatedAt'),
  );
}

Map<String, Object?> encodePlaybackCompletion(PlaybackCompletion value) => {
  'sessionId': value.sessionId,
  'item': value.item.toRow(),
  'positionMs': value.positionMs,
  'durationMs': value.durationMs,
};

PlaybackCompletion decodePlaybackCompletion(Object? value) {
  var data = playbackMap(value);
  return PlaybackCompletion(
    sessionId: playbackString(data, 'sessionId'),
    item: decodePlaybackItem(data['item']),
    positionMs: playbackInt(data, 'positionMs'),
    durationMs: playbackInt(data, 'durationMs', minimum: 1),
  );
}
