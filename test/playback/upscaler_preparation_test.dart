// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/playback_upscaler.dart';
import 'package:bangumi_today/models/playback/playback_janai_frame_rate.dart';
import 'package:bangumi_today/models/playback/playback_janai_status.dart';
import 'package:bangumi_today/models/playback/playback_upscale.dart';

const _budgetFailure = 'AnimeJaNai exceeded the frame budget for three windows';

void main() {
  test('旧 AI 档位性能回退后继续等待并启用已请求的新档位', () async {
    var backend = _Backend();
    var upscaler = _createUpscaler(backend);
    await _enableQuality(upscaler, backend);

    upscaler.preferences(PlaybackUpscaleMode.janaiSmooth);
    await _until(() => backend.preparations.length == 2);
    expect(upscaler.configuredMode, PlaybackUpscaleMode.janaiQuality);

    upscaler.log('vf/animejanai', 'error', _budgetFailure);
    await _until(() => backend.installedSlot == null);
    backend.preparations.last.complete();

    await _until(
      () => upscaler.configuredMode == PlaybackUpscaleMode.janaiSmooth,
    );
    expect(upscaler.selectedMode, PlaybackUpscaleMode.janaiSmooth);
    expect(upscaler.warning, isNull);
    expect(backend.installs, [2, null, 1]);
    expect(backend.preparations, hasLength(2));
  });

  test('准备在旧档位清理完成前结束时仍能启用新档位', () async {
    var backend = _Backend();
    var upscaler = _createUpscaler(backend);
    await _enableQuality(upscaler, backend);

    upscaler.preferences(PlaybackUpscaleMode.janaiSmooth);
    await _until(() => backend.preparations.length == 2);
    var recovery = backend.recovery = Completer<void>();
    upscaler.log('vf/animejanai', 'error', _budgetFailure);
    await _until(() => backend.restoring);
    backend.preparations.last.complete();
    await _settle();
    expect(backend.installs, [2]);

    recovery.complete();
    await _until(
      () => upscaler.configuredMode == PlaybackUpscaleMode.janaiSmooth,
    );
    expect(backend.installs, [2, null, 1]);
  });

  test('新档位编译失败保持普通播放且不自动重试', () async {
    var backend = _Backend();
    var upscaler = _createUpscaler(backend);
    await _enableQuality(upscaler, backend);

    upscaler.preferences(PlaybackUpscaleMode.janaiSmooth);
    await _until(() => backend.preparations.length == 2);
    backend.preparations.last.completeError(StateError('compile failed'));
    await _until(() => upscaler.warning != null);
    await _settle();

    expect(upscaler.selectedMode, PlaybackUpscaleMode.off);
    expect(upscaler.configuredMode, isNull);
    expect(backend.installs, [2, null]);
    expect(backend.preparations, hasLength(2));
  });

  test('新档位启用后自身性能不足仍回退且不自动重试', () async {
    var backend = _Backend();
    var upscaler = _createUpscaler(backend);
    await _enableQuality(upscaler, backend);
    upscaler.preferences(PlaybackUpscaleMode.janaiSmooth);
    await _until(() => backend.preparations.length == 2);
    backend.preparations.last.complete();
    await _until(
      () => upscaler.configuredMode == PlaybackUpscaleMode.janaiSmooth,
    );

    upscaler.log('vf/animejanai', 'error', _budgetFailure);
    await _until(() => upscaler.warning != null);
    await _settle();

    expect(upscaler.selectedMode, PlaybackUpscaleMode.off);
    expect(upscaler.configuredMode, isNull);
    expect(backend.installs, [2, 1, null]);
    expect(backend.preparations, hasLength(2));
  });

  test('清理重试成功不会覆盖新档位的编译失败状态', () async {
    var backend = _Backend();
    var upscaler = _createUpscaler(backend);
    await _enableQuality(upscaler, backend);
    upscaler.preferences(PlaybackUpscaleMode.janaiSmooth);
    await _until(() => backend.preparations.length == 2);
    var recovery = backend.recovery = Completer<void>();
    backend.recoveryFailures = 1;
    upscaler.log('vf/animejanai', 'error', _budgetFailure);
    await _until(() => backend.restoring);

    backend.preparations.last.completeError(StateError('compile failed'));
    await _settle();
    recovery.complete();
    await _until(() => upscaler.warning != null);
    await _settle();

    expect(upscaler.selectedMode, PlaybackUpscaleMode.off);
    expect(upscaler.configuredMode, isNull);
    expect(backend.preparations, hasLength(2));
    expect(backend.installs, isNot(contains(1)));
  });

  test('用户在旧档位清理期间关闭超分后不再启用新档位', () async {
    var backend = _Backend();
    var upscaler = _createUpscaler(backend);
    await _enableQuality(upscaler, backend);
    upscaler.preferences(PlaybackUpscaleMode.janaiSmooth);
    await _until(() => backend.preparations.length == 2);
    var recovery = backend.recovery = Completer<void>();
    upscaler.log('vf/animejanai', 'error', _budgetFailure);
    await _until(() => backend.restoring);

    upscaler.preferences(PlaybackUpscaleMode.off);
    backend.preparations.last.complete();
    recovery.complete();
    await _until(() => upscaler.configuredMode == null);
    await _settle();

    expect(upscaler.selectedMode, PlaybackUpscaleMode.off);
    expect(backend.installs, [2, null]);
  });

  test('旧档位清理失败时新引擎就绪也不继续应用', () async {
    var backend = _Backend();
    var upscaler = _createUpscaler(backend);
    await _enableQuality(upscaler, backend);
    upscaler.preferences(PlaybackUpscaleMode.janaiSmooth);
    await _until(() => backend.preparations.length == 2);
    backend.recoveryFailures = 2;
    upscaler.log('vf/animejanai', 'error', _budgetFailure);
    await _until(() => upscaler.warning?.contains('清理失败') == true);
    backend.preparations.last.complete();
    await _settle();

    expect(upscaler.configuredMode, isNull);
    expect(backend.installs, isNot(contains(1)));
    expect(upscaler.warning, contains('清理失败'));
  });
}

