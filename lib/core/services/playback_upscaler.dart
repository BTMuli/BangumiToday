// Dart imports:
import 'dart:async';

// Project imports:
import '../../models/playback/playback_frame_drop_monitor.dart';
import '../../models/playback/playback_janai_status.dart';
import '../../models/playback/playback_upscale.dart';

abstract class PlaybackUpscaleBackend {
  /// Explicit mpv label used to address this Player's inference filter.
  static const janaiFilterLabel = 'bt-janai';

  Future<void> command(List<String> arguments);
  Future<Object?> read(String property);
  Future<void> shaders(List<String> paths);

  /// Installs or clears the AnimeJaNai filter chain. `slot` selects the model
  /// (1 smooth, 2 high quality); null clears the chain. All modes share the
  /// decoder configured at Player creation.
  Future<void> janai(int? slot);
  Future<PlaybackJanaiStatus?> janaiStatus();

  /// The installed video filter entries as mpv reports them: one map per filter
  /// with at least `name`, plus `enabled` and `params` when mpv provides them.
  /// Verification reads this structure rather than a serialized string, so a
  /// value that merely contains the filter name cannot pass the check.
  Future<List<Map<Object?, Object?>>> filterList();

  /// Rendering options and texture resizing redraw through libmpv's update
  /// callback. Filter changes refresh paused frames in mpv itself; an extra
  /// seek here would redundantly reset decoding and could move the picture.
  Future<void> resize(PlaybackPixels? size);
  void close();
}

/// One coordinator per Player. Layout events replace a single pending plan;
/// they never join the Store's media-operation queue.
class PlaybackUpscaler {
  static final _rendererPattern = RegExp("GL_RENDERER='([^']+)'");
  static const _nativeFrameBudgetFailure =
      'AnimeJaNai exceeded the frame budget for three windows';
  PlaybackUpscaler({
    required this.backend,
    required this.loadShaders,
    required this.onChanged,
    required this.onError,
    this.onDiagnostics,
    this.debounce = const Duration(milliseconds: 150),
    this.viewportGrace = const Duration(seconds: 1),
  });

  final PlaybackUpscaleBackend backend;
  final Future<List<String>> Function(PlaybackUpscaleMode) loadShaders;
  final void Function() onChanged;
  final void Function(Object) onError;
  final void Function(String)? onDiagnostics;
  final Duration debounce;
  final Duration viewportGrace;
  PlaybackUpscaleMode mode = PlaybackUpscaleMode.off;
  PlaybackVideoSource? _source;
  PlaybackViewport? _viewport;
  String? renderer;
  PlaybackPixels? actualOutput;
  PlaybackUpscalePlan plan = const PlaybackUpscalePlan('已关闭');
  String? warning;
  PlaybackJanaiStatus? janaiStatus;
  bool _warned = false;
  bool _failed = false;
  bool _closed = false;
  bool _mediaReady = false;
  bool _dirty = false;
  bool _janaiDirty = false;
  PlaybackUpscaleMode? _loadedMode;
  PlaybackUpscaleMode? get configuredMode => _loadedMode;
  bool _restorationFailed = false;
  bool _unsupported = false;

  /// Reason of the last failed apply, surfaced so a failure can be diagnosed
  /// from the playback UI instead of only from the log.
  Object? _lastFailure;
  String? _baselineDumbMode;
  bool _resizeInvalidated = false;
  PlaybackPixels? _fixedOutput;
  PlaybackPixels? _retainedOutputSource;
  List<String> _paths = [];
  int _generation = 0;
  PlaybackUpscalePlan? _applied;
  PlaybackUpscalePlan? _applying;
  PlaybackUpscalePlan? _pending;
  bool _pendingReady = false;
  Future<void>? _flight;
  Future<void>? _resetWork;
  Future<void>? _closeFuture;
  Timer? _timer;
  Timer? _confirmation;
  Timer? _viewportRelease;
  Timer? _outputDeadline;
  Timer? _dropTimer;
  bool _readingDrops = false;
  final _dropMonitor = PlaybackFrameDropMonitor();
  final _dropClock = Stopwatch()..start();
  double? _performanceFailureRate;
  int _dropEpoch = 0;
  Completer<bool>? _outputReady;
  PlaybackPixels? _awaitingOutput;
  final _forwardedErrors = <String>{};

