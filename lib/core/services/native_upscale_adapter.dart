// Dart imports:
import 'dart:async';
import 'dart:ffi';

// Package imports:
import 'package:ffi/ffi.dart';
import 'package:media_kit/generated/libmpv/bindings.dart' as mpv;
import 'package:media_kit/media_kit.dart';

class NativeUpscaleException implements Exception {
  const NativeUpscaleException(this.operation, this.code, this.message);

  final String operation;
  final int code;
  final String message;

  @override
  String toString() => '$operation: $message ($code)';
}

/// Uses a weak client to keep async replies separate from media_kit. Native
/// requests never wait for the playback core on the Flutter isolate. Callers
/// still await each mutation before starting the next one to preserve order.
class NativeUpscaleAdapter {
  NativeUpscaleAdapter(this._player) {
    _player.release.add(close);
  }

  final NativePlayer _player;
  Pointer<mpv.mpv_handle> _client = nullptr;
  Future<void>? _opening;
  final _requests =
      <int, ({String operation, int reply, Completer<Object?> result})>{};
  final _reads = <String, Future<Object?>>{};
  final _closedResult = Completer<void>();
  Timer? _poll;
  int _nextId = 0;
  bool _closed = false;

  Future<void> close() {
    _closed = true;
    if (_requests.isEmpty) _destroy();
    return _closedResult.future;
  }

  Future<void> _open() => NativePlayer.lock.synchronized(() async {
    _checkOpen();
    await _player.waitForPlayerInitialization;
    await _player.waitForVideoControllerInitializationIfAttached;
    _checkOpen();
    if (_player.ctx == nullptr) throw StateError('播放器尚未初始化');
    _client = _player.mpv.mpv_create_weak_client(_player.ctx, nullptr);
    if (_client == nullptr) throw StateError('无法创建超分播放客户端');
    for (var id = 0; id <= mpv.mpv_event_id.MPV_EVENT_HOOK; id++) {
      _player.mpv.mpv_request_event(_client, id, 0);
    }
  });

  Future<T> _withPlayer<T>(Future<T> Function() action) async {
    _checkOpen();
    await (_opening ??= _open());
    _checkOpen();
    // Do not hold media_kit's disposal lock while waiting for async replies.
    return action();
  }

  void _checkOpen() {
    if (_closed || _player.disposed) {
      throw StateError('播放适配器或播放器已关闭');
    }
  }

  void _checkResult(String operation, int code) {
    if (code >= 0) return;
    var message = _player.mpv.mpv_error_string(code);
    throw NativeUpscaleException(
      operation,
      code,
      message == nullptr
          ? 'unknown mpv error'
          : message.cast<Utf8>().toDartString(),
    );
  }

  Future<Object?> _request(
    String operation,
    int reply,
    int Function(int id) submit,
  ) {
    _checkOpen();
    if (_requests.length >= 64) throw StateError('超分播放请求队列已满');
    var id = ++_nextId;
    var result = Completer<Object?>();
    _requests[id] = (operation: operation, reply: reply, result: result);
    try {
      _checkResult(operation, submit(id));
    } catch (error, stackTrace) {
      _requests.remove(id);
      result.completeError(error, stackTrace);
    }
    if (_requests.isNotEmpty) {
      _poll ??= Timer.periodic(
        const Duration(milliseconds: 16),
        (_) => _drain(),
      );
    }
    return result.future;
  }