PlaybackUpscaler _createUpscaler(_Backend backend) {
  var upscaler = PlaybackUpscaler(
    backend: backend,
    loadShaders: (_) async => const [],
    onChanged: () {},
    onError: (_) {},
    debounce: Duration.zero,
  );
  backend.upscaler = upscaler;
  addTearDown(upscaler.close);
  upscaler.log('vo/gpu', 'info', "GL_RENDERER='NVIDIA Test'");
  upscaler.viewport((width: 1920, height: 1080, dpr: 1));
  upscaler.mediaReady(
    playbackVideoSource(width: 1280, height: 720, gamma: 'bt.1886'),
  );
  return upscaler;
}

Future<void> _enableQuality(PlaybackUpscaler upscaler, _Backend backend) async {
  upscaler.preferences(PlaybackUpscaleMode.janaiQuality);
  await _until(() => backend.preparations.isNotEmpty);
  backend.preparations.single.complete();
  await _until(
    () => upscaler.configuredMode == PlaybackUpscaleMode.janaiQuality,
  );
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 100; i++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('超分状态未完成预期转换');
}

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Backend extends PlaybackUpscaleBackend {
  late final PlaybackUpscaler upscaler;
  final preparations = <Completer<void>>[];
  final installs = <int?>[];
  int? installedSlot;
  PlaybackJanaiFrameRate? _frameRate;
  Completer<void>? recovery;
  bool restoring = false;
  int recoveryFailures = 0;

  @override
  Future<void> prepareJanai(
    int slot,
    PlaybackVideoSource source,
    String renderer,
  ) {
    var preparation = Completer<void>();
    preparations.add(preparation);
    return preparation.future;
  }

  @override
  Future<void> command(List<String> arguments) async {}

  @override
  Future<Object?> read(String property) async => switch (property) {
    'current-tracks/video/demux-fps' => 24,
    _ => null,
  };

  @override
  Future<void> shaders(List<String> paths) async {
    if (paths.isEmpty) {
      restoring = true;
      await recovery?.future;
      if (recoveryFailures > 0) {
        recoveryFailures--;
        throw StateError('cleanup failed');
      }
    }
  }

  @override
  Future<void> janai(int? slot, {PlaybackJanaiFrameRate? frameRate}) async {
    installedSlot = slot;
    _frameRate = frameRate;
    installs.add(slot);
  }

  @override
  Future<void> janaiFrameRate(PlaybackJanaiFrameRate? value) async {
    _frameRate = value;
  }

  @override
  Future<PlaybackJanaiStatus?> janaiStatus() async => null;

  @override
  Future<List<Map<Object?, Object?>>> filterList() async => [
    if (_frameRate != null)
      {
        'name': 'lavfi',
        'label': PlaybackUpscaleBackend.janaiFrameRateLabel,
        'enabled': true,
        'params': {'graph': _frameRate!.graph},
      },
    if (installedSlot != null)
      {
        'name': 'animejanai',
        'label': PlaybackUpscaleBackend.janaiFilterLabel,
        'enabled': true,
        'params': {'slot': '$installedSlot', 'conf': 'test.conf'},
      },
  ];

  @override
  Future<void> resize(PlaybackPixels? size) async => upscaler.texture(size);

  @override
  Future<void> close() async {
    for (var preparation in preparations) {
      if (!preparation.isCompleted) {
        preparation.completeError(StateError('closed'));
      }
    }
  }
}
