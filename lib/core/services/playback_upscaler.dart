import 'dart:async';

import '../../models/playback/playback_fit.dart';
import '../../models/playback/playback_upscale.dart';

abstract class PlaybackUpscaleBackend {
  Future<void> command(List<String> arguments);
  Future<Object?> read(String property);
  Future<void> resize(PlaybackPixels? size);
  Future<void> redraw();
  void close();
}

/// One coordinator per Player. Layout events replace a single pending plan;
/// they never join the Store's media-operation queue.
class PlaybackUpscaler {
  static final _rendererPattern = RegExp("GL_RENDERER='([^']+)'");
  PlaybackUpscaler({
    required this.backend,
    required this.loadShaders,
    required this.onChanged,
    required this.onError,
    this.debounce = const Duration(milliseconds: 150),
  });

  final PlaybackUpscaleBackend backend;
  final Future<List<String>> Function() loadShaders;
  final void Function() onChanged;
  final void Function(Object) onError;
  final Duration debounce;
  PlaybackUpscaleMode mode = PlaybackUpscaleMode.off;
  PlaybackFit fit = PlaybackFit.fit;
  PlaybackVideoSource? _source;
  PlaybackViewport? _viewport;
  String? renderer;
  PlaybackPixels? actualOutput;
  PlaybackUpscalePlan plan = const PlaybackUpscalePlan('已关闭');
  String? warning;
  bool _warned = false;
  bool _failed = false;
  bool _closed = false;
  bool _mediaReady = false;
  bool _dirty = false;
  bool _chainLoaded = false;
  bool _restorationFailed = false;
  bool _unsupported = false;
  String? _baselineDumbMode;
  List<String> _paths = [];
  int _generation = 0;
  PlaybackUpscalePlan? _applied;
  PlaybackUpscalePlan? _pending;
  bool _pendingReady = false;
  Future<void>? _flight;
  Future<void>? _resetWork;
  Future<void>? _closeFuture;
  Timer? _timer;
  Timer? _confirmation;
  final _forwardedErrors = <String>{};

  void preferences(PlaybackUpscaleMode value, PlaybackFit framing) {
    if (_closed || (mode == value && fit == framing)) return;
    mode = value;
    fit = framing;
    _schedule(immediate: true);
  }

  void source(PlaybackVideoSource? value) {
    if (_closed || !_mediaReady || _source == value) return;
    _source = value;
    // media_kit_video resets the texture when display parameters change. Its
    // cached fixed dimensions must be invalidated before applying the new plan.
    _applied = null;
    _schedule();
  }

  void viewport(PlaybackViewport? value) {
    if (_closed || _viewport == value) return;
    _viewport = value;
    _schedule();
  }

  void texture(PlaybackPixels? value) {
    if (_closed || actualOutput == value) return;
    actualOutput = value;
    if (value == _applied?.output) _confirmation?.cancel();
    onChanged();
  }

  void dismissWarning() {
    if (warning == null) return;
    warning = null;
    onChanged();
  }

  /// Called before stop/open. No old application can write after this returns.
  Future<void> resetMedia() =>
      _resetWork ??= _resetMedia().whenComplete(() => _resetWork = null);

  Future<void> _resetMedia() async {
    if (_closed) return;
    _mediaReady = false;
    _generation++;
    _timer?.cancel();
    _confirmation?.cancel();
    _pending = null;
    _pendingReady = false;
    await _flight;
    if (_closed) return;
    if (_dirty) await _restore();
    if (_closed) return;
    _source = null;
    _applied = null;
    actualOutput = null;
    _failed = false;
    _restorationFailed = false;
    _warned = false;
    warning = null;
    _forwardedErrors.clear();
    plan = const PlaybackUpscalePlan('等待视频参数');
    onChanged();
  }

  void mediaReady(PlaybackVideoSource? value) {
    if (_closed) return;
    _mediaReady = true;
    _source = value;
    _schedule(immediate: true);
  }

  void _schedule({bool immediate = false}) {
    if (_closed || !_mediaReady || _restorationFailed) return;
    var next = _failed && mode != PlaybackUpscaleMode.off
        ? const PlaybackUpscalePlan('暂不可用，已恢复普通播放')
        : _unsupported && mode != PlaybackUpscaleMode.off
        ? const PlaybackUpscalePlan('渲染器不支持所需 FBO')
        : playbackUpscalePlan(
            mode: mode,
            fit: fit,
            source: _source,
            viewport: _viewport,
            renderer: renderer,
            previouslyEnabled: _pending?.enabled ?? _applied?.enabled ?? false,
          );
    _pending = next;
    _pendingReady = immediate;
    _generation++;
    _timer?.cancel();
    _confirmation?.cancel();
    if (immediate) {
      _start();
    } else {
      _timer = Timer(debounce, () {
        _pendingReady = true;
        _start();
      });
    }
  }

  void _start() {
    if (_closed ||
        !_mediaReady ||
        _restorationFailed ||
        !_pendingReady ||
        _flight != null ||
        _pending == null) {
      return;
    }
    var work = _drain();
    _flight = work;
    unawaited(
      work.whenComplete(() {
        _flight = null;
        if (!_closed && _pending != null) _start();
      }),
    );
  }

  bool _current(int generation) =>
      !_closed && _mediaReady && generation == _generation;