  void _drain() {
    for (var count = 0; count < 128 && _client != nullptr; count++) {
      var event = _player.mpv.mpv_wait_event(_client, 0).ref;
      if (event.event_id == mpv.mpv_event_id.MPV_EVENT_NONE) break;
      var request = _requests[event.reply_userdata];
      if (request == null || event.event_id != request.reply) continue;
      _requests.remove(event.reply_userdata);
      try {
        _checkResult(request.operation, event.error);
        Object? value;
        if (event.event_id == mpv.mpv_event_id.MPV_EVENT_GET_PROPERTY_REPLY) {
          if (event.data == nullptr) {
            throw const FormatException('mpv property reply is empty');
          }
          var property = event.data.cast<mpv.mpv_event_property>().ref;
          if (property.format != mpv.mpv_format.MPV_FORMAT_NODE ||
              property.data == nullptr) {
            throw const FormatException('mpv property reply has no node');
          }
          // Event-owned data expires at the next mpv_wait_event. Copy it now;
          // it must not be released with mpv_free_node_contents.
          value = _MpvNodeReader().read(property.data.cast<mpv.mpv_node>().ref);
        }
        request.result.complete(value);
      } catch (error, stackTrace) {
        request.result.completeError(error, stackTrace);
      }
    }
    if (_requests.isEmpty) {
      _poll?.cancel();
      _poll = null;
      if (_closed) _destroy();
    }
  }

  void _destroy() {
    // mpv_destroy waits for pending replies. Only destroy after draining them,
    // and let Player.release await this before destroying the playback core.
    if (_client != nullptr) {
      _player.mpv.mpv_destroy(_client);
      _client = nullptr;
    }
    if (!_closedResult.isCompleted) _closedResult.complete();
  }

  /// Only used for short playback configuration commands, never media loading.
  Future<void> command(List<String> arguments) {
    if (arguments.isEmpty ||
        arguments.length > 16 ||
        arguments.any((value) => value.contains('\u0000'))) {
      throw ArgumentError.value(arguments, 'arguments');
    }
    var command = List<String>.of(arguments);
    return _withPlayer(() {
      var strings = <Pointer<Utf8>>[];
      var pointers = calloc<Pointer<Int8>>(command.length + 1);
      try {
        for (var index = 0; index < command.length; index++) {
          var value = command[index].toNativeUtf8();
          strings.add(value);
          pointers[index] = value.cast();
        }
        return _request(
          command.first,
          mpv.mpv_event_id.MPV_EVENT_COMMAND_REPLY,
          (id) => _player.mpv.mpv_command_async(_client, id, pointers),
        ).then<void>((_) {});
      } finally {
        for (var value in strings) {
          calloc.free(value);
        }
        calloc.free(pointers);
      }
    });
  }

  /// Replace the complete list in one native mutation. MPV_FORMAT_NODE avoids
  /// path-list escaping and keeps the renderer from seeing partial presets.
  Future<void> setStringList(String property, List<String> values) {
    if (property.isEmpty ||
        property.contains('\u0000') ||
        values.any((value) => value.contains('\u0000'))) {
      throw ArgumentError('Invalid mpv string list');
    }
    var entries = List<String>.of(values);
    return _withPlayer(() {
      var name = property.toNativeUtf8();
      var node = calloc<mpv.mpv_node>();
      var list = calloc<mpv.mpv_node_list>();
      var items = calloc<mpv.mpv_node>(entries.length);
      var strings = <Pointer<Utf8>>[];
      try {
        for (var index = 0; index < entries.length; index++) {
          var value = entries[index].toNativeUtf8();
          strings.add(value);
          items[index].format = mpv.mpv_format.MPV_FORMAT_STRING;
          items[index].u.string = value.cast();
        }
        list.ref.num = entries.length;
        list.ref.values = items;
        node.ref.format = mpv.mpv_format.MPV_FORMAT_NODE_ARRAY;
        node.ref.u.list = list;
        return _request(
          'set $property',
          mpv.mpv_event_id.MPV_EVENT_SET_PROPERTY_REPLY,
          (id) => _player.mpv.mpv_set_property_async(
            _client,
            id,
            name.cast(),
            mpv.mpv_format.MPV_FORMAT_NODE,
            node.cast(),
          ),
        ).then<void>((_) {});
      } finally {
        for (var value in strings) {
          calloc.free(value);
        }
        calloc.free(items);
        calloc.free(list);
        calloc.free(node);
        calloc.free(name);
      }
    });
  }

