// Dart imports:
import 'dart:async';
import 'dart:io';
import 'dart:ui';

// Package imports:
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// Project imports:
import '../../models/playback/playback_completion.dart';
import '../../models/playback/playback_geometry.dart';
import '../../models/playback/playback_hires.dart';
import '../../models/playback/playback_item.dart';
import '../../models/playback/playback_upscale.dart';
import '../logging/log_tool.dart';
import 'native_playback_upscale_backend.dart';
import 'playback_audio.dart';
import 'playback_audio_controller.dart';
import 'playback_cache.dart';
import 'playback_chapters.dart';
import 'playback_diagnostics.dart';
import 'playback_janai_video_source.dart';
import 'playback_loudness.dart';
import 'playback_subtitles.dart';
import 'playback_upscale_controller.dart';
import 'playback_upscaler.dart';

/// Snapshot of Store-owned playback session fields the native player needs.
typedef PlaybackMpvSession = ({
  String id,
  PlaybackItem? current,
  bool completed,
  bool loading,
  bool clearingPlayback,
  bool manualSubtitles,
  Duration position,
  Duration duration,
  List<PlaybackItem> playlist,
  int index,
});

/// Owns native Player creation, stream wiring, idle release and disposal.
/// Playlist/session orchestration stays with the Store.
class PlaybackMpvCoordinator {
  PlaybackMpvCoordinator({
    required this.playerAllowed,
    required this.waitForNativeDestroy,
    required this.readSession,
    required this.isClosed,
    required this.isOpening,
    required this.serial,
    required this.trackNativeDisposal,
    required this.onChanged,
    required this.audio,
    required this.upscale,
    required this.saveProgress,
    required this.refreshHistory,
    required this.openIndex,
    required this.autoSelectSubtitle,
    required this.finishSession,
    required this.writeHistory,
    required this.emitCompletion,
    required this.nextEpisodeIndex,
    required this.writePosition,
    required this.writeDuration,
    required this.writeCompleted,
    required this.writeError,
    required this.readLoudnessActive,
    required this.readHiRes,
    required this.readAspectRatio,
    required this.readVideoSize,
    required this.writeGeometry,
    required this.onPlayerReleased,
  });

  final bool playerAllowed;
  final bool waitForNativeDestroy;
  final PlaybackMpvSession Function() readSession;
  final bool Function() isClosed;
  final bool Function() isOpening;
  final Future<void> Function(Future<void> Function()) serial;
  final void Function(
    Future<void> disposal, {
    required bool waitForNativeDestroy,
  })
  trackNativeDisposal;
  final void Function() onChanged;
  final PlaybackAudioController audio;
  final PlaybackUpscaleController upscale;
  final Future<void> Function({bool refreshHistory}) saveProgress;
  final Future<void> Function() refreshHistory;
  final Future<void> Function(int index) openIndex;
  final Future<void> Function() autoSelectSubtitle;
  final PlaybackCompletion? Function({
    required Duration position,
    required Duration duration,
  })
  finishSession;
  final Future<void> Function(PlaybackItem item) writeHistory;
  final void Function(PlaybackCompletion completion) emitCompletion;
  final Future<int?> Function(List<PlaybackItem> items, int index)
  nextEpisodeIndex;
  final void Function(Duration value) writePosition;
  final void Function(Duration value) writeDuration;
  final void Function(bool value) writeCompleted;
  final void Function(String value) writeError;
  final bool Function() readLoudnessActive;
  final PlaybackHiResState Function() readHiRes;
  final double? Function() readAspectRatio;
  final Size? Function() readVideoSize;
  final void Function(double? ratio, Size? size) writeGeometry;
  final void Function() onPlayerReleased;

  Player? player;
  VideoController? video;
  PlaybackUpscaler? upscaler;
  PlaybackDiagnostics? diagnostics;
  PlaybackJanaiVideoSource? janaiVideoSource;
  PlaybackChapters? chapters;
  void Function()? _textureListener;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _saveTimer;
  Timer? _idlePlayerTimer;

  // A paused or completed file still owns its Player. Only unloaded media can
  // release the native render context without interrupting a viewing session.
  bool get _canReleaseIdlePlayer {
    var session = readSession();
    return !isClosed() &&
        player != null &&
        session.current == null &&
        player!.state.playlist.medias.isEmpty &&
        !session.loading &&
        !isOpening() &&
        !session.clearingPlayback;
  }

  void cancelIdleTimer() {
    _idlePlayerTimer?.cancel();
    _idlePlayerTimer = null;
  }

