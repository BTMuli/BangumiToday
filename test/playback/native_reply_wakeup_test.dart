// Dart imports:
import 'dart:ffi';
import 'dart:io';

// Package imports:
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/generated/libmpv/bindings.dart' as bindings;
import 'package:media_kit/media_kit.dart';

// Project imports:
import 'package:bangumi_today/core/services/native_playback_property_reader.dart';
import 'package:bangumi_today/core/services/native_upscale_adapter.dart';

/// A raw headless core without media, audio, video or a Flutter player.
class _HeadlessPlayer extends Fake implements NativePlayer {
  _HeadlessPlayer(this.mpv, this.ctx);

  @override
  final bindings.MPV mpv;
  @override
  Pointer<bindings.mpv_handle> ctx;
  @override
  bool disposed = false;
  @override
  final List<Future<void> Function()> release = [];
  @override
  Future<void> get waitForPlayerInitialization => Future.value();
  @override
  Future<void> get waitForVideoControllerInitializationIfAttached =>
      Future.value();
}

void main() {
  var dll = File('build/windows/x64/libmpv-ajan-20261007/libmpv-2.dll');
  var available = Platform.isWindows && dll.existsSync();
  late _HeadlessPlayer player;
  late NativeUpscaleAdapter adapter;
  late NativePlaybackPropertyReader reader;

  setUp(() {
    if (!available) return;
    var api = bindings.MPV(DynamicLibrary.open(dll.absolute.path));
    var core = api.mpv_create();
    expect(core, isNot(nullptr));
    for (var entry in {'vo': 'null', 'ao': 'null', 'config': 'no'}.entries) {
      var key = entry.key.toNativeUtf8();
      var value = entry.value.toNativeUtf8();
      try {
        expect(api.mpv_set_option_string(core, key.cast(), value.cast()), 0);
      } finally {
        calloc.free(key);
        calloc.free(value);
      }
    }
    expect(api.mpv_initialize(core), 0);
    player = _HeadlessPlayer(api, core);
    adapter = NativeUpscaleAdapter(player);
    reader = NativePlaybackPropertyReader(player);
  });

  tearDown(() async {
    if (!available) return;
    for (var close in player.release) {
      await close().timeout(const Duration(seconds: 3));
    }
    player.mpv.mpv_terminate_destroy(player.ctx);
    player.disposed = true;
  });

  test(
    '原生唤醒完成串行超分配置命令及并行属性读取',
    () async {
      expect(await adapter.read('mpv-version'), isA<String>());
      await adapter.setString('pause', 'yes');
      expect(await adapter.read('pause'), isTrue);
      await adapter.command(['set', 'volume', '35']);
      expect(await adapter.read('volume'), 35);
      var values = await Future.wait([
        reader.read('mpv-version'),
        reader.read('pause'),
        reader.read('volume'),
      ]);
      expect(values.every((value) => value.failure == null), isTrue);
      expect(values[1].value, 'yes');
    },
    skip: !available,
    timeout: const Timeout(Duration(seconds: 10)),
  );

  test(
    '关闭排空已接受回复，迟到的唤醒不访问已销毁客户端',
    () async {
      await adapter.read('mpv-version');
      var pending = [for (var i = 0; i < 30; i++) reader.read('mpv-version')];
      await Future<void>.delayed(Duration.zero);
      await reader.close();
      await Future.wait(pending);
      expect((await reader.read('pause')).issue, 'closed');
      await adapter.close();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    },
    skip: !available,
    timeout: const Timeout(Duration(seconds: 10)),
  );
}
