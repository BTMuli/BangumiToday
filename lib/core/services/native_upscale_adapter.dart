// Dart imports:
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

/// Uses media_kit 1.2.6's existing bindings and disposal lock. No additional
/// mpv client, cached handle, event loop or asynchronous request IDs are
/// created. Close this adapter before disposing its owning Player.
class NativeUpscaleAdapter {
  NativeUpscaleAdapter(this._player);

  final NativePlayer _player;
  bool _closed = false;

  void close() => _closed = true;

  Future<T> _withPlayer<T>(T Function() action) {
    return NativePlayer.lock.synchronized(() async {
      _checkOpen();
      await _player.waitForPlayerInitialization;
      await _player.waitForVideoControllerInitializationIfAttached;
      _checkOpen();
      if (_player.ctx == nullptr) throw StateError('播放器尚未初始化');
      return action();
    });
  }

  void _checkOpen() {
    if (_closed || _player.disposed) {
      throw StateError('超分适配器或播放器已关闭');
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

  /// Only used for short shader configuration commands, never media loading.
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
        _checkResult(
          command.first,
          _player.mpv.mpv_command(_player.ctx, pointers),
        );
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
        _checkResult(
          'set $property',
          _player.mpv.mpv_set_property(
            _player.ctx,
            name.cast(),
            mpv.mpv_format.MPV_FORMAT_NODE,
            node.cast(),
          ),
        );
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

  /// Copies a native property into Dart values before freeing mpv-owned data.
  Future<Object?> read(String property) {
    if (property.isEmpty || property.contains('\u0000')) {
      throw ArgumentError.value(property, 'property');
    }
    return _withPlayer(() {
      var name = property.toNativeUtf8();
      var node = calloc<mpv.mpv_node>();
      var received = false;
      try {
        _checkResult(
          'read $property',
          _player.mpv.mpv_get_property(
            _player.ctx,
            name.cast(),
            mpv.mpv_format.MPV_FORMAT_NODE,
            node.cast(),
          ),
        );
        received = true;
        return _MpvNodeReader().read(node.ref);
      } finally {
        if (received) _player.mpv.mpv_free_node_contents(node);
        calloc.free(node);
        calloc.free(name);
      }
    });
  }
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
