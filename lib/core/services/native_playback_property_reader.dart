// Dart imports:
import 'dart:async';
import 'dart:ffi';

// Package imports:
import 'package:ffi/ffi.dart';
import 'package:media_kit/generated/libmpv/bindings.dart' as mpv;
import 'package:media_kit/media_kit.dart';

/// Queues reads without waiting for mpv's playback/render thread on the UI
/// isolate. A separate weak client keeps replies out of media_kit's event loop.
class NativePlaybackPropertyReader {
  NativePlaybackPropertyReader(this._player) {
    _player.release.add(close);
  }

  final NativePlayer _player;
  Pointer<mpv.mpv_handle> _client = nullptr;
  Future<void>? _opening;
  final _requests = <int, ({String name, Completer<String> result})>{};
  final _byName = <String, int>{};
  final _closedResult = Completer<void>();
  Timer? _poll;
  int _nextId = 0;
  int _generation = 0;
  bool _closed = false;

  Future<void> _open() => NativePlayer.lock.synchronized(() async {
    if (_closed || _player.disposed) return;
    await _player.waitForPlayerInitialization;
    await _player.waitForVideoControllerInitializationIfAttached;
    if (_closed || _player.disposed) return;
    _client = _player.mpv.mpv_create_weak_client(_player.ctx, nullptr);
    if (_client == nullptr) throw StateError('无法创建播放属性读取器');
    // Keep only replies; playback events are already consumed by media_kit.
    for (var id = 0; id <= mpv.mpv_event_id.MPV_EVENT_HOOK; id++) {
      _player.mpv.mpv_request_event(_client, id, 0);
    }
  });

  Future<String> read(String property) async {
    if (property.isEmpty || property.contains('\u0000')) {
      throw ArgumentError.value(property, 'property');
    }
    if (_closed || _player.disposed) return '';
    var generation = _generation;
    await (_opening ??= _open());
    if (_closed || _player.disposed || generation != _generation) return '';
    var existing = _byName[property];
    if (existing != null) return _requests[existing]!.result.future;
    // A timed-out caller cannot cancel a native read. Keep it in flight and
    // coalesce retries so a busy core cannot build an unbounded request queue.
    if (_requests.length >= 64) return '';
    var id = ++_nextId;
    var result = Completer<String>();
    var name = property.toNativeUtf8();
    int status;
    try {
      status = _player.mpv.mpv_get_property_async(
        _client,
        id,
        name.cast(),
        mpv.mpv_format.MPV_FORMAT_STRING,
      );
    } finally {
      calloc.free(name);
    }
    if (status < 0) return '';
    _requests[id] = (name: property, result: result);
    _byName[property] = id;
    _poll ??= Timer.periodic(const Duration(milliseconds: 16), (_) => _drain());
    return result.future;
  }

  void _drain() {
    // Copy event-owned strings before the next mpv_wait_event invalidates them.
    // A zero timeout never waits for the playback core or a rendered frame.
    for (var count = 0; count < 128; count++) {
      var event = _player.mpv.mpv_wait_event(_client, 0).ref;
      if (event.event_id == mpv.mpv_event_id.MPV_EVENT_NONE) break;
      if (event.event_id != mpv.mpv_event_id.MPV_EVENT_GET_PROPERTY_REPLY) {
        continue;
      }
      var request = _requests.remove(event.reply_userdata);
      if (request == null) continue;
      if (_byName[request.name] == event.reply_userdata) {
        _byName.remove(request.name);
      }
      var value = '';
      if (event.error >= 0 && event.data != nullptr) {
        var property = event.data.cast<mpv.mpv_event_property>().ref;
        if (property.format == mpv.mpv_format.MPV_FORMAT_STRING &&
            property.data != nullptr) {
          var string = property.data.cast<Pointer<Utf8>>().value;
          if (string != nullptr) value = string.toDartString();
        }
      }
      if (!request.result.isCompleted) request.result.complete(value);
    }
    if (_requests.isEmpty) {
      _poll?.cancel();
      _poll = null;
      if (_closed) _destroy();
    }
  }

  /// Discard old-media results without losing the native requests to drain.
  void invalidate() {
    _generation++;
    _byName.clear();
    for (var request in _requests.values) {
      if (!request.result.isCompleted) request.result.complete('');
    }
  }

  Future<void> close() {
    if (!_closed) {
      _closed = true;
      invalidate();
      if (_requests.isEmpty) _destroy();
    }
    return _closedResult.future;
  }

  void _destroy() {
    // mpv_destroy waits for outstanding async requests. Drain their replies
    // first, and let Player.release await this cleanup before core destruction.
    if (_client != nullptr) {
      _player.mpv.mpv_destroy(_client);
      _client = nullptr;
    }
    if (!_closedResult.isCompleted) _closedResult.complete();
  }
}