  String _pixels(PlaybackPixels? value) =>
      value == null ? 'none' : '${value.width}x${value.height}';

  void _trace(String message, {int? generation}) {
    // Diagnostic sinks must never change playback or recovery behavior.
    try {
      onDiagnostics?.call(
        '超分 generation=${generation ?? _generation} $message',
      );
    } catch (_) {}
  }

  Future<T> _step<T>(
    String name,
    Future<T> Function() action, {
    int? generation,
  }) async {
    var clock = Stopwatch();
    _trace('step=$name begin', generation: generation);
    clock.start();
    try {
      var result = await action();
      _trace(
        'step=$name completed elapsed_ms=${clock.elapsedMilliseconds}',
        generation: generation,
      );
      return result;
    } catch (error) {
      _trace(
        'step=$name failed elapsed_ms=${clock.elapsedMilliseconds} '
        'error=$error',
        generation: generation,
      );
      rethrow;
    }
  }

  void preferences(PlaybackUpscaleMode value) {
    if (_closed || mode == value) return;
    _trace('preferences old_mode=${mode.name} new_mode=${value.name}');
    // A deliberate quality change may retry after a recovered shader failure.
    // Layout changes never retry, and failed restoration still blocks work.
    if (mode != value && !_restorationFailed) {
      _failed = false;
      _warned = false;
      _lastFailure = null;
      _performanceFailureRate = null;
      warning = null;
    }
    mode = value;
    _schedule(immediate: true);
  }

  void inferencePreferenceChanged() {
    if (_closed) return;
    _stopDropMonitor();
    _loadedMode = null;
    _applied = null;
    janaiStatus = null;
    if (!_restorationFailed) {
      _failed = _warned = false;
      warning = null;
      _lastFailure = null;
      _performanceFailureRate = null;
    }
    _schedule(immediate: true, invalidate: true);
  }

  void playbackRate(double value) {
    if (_closed || !_dropMonitor.speed(value, _dropClock.elapsed)) return;
    _dropEpoch++;
    _trace('playback rate=$value reset_drop_windows');
    var failedRate = _performanceFailureRate;
    if (failedRate == null || value >= failedRate || _restorationFailed) return;
    // Retry only a performance fallback after reducing demand. Model, device
    // and restoration failures still require an explicit retry.
    _performanceFailureRate = null;
    _failed = _warned = false;
    _lastFailure = null;
    warning = null;
    _schedule(immediate: true, invalidate: true);
  }

  void source(PlaybackVideoSource? value) {
    if (_closed || !_mediaReady || _source == value) return;
    var dimensionsChanged =
        _validateRetainedOutput(value) ??
        (_source?.width != value?.width || _source?.height != value?.height);
    _source = value;
    // media_kit_video resets the texture when display parameters change. Its
    // cached fixed dimensions must be invalidated before applying the new plan.
    if (dimensionsChanged) {
      _resizeInvalidated = true;
      _applied = null;
    }
    _schedule(invalidate: dimensionsChanged);
  }

  void viewport(PlaybackViewport? value) {
    if (_closed) return;
    if (value == null && _viewportRelease != null) return;
    _viewportRelease?.cancel();
    _viewportRelease = null;
    if (value == null && _viewport != null && _mediaReady) {
      // Fullscreen/routes can temporarily detach both reporters. Keep the
      // installed chain through that handoff instead of recompiling it.
      _viewportRelease = Timer(viewportGrace, () {
        _viewportRelease = null;
        _viewport = null;
        _schedule();
      });
      return;
    }
    if (_viewport == value) return;
    _viewport = value;
    _schedule();
  }

