// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:window_manager/window_manager.dart';

// Project imports:
import '../../providers/episode_mark_providers.dart';
import '../../store/app_store.dart';
import '../../store/nav_store.dart';
import '../../store/playback_store.dart';
import '../../tools/log_tool.dart';
import 'episode_mark_service.dart';
import 'playback_episode_protocol.dart';
import 'playback_window_data_host.dart';
import 'playback_window_protocol.dart';

final playbackWindowServiceProvider =
    ChangeNotifierProvider<PlaybackWindowService>((ref) {
      var service = PlaybackWindowService(ref, ref.read(playbackStoreProvider));
      ref.listen(episodeMarkProvider, (_, _) => service.publishPresentation());
      ref.listen(appStoreProvider, (_, _) => service.publishPresentation());
      return service;
    });

class _PlaybackWindowSession {
  _PlaybackWindowSession(this.identity, this.data)
    : channel = WindowMethodChannel(
        identity.hostChannel,
        mode: ChannelMode.unidirectional,
      );
  final PlaybackWindowIdentity identity;
  final PlaybackWindowDataHost data;
  final WindowMethodChannel channel;
  final ready = Completer<void>();
  final gone = Completer<void>();
  WindowController? window;
  String? reportedId;
  bool closing = false;
  bool visible = true;
  Completer<void>? closePending;
  bool cleanupConfirmed = false;
  int sequence = 0;
  Future<void> push = Future.value();
  Future<void>? retirement;
}

/// Main-engine owner of the single child window and all durable data access.
class PlaybackWindowService extends ChangeNotifier {
  PlaybackWindowService(this.ref, this.store) {
    _events = onWindowsChanged.listen((_) {
      unawaited(
        _checkWindow().catchError((Object error) {
          BTLogTool.warn('检查播放器窗口失败：$error');
        }),
      );
    });
  }
  final Ref ref;
  final PlaybackStore store;
  late final StreamSubscription<void> _events;
  _PlaybackWindowSession? _session;
  Future<void> _operations = Future.value();
  Future<void>? _shutdownFuture;
  bool _exiting = false;
  bool _disposed = false;
  int _generation = 0;
  int _presentationRevision = 0;
  String? error;
  bool get hasWindow => _session != null;
  bool get isClosing => _session?.closing == true;

