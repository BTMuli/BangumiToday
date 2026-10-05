// media_kit has no public library-path getter. Match its own screenshot worker
// so the isolate opens the exact same mpv binary as the owning NativePlayer.
// ignore_for_file: implementation_imports

// Dart imports:
import 'dart:ffi';
import 'dart:ui' as ui;

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:ffi/ffi.dart';
import 'package:media_kit/generated/libmpv/bindings.dart' as mpv;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit/src/player/native/core/native_library.dart';

// Project imports:
import '../errors/playback_unavailable.dart';

abstract final class PlaybackScreenshot {
  static Future<Uint8List?> capture(
    Player player, {
    required bool rendered,
  }) async {
    if (!rendered) {
      return player.screenshot(
        format: 'image/png',
        includeLibassSubtitles: true,
      );
    }
    var native = player.platform as NativePlayer;
    // Hold media_kit's disposal lock until the worker copies mpv-owned data.
    var frame = await NativePlayer.lock.synchronized(() async {
      if (native.disposed) throw StateError('播放器已经关闭');
      await native.waitForPlayerInitialization;
      await native.waitForVideoControllerInitializationIfAttached;
      if (native.disposed || native.ctx == nullptr) {
        throw StateError('播放器已经关闭');
      }
      return compute(_renderedFrame, (native.ctx.address, NativeLibrary.path));
    });
    var buffer = await ui.ImmutableBuffer.fromUint8List(frame.pixels);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: frame.width,
        height: frame.height,
        rowBytes: frame.width * 4,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      codec = await descriptor.instantiateCodec();
      image = (await codec.getNextFrame()).image;
      var data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}

typedef _ScreenshotFrame = ({int width, int height, Uint8List pixels});

/// Window screenshots use the active GPU shader chain at the output texture
/// size. Flutter controls and overlays are outside mpv and are not captured.
_ScreenshotFrame _renderedFrame((int, String) request) {
  var api = mpv.MPV(DynamicLibrary.open(request.$2));
  var handle = Pointer<mpv.mpv_handle>.fromAddress(request.$1);
  var arguments = ['screenshot-raw', 'window', 'rgba'];
  var strings = arguments.map((value) => value.toNativeUtf8()).toList();
  var pointers = calloc<Pointer<Int8>>(arguments.length + 1);
  var result = calloc<mpv.mpv_node>();
  try {
    for (var i = 0; i < strings.length; i++) {
      pointers[i] = strings[i].cast();
    }
    var code = api.mpv_command_ret(handle, pointers, result);
    if (code < 0) {
      var message = api.mpv_error_string(code);
      var detail = message == nullptr
          ? '$code'
          : message.cast<Utf8>().toDartString();
      throw PlaybackUnavailable('无法截取超分画面：$detail');
    }
    if (result.ref.format != mpv.mpv_format.MPV_FORMAT_NODE_MAP) {
      throw const PlaybackUnavailable('当前没有可截取的超分画面');
    }
    var fields = <String, mpv.mpv_node>{};
    var list = result.ref.u.list.ref;
    for (var i = 0; i < list.num; i++) {
      fields[list.keys[i].cast<Utf8>().toDartString()] = list.values[i];
    }
    int integer(String key) {
      var value = fields[key];
      if (value?.format != mpv.mpv_format.MPV_FORMAT_INT64) {
        throw const FormatException('截图尺寸无效');
      }
      return value!.u.int64;
    }

    var width = integer('w');
    var height = integer('h');
    var stride = integer('stride');
    var format = fields['format'];
    var data = fields['data'];
    if (width <= 0 ||
        height <= 0 ||
        width * height > 16777216 ||
        stride.abs() < width * 4 ||
        format?.format != mpv.mpv_format.MPV_FORMAT_STRING ||
        format!.u.string.cast<Utf8>().toDartString() != 'rgba' ||
        data?.format != mpv.mpv_format.MPV_FORMAT_BYTE_ARRAY) {
      throw const FormatException('截图像素格式无效');
    }
    var bytes = data!.u.ba.ref;
    if (bytes.data == nullptr ||
        bytes.size < stride.abs() * (height - 1) + width * 4) {
      throw const FormatException('截图像素数据不完整');
    }
    var pixels = Uint8List(width * height * 4);
    var source = bytes.data.cast<Uint8>();
    for (var y = 0; y < height; y++) {
      pixels.setRange(
        y * width * 4,
        (y + 1) * width * 4,
        (source + y * stride).asTypedList(width * 4),
      );
    }
    return (width: width, height: height, pixels: pixels);
  } finally {
    api.mpv_free_node_contents(result);
    calloc.free(result);
    calloc.free(pointers);
    for (var value in strings) {
      calloc.free(value);
    }
  }
}