  void texture(PlaybackPixels? value) {
    if (_closed || actualOutput == value) return;
    _trace(
      'output observed old=${_pixels(actualOutput)} new=${_pixels(value)} '
      'expected=${_pixels(_applied?.output ?? _applying?.output)}',
    );
    actualOutput = value;
    if (value != null && value == _awaitingOutput) {
      _cancelOutputWait(ready: true);
    }
    if (value == _applied?.output) _confirmation?.cancel();
    onChanged();
  }

  void dismissWarning() {
    if (warning == null) return;
    warning = null;
    onChanged();
  }

  /// Called before stop/open. No old application can write after this returns.
  /// Episode switches can retain a confirmed Anime4K output while clearing the
  /// old shaders, keeping new SDR frames on the same mpv scaling path.
  Future<void> resetMedia({bool keepOutput = false}) => _resetWork ??=
      _resetMedia(keepOutput: keepOutput).whenComplete(() => _resetWork = null);

  Future<void> _resetMedia({required bool keepOutput}) async {
    if (_closed) return;
    _mediaReady = false;
    _stopDropMonitor();
    _generation++;
    _timer?.cancel();
    _confirmation?.cancel();
    if (_viewportRelease != null) _viewport = null;
    _viewportRelease?.cancel();
    _viewportRelease = null;
    _cancelOutputWait();
    _pending = null;
    _pendingReady = false;
    await _flight;
    if (_closed) return;
    var retainOutput =
        keepOutput &&
        !_failed &&
        !_restorationFailed &&
        mode != PlaybackUpscaleMode.off &&
        !mode.isJanai &&
        _loadedMode == mode &&
        _source != null &&
        _fixedOutput != null &&
        actualOutput == _fixedOutput;
    var retainedSource = retainOutput
        ? (width: _source!.width, height: _source!.height)
        : null;
    _trace(
      'media reset retain_output=$retainOutput '
      'output=${_pixels(_fixedOutput)} source=${_pixels(retainedSource)}',
    );
    if (_dirty) await _restore(keepOutput: retainOutput);
    if (_closed) return;
    _retainedOutputSource = retainedSource;
    _source = null;
    _applied = null;
    _resizeInvalidated = false;
    if (!retainOutput) actualOutput = null;
    _failed = false;
    _performanceFailureRate = null;
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
    _resizeInvalidated = _validateRetainedOutput(value) ?? false;
    _source = value;
    _schedule(immediate: true);
  }

  bool? _validateRetainedOutput(PlaybackVideoSource? source) {
    var previous = _retainedOutputSource;
    if (previous == null || source == null) return null;
    _retainedOutputSource = null;
    return previous.width != source.width || previous.height != source.height;
  }