  void syncIdleTimer() {
    if (!_canReleaseIdlePlayer) {
      cancelIdleTimer();
      return;
    }
    // Settings and history operations must not extend the idle deadline.
    if (_idlePlayerTimer != null) return;
    late Timer timer;
    timer = _idlePlayerTimer = Timer(const Duration(hours: 2), () {
      unawaited(
        serial(() async {
          // An open may have cancelled this timeout while it was queued.
          if (!identical(_idlePlayerTimer, timer) || !_canReleaseIdlePlayer) {
            return;
          }
          _idlePlayerTimer = null;
          await _releaseIdlePlayer();
        }).catchError((Object _) {}),
      );
    });
  }

  Future<void> _releaseIdlePlayer() async {
    var releasing = player!;
    var upscaleInstance = upscaler;
    var textureListener = _textureListener;
    if (textureListener != null) video?.rect.removeListener(textureListener);
    _textureListener = null;
    // Detach synchronously so shutdown cannot take ownership of this Player
    // while listener cancellation or native disposal is still pending.
    player = null;
    video = null;
    upscaler = null;
    diagnostics?.close();
    diagnostics = null;
    janaiVideoSource?.close();
    janaiVideoSource = null;
    chapters?.close();
    chapters = null;
    _saveTimer?.cancel();
    _saveTimer = null;
    audio.releasePlayer();
    onPlayerReleased();
    var subscriptions = List<StreamSubscription<dynamic>>.of(_subscriptions);
    _subscriptions.clear();
    BTLogTool.info('未加载文件已满 2 小时，释放原生播放器');
    onChanged();
    await Future.wait(
      subscriptions.map((subscription) => subscription.cancel()),
    );
    await disposePlayer(releasing, upscale: upscaleInstance);
  }

