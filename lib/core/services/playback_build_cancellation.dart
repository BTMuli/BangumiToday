// Dart imports:
import 'dart:ffi';

// Package imports:
import 'package:ffi/ffi.dart';

/// A per-configuration Windows event shared with the native build worker.
/// Signalling it bypasses mpv and the serialized media-operation queue.
class PlaybackBuildCancellation {
  PlaybackBuildCancellation(this.name) {
    _handle = using(
      (arena) =>
          _createEvent(nullptr, 1, 0, name.toNativeUtf16(allocator: arena)),
    );
    if (_handle == nullptr) throw StateError('无法创建 TensorRT 编译取消信号');
  }

  final String name;
  Pointer<Void> _handle = nullptr;
  static final _kernel = DynamicLibrary.open('kernel32.dll');
  static final _createEvent = _kernel
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Int32, Int32, Pointer<Utf16>),
        Pointer<Void> Function(Pointer<Void>, int, int, Pointer<Utf16>)
      >('CreateEventW');
  static final _setEvent = _kernel
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('SetEvent');
  static final _closeHandle = _kernel
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('CloseHandle');

  void cancel() {
    if (_handle != nullptr) _setEvent(_handle);
  }

  void dispose() {
    if (_handle == nullptr) return;
    _closeHandle(_handle);
    _handle = nullptr;
  }
}