  void clearError() {
    if (error == null) return;
    error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _serial(Future<void> Function() action) {
    var result = _operations.then((_) => action());
    _operations = result.catchError((Object failure, StackTrace stackTrace) {
      BTLogTool.error(['播放器窗口操作失败：$failure', stackTrace.toString()]);
      error = failure.toString();
      _notify();
    });
    return result;
  }

  Future<void> open({String? filePath, int? subject}) => _serial(() async {
    if (_exiting) throw StateError('应用正在退出');
    await _checkWindow();
    var session = _session ?? await _create();
    var pendingClose = session.closePending;
    if (pendingClose != null) {
      await pendingClose.future.timeout(const Duration(seconds: 30));
    }
    if (_exiting) throw StateError('应用正在退出');
    if (session.closing) throw StateError('播放器正在保存并关闭，请稍后重试');
    error = null;
    await _invoke(session, 'activate', {});
    if (_exiting) throw StateError('应用正在退出');
    if (filePath != null) {
      await _invoke(session, 'open', {
        'filePath': filePath,
        'subject': subject,
      });
    }
    _notify();
  });

  Future<_PlaybackWindowSession> _create() async {
    var identity = PlaybackWindowIdentity(
      '${DateTime.now().microsecondsSinceEpoch}-${++_generation}',
    );
    var session = _PlaybackWindowSession(
      identity,
      PlaybackWindowDataHost(
        identity: identity,
        library: store.library,
        history: store.historyStore,
        settings: store.settingsStore,
        subjects: store.subjectResolver,
        cover: store.cover,
        onHistoryChanged: () {
          unawaited(
            store.refreshHistory().catchError((Object failure) {
              BTLogTool.warn('刷新主窗口播放记录失败：$failure');
            }),
          );
        },
      ),
    );
    _session = session;
    BTLogTool.info('创建播放器窗口会话：generation=${identity.generation}');
    unawaited(session.ready.future.catchError((Object _) {}));
    _notify();
    try {
      await session.channel.setMethodCallHandler(
        (call) => _handle(session, call),
      );
      BTLogTool.info('播放器窗口通道已注册：${identity.hostChannel}');
      session.window = await WindowController.create(
        WindowConfiguration(arguments: identity.encode()),
      );
      await session.ready.future.timeout(const Duration(seconds: 20));
      if (session.reportedId != session.window!.windowId) {
        throw StateError('播放器窗口身份不匹配');
      }
      if (!identical(_session, session) || session.closing) {
        throw StateError('播放器窗口已经关闭');
      }
      return session;
    } catch (_) {
      // A timed-out engine may still be starting; retain ownership until its
      // actual close is observed, so another Player is never created alongside.
      session.closing = true;
      if (session.window == null) await _retire(session);
      _notify();
      rethrow;
    }
  }

  Map<String, Object?> _presentation() {
    var marking = ref.read(episodeMarkProvider.notifier);
    var settings = ref.read(appStoreProvider);
    return {
      'theme': settings.themeMode.name,
      'accent': settings.effectiveAccentColor.toARGB32(),
      'bangumiUrl': settings.bangumiUrl,
      'episodes': encodeEpisodeMarkState(
        ref.read(episodeMarkProvider),
        account: marking.currentAccount(),
        revision: ++_presentationRevision,
      ),
    };
  }

  void publishPresentation() {
    var session = _session;
    if (session == null ||
        session.window == null ||
        session.closing ||
        !session.visible ||
        _disposed) {
      return;
    }
    var value = _presentation();
    session.push = session.push
        .then((_) async {
          if (identical(_session, session) && !session.closing) {
            await _invoke(session, 'presentation', value);
          }
        })
        .catchError((Object failure) {
          BTLogTool.warn('更新播放器主题或提示失败：$failure');
        });
  }

  Future<Object?> _invoke(
    _PlaybackWindowSession session,
    String method,
    Map<String, Object?> body,
  ) {
    var window = session.window;
    if (window == null) throw StateError('播放器尚未就绪');
    return window.invokeMethod<Object?>(
      method,
      session.identity.request(++session.sequence, body),
    );
  }

  Future<Object?> _handle(
    _PlaybackWindowSession session,
    MethodCall call,
  ) async {
    if (!identical(_session, session)) throw StateError('播放器窗口会话已经失效');
    var body = session.identity.read(call.arguments).body;
    switch (call.method) {
      case 'bootstrap':
        BTLogTool.info('播放器窗口 bootstrap：${session.identity.generation}');
        return _presentation();
      case 'ready':
        var id = playbackString(body, 'windowId');
        if (session.reportedId != null && session.reportedId != id) {
          throw StateError('重复的窗口身份');
        }
        session.reportedId = id;
        if (!session.ready.isCompleted) session.ready.complete();
        return _presentation();
      case 'closing':
        session.closing = true;
        if (!_exiting && session.closePending == null) {
          session.closePending = Completer<void>();
          unawaited(session.closePending!.future.catchError((Object _) {}));
        }
        ref.read(episodeMarkProvider.notifier).discardWindowWork();
        _notify();
        return null;
      case 'hidden':
        session.visible = false;
        session.closing = _exiting;
        _finishClose(session);
        _notify();
        return null;
      case 'activated':
        if (_exiting) throw StateError('应用正在退出');
        session.visible = true;
        session.closing = false;
        _notify();
        return _presentation();
      case 'closeFailed':
        error = playbackString(body, 'message');
        session.visible = true;
        session.closing = _exiting;
        _finishClose(session, failure: StateError(error!));
        _notify();
        return _presentation();
      case 'closed':
        session.closing = true;
        session.cleanupConfirmed = true;
        return null;
      case 'failed':
        error = playbackString(body, 'message');
        BTLogTool.error('播放器窗口启动失败：$error');
        if (!session.ready.isCompleted) {
          session.ready.completeError(StateError(error!));
        }
        _notify();
        return null;
      case 'subject.open':
        if (session.closing || _exiting) throw StateError('播放器正在关闭');
        ref
            .read(navStoreProvider.notifier)
            .addNavItemB(
              subject: playbackInt(body, 'subject', minimum: 1),
              paneTitle: store.cover.nameOf(
                playbackInt(body, 'subject', minimum: 1),
              ),
            );
        if (await windowManager.isMinimized()) await windowManager.restore();
        await windowManager.show();
        await windowManager.focus();
        return null;
      default:
        if (call.method.startsWith('episodes.')) {
          if (session.closing || _exiting) throw StateError('播放器正在关闭');
          return _episodeRequest(call.method, body);
        }
        return session.data.handle(call.method, call.arguments);
    }
  }

  void _finishClose(_PlaybackWindowSession session, {Object? failure}) {
    var pending = session.closePending;
    session.closePending = null;
    if (pending == null || pending.isCompleted) return;
    if (failure == null) {
      pending.complete();
    } else {
      pending.completeError(failure);
    }
  }

  Future<Object?> _episodeRequest(
    String method,
    Map<String, Object?> body,
  ) async {
    var controller = ref.read(episodeMarkProvider.notifier);
    Object? result;
    switch (method) {
      case 'episodes.syncItems':
        if (body['account'] == controller.currentAccount()) {
          await controller.syncItems(
            (body['items'] as List).map(decodePlaybackItem).toList(),
            refresh: body['refresh'] as bool,
          );
        }
      case 'episodes.markItem':
        var write = body['account'] != controller.currentAccount()
            ? const EpisodeMarkWriteResult(EpisodeMarkWriteStatus.expired)
            : await controller.markItem(decodePlaybackItem(body['item']));
        result = {'status': write.status.name, 'message': write.message};
      default:
        throw FormatException('不支持的章节请求：$method');
    }
    return {'result': result, 'state': _presentation()['episodes']};
  }

  Future<void> _checkWindow() async {
    var session = _session;
    if (session == null || session.window == null) return;
    var windows = await WindowController.getAll();
    if (!identical(_session, session)) return;
    if (!windows.any((window) => window.windowId == session.window!.windowId)) {
      if (!session.cleanupConfirmed) {
        // Native ownership cannot be inferred from a disappeared HWND. Block
        // reopening after an unexpected close until the whole app restarts.
        if (!session.gone.isCompleted) {
          BTLogTool.error('播放器意外关闭：generation=${session.identity.generation}');
        }
        session.closing = true;
        error = '播放器意外关闭，原生释放未确认；请重启应用后再播放';
        _finishClose(session, failure: StateError(error!));
        if (!session.gone.isCompleted) session.gone.complete();
        ref.read(episodeMarkProvider.notifier).discardWindowWork();
        _notify();
        return;
      }
      await _retire(session);
    }
  }

  Future<void> _retire(_PlaybackWindowSession session) =>
      session.retirement ??= _finishRetirement(session);

  Future<void> _finishRetirement(_PlaybackWindowSession session) async {
    _finishClose(session, failure: StateError('播放器窗口已经关闭'));
    await session.data.close();
    await session.channel.setMethodCallHandler(null);
    BTLogTool.info('播放器窗口通道已注销：generation=${session.identity.generation}');
    if (identical(_session, session)) {
      _session = null;
      ref.read(episodeMarkProvider.notifier).discardWindowWork();
    }
    if (!session.gone.isCompleted) session.gone.complete();
    _notify();
  }

  Future<void> shutdown() => _shutdownFuture ??= _shutdown();
  Future<void> _shutdown() async {
    _exiting = true;
    // An open command can itself be waiting on the child's playback queue.
    // Send close concurrently once a window exists; its store drains that
    // queue.
    if (_session?.window == null) {
      await _operations.timeout(const Duration(seconds: 30));
    }
    var session = _session;
    if (session == null) return;
    session.closing = true;
    await _invoke(
      session,
      'prepareClose',
      {},
    ).timeout(const Duration(seconds: 30));
    await _checkWindow();
    await session.gone.future.timeout(const Duration(seconds: 10));
    if (!session.cleanupConfirmed) throw StateError('播放器未确认原生清理');
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_events.cancel());
    super.dispose();
  }
}