  Future<void> _drain() async {
    while (!_closed && _mediaReady && _pendingReady && _pending != null) {
      var next = _pending!;
      _pending = null;
      var generation = _generation;
      if (next == _applied) {
        plan = next;
        onChanged();
        _watchOutput(generation, next);
        continue;
      }
      try {
        if (!next.enabled) {
          if (_dirty) await _restore();
          if (!_current(generation)) continue;
        } else {
          if (_baselineDumbMode == null) {
            var baseline = await backend.read('gpu-dumb-mode');
            if (!_current(generation)) continue;
            if (baseline is! String ||
                !['yes', 'no', 'auto'].contains(baseline)) {
              throw StateError('无法确认渲染器的普通播放配置');
            }
            var original = await backend.read('glsl-shaders');
            if (!_current(generation)) continue;
            if (original is! List || original.isNotEmpty) {
              throw StateError('当前渲染器已有其他着色器');
            }
            _baselineDumbMode = baseline;
          }
          if (!_chainLoaded) {
            var shaders = await loadShaders();
            if (!_current(generation)) continue;
            _paths = shaders;
            _dirty = true;
            await backend.command(['set', 'gpu-dumb-mode', 'no']);
            if (!_current(generation)) continue;
            await backend.command(['change-list', 'glsl-shaders', 'clr', '']);
            if (!_current(generation)) continue;
            for (var shader in shaders) {
              await backend.command([
                'change-list',
                'glsl-shaders',
                'append',
                shader,
              ]);
              if (!_current(generation)) break;
            }
            if (!_current(generation)) continue;
            var configured = await backend.read('glsl-shaders');
            if (!_current(generation)) continue;
            if (configured is! List ||
                configured.length != shaders.length ||
                [
                  for (var i = 0; i < shaders.length; i++)
                    configured[i] != shaders[i],
                ].any((different) => different)) {
              throw StateError('着色器链路读回与已验证清单不一致');
            }
            _chainLoaded = true;
          }
          // Clear cached fixed dimensions even when a new source happens to
          // calculate the same output as the previous source.
          await backend.resize(null);
          if (!_current(generation)) continue;
          await backend.resize(next.output);
          if (!_current(generation)) continue;
          await backend.redraw();
          if (!_current(generation)) continue;
        }
        _applied = next;
        plan = next;
        if (_failed && mode != PlaybackUpscaleMode.off) {
          _showFailure();
        } else {
          onChanged();
        }
        _watchOutput(generation, next);
      } catch (error) {
        onError(error);
        if (_closed) return;
        _failed = true;
        try {
          if (_dirty) await _restore();
        } catch (restorationError) {
          _restorationFailed = true;
          onError(restorationError);
        }
        // A newer layout request cannot retry a failed chain in this file.
        // Media reset, unlike layout changes, deliberately clears this latch.
        _pending = null;
        _timer?.cancel();
        _confirmation?.cancel();
        if (_mediaReady) _showFailure();
      }
    }
  }

  Future<void> _restore() async {
    // Try every part of recovery even when clearing the shader list fails.
    Object? failure;
    for (var action in <Future<void> Function()>[
      () => backend.command(['change-list', 'glsl-shaders', 'clr', '']),
      () => backend.resize(null),
      if (_baselineDumbMode != null)
        () => backend.command(['set', 'gpu-dumb-mode', _baselineDumbMode!]),
      backend.redraw,
    ]) {
      try {
        await action();
      } catch (error) {
        failure ??= error;
      }
    }
    _chainLoaded = false;
    _applied = null;
    if (failure != null) throw failure;
    _dirty = false;
  }

  void _watchOutput(int generation, PlaybackUpscalePlan next) {
    if (!next.enabled || actualOutput == next.output) return;
    _confirmation = Timer(const Duration(seconds: 3), () {
      if (!_current(generation) || actualOutput == next.output) return;
      _failed = true;
      onError(StateError('超分纹理尺寸未能确认'));
      _schedule(immediate: true);
    });
  }

  void _showFailure() {
    plan = PlaybackUpscalePlan(
      _restorationFailed ? '普通播放恢复失败，请重新打开播放器' : '暂不可用，已恢复普通播放',
    );
    if (!_warned) {
      _warned = true;
      warning = _restorationFailed ? '超分清理失败，请关闭并重新打开播放器' : '超分暂不可用，已恢复普通播放';
    }
    onChanged();
  }

  /// Log evidence is scoped to this Player and an installed/applying chain.
  /// Only the exact same forwarded file error is consumed by stream.error.
  void log(String prefix, String level, String text) {
    if (_closed) return;
    var renderLog = prefix.startsWith('vo/') || prefix.startsWith('libmpv');
    var lower = text.toLowerCase();
    var unsupported =
        renderLog && lower.contains('high bit depth fbos unsupported');
    if (unsupported) {
      _unsupported = true;
      _schedule();
    }
    var glRenderer = _rendererPattern.firstMatch(text);
    if (glRenderer != null && renderer != glRenderer.group(1)) {
      renderer = glRenderer.group(1);
      _schedule();
    }
    if (!_mediaReady || !_dirty || _failed) return;
    var shaderFileError =
        prefix == 'file' &&
        level == 'error' &&
        _paths.any((shader) => text.contains(shader));
    var shaderError =
        renderLog &&
        (level == 'error' || level == 'fatal') &&
        (lower.contains('shader') ||
            lower.contains('glsl') ||
            lower.contains('framebuffer'));
    if (!shaderFileError && !shaderError && !unsupported) return;
    if (shaderFileError) _forwardedErrors.add(text.trim());
    _failed = true;
    onError(StateError(text.trim()));
    _schedule(immediate: true);
  }

  bool consumesError(String text) => _forwardedErrors.remove(text.trim());

  /// Closing does not initiate another compile/redraw. Wait for all accepted
  /// commands before closing the adapter and letting Store dispose the Player.
  Future<void> close() => _closeFuture ??= () async {
    _closed = true;
    _generation++;
    _pending = null;
    _timer?.cancel();
    _confirmation?.cancel();
    await _flight;
    await _resetWork;
    backend.close();
  }();
}