  void _schedule({bool immediate = false, bool invalidate = false}) {
    if (_closed || !_mediaReady || _restorationFailed) return;
    var next = _failed && mode != PlaybackUpscaleMode.off
        ? const PlaybackUpscalePlan('暂不可用，已恢复普通播放')
        : _unsupported && mode != PlaybackUpscaleMode.off
        ? const PlaybackUpscalePlan('渲染器不支持所需 FBO')
        : playbackUpscalePlan(
            mode: mode,
            source: _source,
            viewport: _viewport,
            renderer: renderer,
            previouslyEnabled: _pending?.enabled ?? _applied?.enabled ?? false,
          );
    // Equivalent layouts must not cancel an in-flight application or its
    // output confirmation, nor notify/rebuild the playback page again.
    if (!invalidate &&
        (next == _pending ||
            (next == _applying && _pending == null) ||
            (next == _applied &&
                _pending == null &&
                _flight == null &&
                !_resizeInvalidated))) {
      return;
    }
    _pending = next;
    _pendingReady = immediate;
    _generation++;
    _timer?.cancel();
    _confirmation?.cancel();
    _cancelOutputWait();
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
        _applying = null;
        if (!_closed && _pending != null) _start();
      }),
    );
  }

  bool _current(int generation) =>
      !_closed && _mediaReady && generation == _generation;

  void _cancelOutputWait({bool ready = false}) {
    _outputDeadline?.cancel();
    _outputDeadline = null;
    _awaitingOutput = null;
    var pending = _outputReady;
    _outputReady = null;
    pending?.complete(ready);
  }

  Future<bool> _waitForOutput(PlaybackPixels output) {
    if (actualOutput == output) return Future.value(true);
    _cancelOutputWait();
    var ready = _outputReady = Completer<bool>();
    _awaitingOutput = output;
    _trace('waiting_for_output=${_pixels(output)} before_shader_install');
    _outputDeadline = Timer(const Duration(seconds: 3), _cancelOutputWait);
    return ready.future;
  }

  Future<bool> _resizeOutput(PlaybackUpscalePlan next, int generation) async {
    // Only source-size changes invalidate media_kit's fixed-size cache.
    if (_resizeInvalidated) {
      _applied = null;
      await _step(
        'invalidate_output',
        () => backend.resize(null),
        generation: generation,
      );
      _fixedOutput = null;
      if (!_current(generation)) return false;
    }
    if (_fixedOutput != next.output) {
      _applied = null;
      await _step(
        'resize:${_pixels(next.output)}',
        () => backend.resize(next.output),
        generation: generation,
      );
      _fixedOutput = next.output;
      if (!_current(generation)) return false;
    }
    _resizeInvalidated = false;
    return true;
  }

  Future<void> _drain() async {
    while (!_closed && _mediaReady && _pendingReady && _pending != null) {
      var next = _pending!;
      _pending = null;
      _applying = next;
      var generation = _generation;
      if (next == _applied) {
        plan = next;
        onChanged();
        _watchOutput(generation, next);
        continue;
      }
      var clock = Stopwatch()..start();
      _trace(
        'apply begin configured=${_loadedMode?.name ?? 'none'} '
        'mode=${next.mode.name} enabled=${next.enabled} reason=${next.reason} '
        'old_output=${_pixels(_fixedOutput)} '
        'new_output=${_pixels(next.output)} '
        'actual=${_pixels(actualOutput)} source=$_source viewport=$_viewport '
        'resize_invalidated=$_resizeInvalidated',
        generation: generation,
      );
      var outcome = 'superseded';
      try {
        if (!next.enabled) {
          // open() may return before the first video-params event. The old
          // shaders are already cleared; keep its output until new parameters
          // can confirm the plan, rather than briefly restoring source size.
          if (_retainedOutputSource != null &&
              _source == null &&
              !_failed &&
              !_unsupported &&
              mode != PlaybackUpscaleMode.off &&
              !mode.isJanai) {
            plan = next;
            outcome = 'waiting_source';
            onChanged();
            continue;
          }
          if (_dirty) await _restore(generation: generation);
          if (!_current(generation)) continue;
        } else if (next.mode.isJanai) {
          // The filter produces fixed 2x frames. media_kit_video observes the
          // decoder's video-params, so explicitly request the planned viewport
          // texture size and let mpv scale the filtered frame to that target.
          if (_dirty && !(_loadedMode?.isJanai ?? false)) {
            await _restore(generation: generation);
          }
          if (!_current(generation)) continue;
          _dirty = true;
          if (_loadedMode != next.mode) {
            _stopDropMonitor();
            _janaiDirty = true;
            _loadedMode = null;
            _applied = null;
            await _step(
              'install_janai:${next.mode.name}',
              () => backend.janai(next.mode.janaiSlot),
              generation: generation,
            );
            if (!_current(generation)) continue;
            // Verification inspects mpv's structured filter list: an entry has
            // to be the AnimeJaNai filter, be enabled, and name the requested
            // model slot when mpv reports the parameters.
            var filters = await _step(
              'verify_vf',
              backend.filterList,
              generation: generation,
            );
            if (!_current(generation)) continue;
            var expectedSlot = next.mode.janaiSlot;
            var installed = filters.any((entry) {
              if (entry['name'] != 'animejanai') return false;
              if (entry['label'] != PlaybackUpscaleBackend.janaiFilterLabel) {
                return false;
              }
              if (entry['enabled'] != true) return false;
              var params = entry['params'];
              return expectedSlot != null &&
                  params is Map &&
                  params['slot'].toString() == expectedSlot.toString() &&
                  params['conf'] is String &&
                  (params['conf'] as String).isNotEmpty;
            });
            if (!installed) {
              throw StateError('AI 滤镜未生效：$filters');
            }
            _loadedMode = next.mode;
          }
          if (!await _resizeOutput(next, generation)) continue;
        } else {
          // Leaving an AnimeJaNai mode has to clear its filter chain; otherwise
          // the shader preset would stack on top of the AI upscaler.
          if (_janaiDirty) {
            await _step(
              'clear_janai',
              () => backend.janai(null),
              generation: generation,
            );
            _janaiDirty = false;
            if (!_current(generation)) continue;
            _loadedMode = null;
          }
          if (_baselineDumbMode == null) {
            var baseline = await _step(
              'read_gpu_dumb_mode',
              () => backend.read('gpu-dumb-mode'),
              generation: generation,
            );
            if (!_current(generation)) continue;
            if (baseline is! String ||
                !['yes', 'no', 'auto'].contains(baseline)) {
              throw StateError('无法确认渲染器的普通播放配置');
            }
            var original = await _step(
              'read_original_shaders',
              () => backend.read('glsl-shaders'),
              generation: generation,
            );
            if (!_current(generation)) continue;
            if (original is! List || original.isNotEmpty) {
              throw StateError('当前渲染器已有其他着色器');
            }
            _baselineDumbMode = baseline;
          }
          List<String>? shaders;
          if (_loadedMode != next.mode) {
            var loaded = await _step(
              'load_shaders:${next.mode.name}',
              () => loadShaders(next.mode),
              generation: generation,
            );
            if (!_current(generation)) continue;
            shaders = loaded;
            _paths = loaded;
          }
          _dirty = true;
          if (!await _resizeOutput(next, generation)) continue;
          var selectedShaders = shaders;
          if (selectedShaders != null) {
            // Installing first compiles the chain at the old dimensions and
            // again after resize. SetSize acceptance is asynchronous: wait
            // for its first published frame, including during paused playback.
            var ready = await _waitForOutput(next.output!);
            if (!_current(generation)) continue;
            if (!ready) throw StateError('超分安装前未能确认目标纹理尺寸');
            // Invalidate before mutating. A superseded partial chain must be
            // reloaded even if the latest preference returns to the old mode.
            _loadedMode = null;
            _applied = null;
            await _step(
              'gpu_dumb_mode:no',
              () => backend.command(['set', 'gpu-dumb-mode', 'no']),
              generation: generation,
            );
            if (!_current(generation)) continue;
            _trace('shader_chain=$selectedShaders', generation: generation);
            await _step(
              'install_shaders',
              () => backend.shaders(selectedShaders),
              generation: generation,
            );
            if (!_current(generation)) continue;
            var configured = await _step(
              'verify_shaders',
              () => backend.read('glsl-shaders'),
              generation: generation,
            );
            if (!_current(generation)) continue;
            if (configured is! List ||
                configured.length != selectedShaders.length ||
                [
                  for (var i = 0; i < selectedShaders.length; i++)
                    configured[i] != selectedShaders[i],
                ].any((different) => different)) {
              throw StateError('着色器链路读回与已验证清单不一致');
            }
            _loadedMode = next.mode;
          }
        }
        _applied = next;
        outcome = 'configured';
        plan = next;
        if (_failed && mode != PlaybackUpscaleMode.off) {
          _showFailure();
        } else {
          onChanged();
        }
        _watchOutput(generation, next);
      } catch (error) {
        outcome = 'failed';
        _lastFailure = error;
        onError(error);
        if (_closed) return;
        _failed = true;
        try {
          if (_dirty) await _restore(generation: generation);
        } catch (restorationError) {
          _restorationFailed = true;
          onError(restorationError);
        }
        // A newer layout request cannot retry a failed chain in this file.
        // Media reset or a deliberate quality change clears this latch.
        _pending = null;
        _timer?.cancel();
        _confirmation?.cancel();
        _cancelOutputWait();
        if (_mediaReady) _showFailure();
      } finally {
        _trace(
          'apply end outcome=$outcome elapsed_ms=${clock.elapsedMilliseconds} '
          'current_generation=$_generation configured=${_loadedMode?.name} '
          'actual=${_pixels(actualOutput)} target=${_pixels(next.output)}',
          generation: generation,
        );
      }
    }
  }

  Future<void> _restore({int? generation, bool keepOutput = false}) async {
    _stopDropMonitor();
    var operation = generation ?? _generation;
    // Try every part of recovery even when clearing the shader list fails.
    Object? failure;
    for (var action in <Future<void> Function()>[
      () => _step(
        'restore_shaders',
        () => backend.shaders(const []),
        generation: operation,
      ),
      if (_janaiDirty)
        () async {
          await _step(
            'restore_janai',
            () => backend.janai(null),
            generation: operation,
          );
          _janaiDirty = false;
        },
      if (!keepOutput)
        () async {
          await _step(
            'restore_output',
            () => backend.resize(null),
            generation: operation,
          );
          _fixedOutput = null;
          _retainedOutputSource = null;
          _resizeInvalidated = false;
        },
      if (!keepOutput && _baselineDumbMode != null)
        () => _step(
          'restore_gpu_dumb_mode:$_baselineDumbMode',
          () => backend.command(['set', 'gpu-dumb-mode', _baselineDumbMode!]),
          generation: operation,
        ),
    ]) {
      try {
        await action();
      } catch (error) {
        failure ??= error;
      }
    }
    _loadedMode = null;
    _applied = null;
    if (failure != null) throw failure;
    // Retained output and gpu-dumb-mode still need full recovery on stop,
    // disabled/unsupported media, a preference change, or a failed apply.
    _dirty = keepOutput;
  }

  void _watchOutput(int generation, PlaybackUpscalePlan next) {
    if (next.enabled && next.mode.isJanai) {
      _dropTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_checkDrops());
      });
    }
    if (!next.enabled || actualOutput == next.output) return;
    _trace(
      'output confirmation pending actual=${_pixels(actualOutput)} '
      'expected=${_pixels(next.output)} timeout_ms=3000',
      generation: generation,
    );
    _confirmation = Timer(const Duration(seconds: 3), () {
      if (!_current(generation) || actualOutput == next.output) return;
      _trace(
        'output confirmation timed_out actual=${_pixels(actualOutput)} '
        'expected=${_pixels(next.output)}',
        generation: generation,
      );
      _failed = true;
      _lastFailure = StateError('超分纹理尺寸未能确认');
      onError(_lastFailure!);
      _schedule(immediate: true);
    });
  }

  void _showFailure() {
    plan = PlaybackUpscalePlan(
      _restorationFailed ? '普通播放恢复失败，请重新打开播放器' : '暂不可用，已恢复普通播放',
    );
    if (!_warned) {
      _warned = true;
      var reason = _lastFailure?.toString() ?? '';
      if (reason.length > 80) reason = '${reason.substring(0, 80)}…';
      warning = _restorationFailed
          ? '超分清理失败，请关闭并重新打开播放器'
          : reason.isEmpty
          ? '超分暂不可用，已恢复普通播放'
          : '超分暂不可用：$reason';
    }
    onChanged();
  }

  void _stopDropMonitor() {
    janaiStatus = null;
    _dropTimer?.cancel();
    _dropTimer = null;
    _dropMonitor.reset();
    _dropEpoch++;
  }

  Future<void> _checkDrops() async {
    if (_readingDrops ||
        _closed ||
        !_mediaReady ||
        _failed ||
        !(_loadedMode?.isJanai ?? false)) {
      return;
    }
    _readingDrops = true;
    var epoch = _dropEpoch;
    try {
      var status = await backend.janaiStatus();
      if (_closed || epoch != _dropEpoch || _failed) return;
      if (status?.preparing == true) {
        // Paused playback has no filter process() calls. Reading the snapshot
        // alone cannot publish build progress or activate a finished engine;
        // the pinned filter's poll command wakes that work without resuming.
        await backend.command([
          'vf-command',
          PlaybackUpscaleBackend.janaiFilterLabel,
          'poll',
          '',
        ]);
        if (_closed || epoch != _dropEpoch || _failed) return;
        status = await backend.janaiStatus();
        if (_closed || epoch != _dropEpoch || _failed) return;
      }
      janaiStatus = status;
      onChanged();
      if (status != null &&
          (status.phase == 'failed' ||
              (status.active && status.backend != 'tensorrt'))) {
        if (status.reason == _nativeFrameBudgetFailure) {
          _performanceFailureRate = _dropMonitor.rate;
        }
        _lastFailure = StateError(
          status.phase == 'failed' && status.reason.isNotEmpty
              ? status.reason
              : 'AI 实时超分需要 NVIDIA 显卡和已配置的 TensorRT',
        );
        _failed = true;
        onError(_lastFailure!);
        _schedule(immediate: true);
        return;
      }
      if (status?.active == false || status == null) {
        // Preparing/passthrough playback has no inference frame budget.
        _dropMonitor.reset();
        return;
      }
      var values = await Future.wait([
        backend.read('frame-drop-count'),
        backend.read('estimated-frame-number'),
        backend.read('time-pos'),
        backend.read('pause'),
        backend.read('seeking'),
      ]);
      if (_closed || epoch != _dropEpoch || _failed) return;
      var dropped = values[0];
      var frame = values[1];
      var position = values[2];
      if (dropped is! num ||
          frame is! num ||
          position is! num ||
          values[3] != false ||
          values[4] != false) {
        _dropMonitor.reset();
        return;
      }
      if (!_dropMonitor.observe(
        dropped: dropped,
        frame: frame,
        position: position,
        elapsed: _dropClock.elapsed,
      )) {
        return;
      }
      _lastFailure = StateError('AI 超分连续三个窗口的播放丢帧率超过 1%');
      _performanceFailureRate = _dropMonitor.rate;
      _failed = true;
      onError(_lastFailure!);
      _schedule(immediate: true);
    } catch (error) {
      if (epoch != _dropEpoch || _closed) return;
      _dropMonitor.reset();
      _trace('drop_monitor unavailable error=$error');
    } finally {
      _readingDrops = false;
    }
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
    var janaiError =
        _janaiDirty &&
        prefix.contains('animejanai') &&
        (level == 'error' || level == 'fatal');
    if (!shaderFileError && !shaderError && !unsupported && !janaiError) return;
    if (shaderFileError) _forwardedErrors.add(text.trim());
    if (janaiError && text.contains(_nativeFrameBudgetFailure)) {
      _performanceFailureRate = _dropMonitor.rate;
    }
    _failed = true;
    _lastFailure = StateError(text.trim());
    onError(_lastFailure!);
    _schedule(immediate: true);
  }

  bool consumesError(String text) => _forwardedErrors.remove(text.trim());

  /// Closing does not initiate another compile/redraw. Wait for all accepted
  /// commands before closing the adapter and letting Store dispose the Player.
  Future<void> close() => _closeFuture ??= () async {
    _closed = true;
    _stopDropMonitor();
    _generation++;
    _pending = null;
    _timer?.cancel();
    _confirmation?.cancel();
    _viewportRelease?.cancel();
    _cancelOutputWait();
    await _flight;
    await _resetWork;
    backend.close();
  }();
}