  Future<void> initialize() async {
    if (player != null) return;
    if (!playerAllowed) throw StateError('主窗口不能创建原生播放器');
    BTLogTool.info('开始初始化原生播放器');
    MediaKit.ensureInitialized();
    // Render subtitles with mpv/libass so ASS styling and embedded fonts are
    // preserved instead of reducing every subtitle track to Flutter text.
    var created = Player(
      configuration: PlayerConfiguration(
        libass: true,
        logLevel: Platform.isWindows ? MPVLogLevel.v : MPVLogLevel.info,
      ),
    );
    var createdDiagnostics = diagnostics = PlaybackDiagnostics(
      created,
      context: () {
        var rect = video?.rect.value;
        var hiRes = readHiRes();
        return {
          'file': readSession().current?.filePath,
          'loading': readSession().loading,
          'upscale': upscale.preferredMode.name,
          'loudness': readLoudnessActive(),
          'hires_requested': audio.hiResEnabled,
          'audio_exclusive_requested': audio.audioExclusiveEnabled,
          'audio_exclusive_configured': audio.exclusiveConfigured,
          'hires_status': hiRes.status,
          'texture': rect == null ? null : '${rect.width}x${rect.height}',
          'upscale_configured': upscaler?.configuredMode?.name,
        };
      },
    );
    // Subscribe before the rendering context is created. Keep only capability
    // evidence until the per-Player coordinator exists, never the full log.
    var earlyLogs = <PlayerLog>[];
    var logs = created.stream.log.listen((value) {
      createdDiagnostics.log(value);
      audio.log(value);
      var activeUpscale = upscaler;
      if (activeUpscale != null) {
        activeUpscale.log(value.prefix, value.level, value.text);
      } else if (earlyLogs.length < 16 &&
          (value.text.contains('GL_RENDERER=') ||
              value.text.contains('High bit depth FBOs unsupported'))) {
        earlyLogs.add(value);
      }
    });
    var createdChapters = PlaybackChapters(
      created.platform as NativePlayer,
      onChanged: onChanged,
    );
    var janaiSource = PlaybackJanaiVideoSource(
      read: createdDiagnostics.readProperty,
      onChanged: onChanged,
    );
    try {
      await PlaybackCache.configure(created);
      await PlaybackSubtitles.configure(created);
      await PlaybackAudio.apply(created, false);
      await createdChapters.initialize();
      var native = created.platform as NativePlayer;
      if (Platform.isWindows) {
        // Use the shader-capable pipeline from the first frame. mpv's simple
        // path samples the padded D3D11 decoder texture differently (e.g.
        // 1088 vs 1080 lines), shifting the picture when shaders are toggled.
        // Set this before VideoController creates the rendering context so
        // ordinary playback and upscale recovery share the same cropping.
        await native.setProperty('gpu-dumb-mode', 'no');
        for (var property in ['current-tracks/video', 'video-dec-params']) {
          await native.observeProperty(property, (_) async {
            unawaited(janaiSource.refresh());
          });
        }
      }
      for (var property in ['audio-out-params', 'current-tracks/audio']) {
        await native.observeProperty(property, (_) async {
          audio.scheduleRefresh();
        });
      }
      if (Platform.isWindows) {
        await PlaybackLoudness.apply(created, readLoudnessActive());
      }
    } catch (error, stackTrace) {
      BTLogTool.error(['初始化播放器失败：$error', stackTrace.toString()]);
      createdDiagnostics.close();
      createdChapters.close();
      janaiSource.close();
      await logs.cancel();
      await disposePlayer(created);
      rethrow;
    }
    if (isClosed()) {
      createdDiagnostics.close();
      createdChapters.close();
      janaiSource.close();
      await logs.cancel();
      await disposePlayer(created);
      return;
    }
    player = created;
    chapters = createdChapters;
    janaiVideoSource = janaiSource;
    // Keep the same GPU decoder for plain playback, Anime4K and AnimeJaNai.
    // The coordinator only changes filters after checking the media's range.
    video = VideoController(
      created,
      configuration: VideoControllerConfiguration(
        hwdec: Platform.isWindows
            ? NativePlaybackUpscaleBackend.hardwareDecoder
            : null,
      ),
    );
    if (Platform.isWindows) {
      var videoController = video!;
      upscaler = upscale.createUpscaler(
        created,
        videoController,
        createdDiagnostics,
      );
      for (var value in earlyLogs) {
        upscaler!.log(value.prefix, value.level, value.text);
      }
      _textureListener = updateTexture;
      videoController.rect.addListener(updateTexture);
      updateTexture();
    }
    _subscriptions.addAll([
      logs,
      created.stream.playing.listen((value) {
        createdDiagnostics.event('播放状态改变：playing=$value');
        upscaler?.playbackState(
          playing: value,
          buffering: created.state.buffering,
        );
      }),
      created.stream.buffering.listen((value) {
        createdDiagnostics.event('缓冲状态改变：buffering=$value');
        upscaler?.playbackState(
          playing: created.state.playing,
          buffering: value,
        );
      }),
      created.stream.rate.listen((value) {
        createdDiagnostics.event('播放速率改变：rate=$value');
        upscaler?.playbackRate(value);
        audio.scheduleRefresh();
        onChanged();
      }),
      created.stream.audioParams.listen((_) => audio.scheduleRefresh()),
      created.stream.audioDevice.listen((_) => audio.deviceChanged()),
      created.stream.tracks.listen((_) {
        if (Platform.isWindows) unawaited(janaiSource.refresh());
        var session = readSession();
        if (isClosed() ||
            session.completed ||
            session.manualSubtitles ||
            session.current == null) {
          return;
        }
        var sessionId = session.id;
        unawaited(
          serial(() async {
            if (readSession().id != sessionId ||
                readSession().current == null) {
              return;
            }
            await autoSelectSubtitle();
          }).catchError((Object _) {}),
        );
      }),
      created.stream.position.listen((value) {
        var session = readSession();
        if (!isClosed() && !session.loading && session.current != null) {
          writePosition(value);
        }
      }),
      created.stream.duration.listen((value) {
        // Duration may arrive only once, while open or subtitle loading is
        // still pending. The Store resets it before opening the new media.
        var session = readSession();
        if (!isClosed() && session.current != null && value > Duration.zero) {
          writeDuration(value);
        }
      }),
      created.stream.videoParams.listen((value) {
        if (isClosed() || readSession().current == null) return;
        if (Platform.isWindows) unawaited(janaiSource.refresh());
        var source = videoSource(value);
        upscaler?.source(source);
        var ratio = playbackAspectRatio(
          aspect: value.aspect,
          width: value.dw ?? value.w,
          height: value.dh ?? value.h,
          rotation: value.rotate,
        );
        // 像素尺寸参与窗口缩放，等比例的分辨率切换也必须通知界面。
        var size = source == null
            ? null
            : Size(source.width.toDouble(), source.height.toDouble());
        if (ratio == readAspectRatio() && size == readVideoSize()) return;
        writeGeometry(ratio, size);
        onChanged();
      }),
      created.stream.error.listen((value) {
        createdDiagnostics.failure(value);
        if (isClosed() || readSession().current == null) return;
        if (upscaler?.consumesError(value) ?? false) return;
        writeError(value);
        onChanged();
      }),
      created.stream.completed.listen((value) {
        var session = readSession();
        if (isClosed() ||
            session.clearingPlayback ||
            session.loading ||
            session.current == null) {
          return;
        }
        writeCompleted(value);
        if (!value) return;
        createdDiagnostics.event('视频播放完成');
        var snapshot = finishSession(
          position: session.position,
          duration: session.duration,
        );
        if (snapshot == null) return;
        var items = session.playlist;
        var finishedIndex = session.index;
        unawaited(
          // Matching runs alongside the durable write, outside the operation
          // queue. Refreshing the full history waits until after the switch.
          Future.wait<int?>([
                serial(() async {
                  if (readSession().id != snapshot.sessionId) return;
                  await writeHistory(snapshot.historyItem);
                  if (isClosed()) return;
                  emitCompletion(snapshot);
                  onChanged();
                }).then((_) => null),
                nextEpisodeIndex(items, finishedIndex),
              ])
              .then((results) async {
                var live = readSession();
                if (isClosed() ||
                    live.clearingPlayback ||
                    live.id != snapshot.sessionId) {
                  return;
                }
                var nextIndex = results[1];
                if (nextIndex == null) {
                  await refreshHistory();
                  return;
                }
                await serial(() async {
                  var queued = readSession();
                  if (isClosed() ||
                      queued.clearingPlayback ||
                      queued.id != snapshot.sessionId) {
                    return;
                  }
                  var nextKey = items[nextIndex].key;
                  var liveIndex = queued.playlist.indexWhere(
                    (item) => item.key == nextKey,
                  );
                  if (liveIndex >= 0) await openIndex(liveIndex);
                });
              })
              .catchError((Object failure) {
                if (isClosed() || readSession().id != snapshot.sessionId) {
                  return;
                }
                writeError('自动切换下一集失败：$failure');
                onChanged();
              }),
        );
      }),
    ]);
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      var session = readSession();
      if (isClosed() ||
          session.clearingPlayback ||
          session.loading ||
          !created.state.playing ||
          session.completed) {
        return;
      }
      // Persist progress without fetching/grouping the entire library or
      // rebuilding the video surface every five seconds during playback.
      unawaited(
        serial(() async {
          if (!readSession().clearingPlayback) {
            await saveProgress(refreshHistory: false);
          }
        }).catchError((Object _) {}),
      );
    });
  }

  static PlaybackVideoSource? videoSource(VideoParams value) =>
      playbackVideoSource(
        width: value.dw ?? value.w,
        height: value.dh ?? value.h,
        pixelWidth: value.w,
        pixelHeight: value.h,
        rotation: value.rotate,
        gamma: value.gamma,
      );

  void updateTexture() {
    var rect = video?.rect.value;
    upscaler?.texture(
      rect == null
          ? null
          : (width: rect.width.round(), height: rect.height.round()),
    );
  }

  Future<void> disposePlayer(Player target, {PlaybackUpscaler? upscale}) {
    var disposal = () async {
      BTLogTool.info('开始释放原生播放器');
      // This wait is not cancelled by the shutdown budget: native commands may
      // still own the media_kit disposal lock after a timeout.
      await upscale?.close();
      await target.dispose();
      BTLogTool.info('Player.dispose 已完成，等待原生销毁=$waitForNativeDestroy');
    }();
    // media_kit 1.2.6 schedules mpv_terminate_destroy 5 seconds after dispose.
    // Do not destroy the child isolate before that timer runs, or call the
    // native destructor ourselves (which would double-free the same handle).
    trackNativeDisposal(disposal, waitForNativeDestroy: waitForNativeDestroy);
    return disposal;
  }

  /// Cancel idle/save timers before shutdown drains accepted work.
  void prepareShutdown() {
    cancelIdleTimer();
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  /// Detach UI-facing native handles; caller finishes subscription cancel and
  /// [disposePlayer] under the shutdown budget.
  ({Player? player, PlaybackUpscaler? upscale}) detachForShutdown() {
    var textureListener = _textureListener;
    if (textureListener != null) video?.rect.removeListener(textureListener);
    _textureListener = null;
    var releasing = player;
    var upscaleInstance = upscaler;
    player = null;
    video = null;
    return (player: releasing, upscale: upscaleInstance);
  }

  List<StreamSubscription<dynamic>> takeSubscriptions() {
    var subscriptions = List<StreamSubscription<dynamic>>.of(_subscriptions);
    _subscriptions.clear();
    return subscriptions;
  }
}