  /// Sets one scalar string property. MPV_FORMAT_STRING keeps the value opaque,
  /// so filter chains and option strings need no path escaping.
  Future<void> setString(String property, String value) {
    if (property.isEmpty ||
        property.contains('\u0000') ||
        value.contains('\u0000')) {
      throw ArgumentError('Invalid mpv string property');
    }
    return _withPlayer(() {
      var name = property.toNativeUtf8();
      var text = value.toNativeUtf8();
      try {
        var data = calloc<Pointer<Int8>>();
        try {
          data.value = text.cast();
          return _request(
            'set $property',
            mpv.mpv_event_id.MPV_EVENT_SET_PROPERTY_REPLY,
            (id) => _player.mpv.mpv_set_property_async(
              _client,
              id,
              name.cast(),
              mpv.mpv_format.MPV_FORMAT_STRING,
              data.cast(),
            ),
          ).then<void>((_) {});
        } finally {
          calloc.free(data);
        }
      } finally {
        calloc.free(text);
        calloc.free(name);
      }
    });
  }

  /// Coalesce reads so a delayed core cannot accumulate repeated polling work.
  Future<Object?> read(String property) {
    if (property.isEmpty || property.contains('\u0000')) {
      throw ArgumentError.value(property, 'property');
    }
    _checkOpen();
    return _reads.putIfAbsent(
      property,
      () => _read(property).whenComplete(() {
        _reads.remove(property);
      }),
    );
  }

  Future<Object?> _read(String property) => _withPlayer(() {
    var name = property.toNativeUtf8();
    try {
      return _request(
        'read $property',
        mpv.mpv_event_id.MPV_EVENT_GET_PROPERTY_REPLY,
        (id) => _player.mpv.mpv_get_property_async(
          _client,
          id,
          name.cast(),
          mpv.mpv_format.MPV_FORMAT_NODE,
        ),
      );
    } finally {
      calloc.free(name);
    }
  });
}

class _MpvNodeReader {
  int _remaining = 32768;

  Object? read(mpv.mpv_node node, [int depth = 0]) {
    if (depth > 16 || --_remaining < 0) {
      throw const FormatException('mpv property exceeds decoding limit');
    }
    switch (node.format) {
      case mpv.mpv_format.MPV_FORMAT_NONE:
        return null;
      case mpv.mpv_format.MPV_FORMAT_STRING:
        if (node.u.string == nullptr) {
          throw const FormatException('mpv string is null');
        }
        return node.u.string.cast<Utf8>().toDartString();
      case mpv.mpv_format.MPV_FORMAT_FLAG:
        return node.u.flag != 0;
      case mpv.mpv_format.MPV_FORMAT_INT64:
        return node.u.int64;
      case mpv.mpv_format.MPV_FORMAT_DOUBLE:
        return node.u.double_;
      case mpv.mpv_format.MPV_FORMAT_NODE_ARRAY:
      case mpv.mpv_format.MPV_FORMAT_NODE_MAP:
        if (node.u.list == nullptr) {
          throw const FormatException('mpv list is null');
        }
        var list = node.u.list.ref;
        if (list.num < 0 ||
            list.num > _remaining ||
            (list.num > 0 && list.values == nullptr)) {
          throw const FormatException('mpv list has invalid length');
        }
        if (node.format == mpv.mpv_format.MPV_FORMAT_NODE_ARRAY) {
          return List<Object?>.unmodifiable([
            for (var index = 0; index < list.num; index++)
              read(list.values[index], depth + 1),
          ]);
        }
        if (list.num > 0 && list.keys == nullptr) {
          throw const FormatException('mpv map has no keys');
        }
        var result = <String, Object?>{};
        for (var index = 0; index < list.num; index++) {
          if (list.keys[index] == nullptr) {
            throw const FormatException('mpv map key is null');
          }
          result[list.keys[index].cast<Utf8>().toDartString()] = read(
            list.values[index],
            depth + 1,
          );
        }
        return Map<String, Object?>.unmodifiable(result);
      default:
        throw FormatException('unsupported mpv node format ${node.format}');
    }
  }
}
