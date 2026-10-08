// Dart imports:
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

// Package imports:
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

/// Settings can check the driver without creating a Player or enabling AI.
/// The native bridge still validates the actual playback adapter separately.
class PlaybackTensorRtGpu {
  const PlaybackTensorRtGpu({
    this.name = '',
    this.sm = 0,
    this.driver = 0,
    this.error = '',
  });

  final String name;
  final int sm;
  final int driver;
  final String error;
  bool get supported => error.isEmpty && sm == 89 && driver >= 13040;
  String get driverLabel => '${driver ~/ 1000}.${driver % 1000 ~/ 10}';
  String get label =>
      error.isNotEmpty ? error : '$name · SM$sm · CUDA $driverLabel';
  String get requirement => error.isNotEmpty
      ? error
      : sm != 89
      ? '当前组件仅支持 SM89 显卡，检测到 SM$sm'
      : driver < 13040
      ? '请更新 NVIDIA 驱动，需要支持 CUDA 13.4 或更高版本'
      : '';

  static Future<PlaybackTensorRtGpu> detect() => Isolate.run(_detect);

  static PlaybackTensorRtGpu _detect() {
    if (!Platform.isWindows) {
      return const PlaybackTensorRtGpu(error: 'TensorRT 仅支持 Windows');
    }
    // Load only the graphics driver's system DLL, never the bundle or PATH.
    var driverFile = path.join(
      Platform.environment['SystemRoot']!,
      'System32',
      'nvcuda.dll',
    );
    if (!File(driverFile).existsSync()) {
      return const PlaybackTensorRtGpu(error: '未检测到 NVIDIA CUDA 驱动');
    }
    var count = calloc<Int32>();
    var version = calloc<Int32>();
    var device = calloc<Int32>();
    var major = calloc<Int32>();
    var minor = calloc<Int32>();
    var name = calloc<Char>(256);
    try {
      var library = DynamicLibrary.open(driverFile);
      var init = library
          .lookupFunction<Int32 Function(Uint32), int Function(int)>('cuInit');
      var getCount = library
          .lookupFunction<
            Int32 Function(Pointer<Int32>),
            int Function(Pointer<Int32>)
          >('cuDeviceGetCount');
      var getVersion = library
          .lookupFunction<
            Int32 Function(Pointer<Int32>),
            int Function(Pointer<Int32>)
          >('cuDriverGetVersion');
      var getDevice = library
          .lookupFunction<
            Int32 Function(Pointer<Int32>, Int32),
            int Function(Pointer<Int32>, int)
          >('cuDeviceGet');
      var getAttribute = library
          .lookupFunction<
            Int32 Function(Pointer<Int32>, Int32, Int32),
            int Function(Pointer<Int32>, int, int)
          >('cuDeviceGetAttribute');
      var getName = library
          .lookupFunction<
            Int32 Function(Pointer<Char>, Int32, Int32),
            int Function(Pointer<Char>, int, int)
          >('cuDeviceGetName');
      if (init(0) != 0 ||
          getCount(count) != 0 ||
          getVersion(version) != 0 ||
          count.value < 1) {
        return const PlaybackTensorRtGpu(error: 'NVIDIA 驱动不可用，请检查显卡驱动');
      }
      PlaybackTensorRtGpu? first;
      for (var ordinal = 0; ordinal < count.value; ordinal++) {
        // CUDA's COMPUTE_CAPABILITY_MAJOR / MINOR attributes are 75 / 76.
        if (getDevice(device, ordinal) != 0 ||
            getAttribute(major, 75, device.value) != 0 ||
            getAttribute(minor, 76, device.value) != 0 ||
            getName(name, 256, device.value) != 0) {
          continue;
        }
        var gpu = PlaybackTensorRtGpu(
          name: name.cast<Utf8>().toDartString(),
          sm: major.value * 10 + minor.value,
          driver: version.value,
        );
        first ??= gpu;
        if (gpu.supported) return gpu;
      }
      return first ?? const PlaybackTensorRtGpu(error: '无法读取 NVIDIA 显卡信息');
    } catch (error) {
      return PlaybackTensorRtGpu(error: '检测 NVIDIA 显卡失败：$error');
    } finally {
      calloc.free(count);
      calloc.free(version);
      calloc.free(device);
      calloc.free(major);
      calloc.free(minor);
      calloc.free(name);
    }
  }
}
