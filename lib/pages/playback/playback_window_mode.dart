// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

// Project imports:
import '../../models/playback/playback_window_size.dart';
import '../../tools/log_tool.dart';

/// Owns native presentation only. The Player and its texture remain mounted
/// while the same video surface moves between the page and a borderless window.
class PlaybackWindowMode extends ChangeNotifier {
  bool videoOnly = false;
  bool screenFullscreen = false;
  bool transitioning = false;
  Rect? restoreBounds;
  bool _restoreMaximized = false;
  bool _disposed = false;
  double _aspectRatio = 16 / 9;
  Future<void> _operation = Future.value();

  Future<void> _serial(Future<void> Function() action) {
    var next = _operation.then((_) async {
      if (_disposed) return;
      transitioning = true;
      notifyListeners();
      try {
        await action();
      } finally {
        transitioning = false;
        if (!_disposed) notifyListeners();
      }
    });
    _operation = next.catchError((Object error) {
      BTLogTool.warn('播放器窗口模式切换失败：$error');
    });
    return next;
  }

  void updateAspectRatio(double? ratio) {
    if (_disposed ||
        ratio == null ||
        !ratio.isFinite ||
        ratio <= 0 ||
        ratio == _aspectRatio) {
      return;
    }
    _aspectRatio = ratio;
    if (!videoOnly || screenFullscreen) return;
    unawaited(
      _serial(() async {
        if (!videoOnly || screenFullscreen) return;
        await _fitVideoBounds(await windowManager.getBounds());
      }).catchError((Object _) {}),
    );
  }

  Future<void> toggleVideoOnly(Size surfaceSize) => _serial(() async {
    if (screenFullscreen) throw StateError('请先退出屏幕全屏');
    if (videoOnly) {
      await _restoreNormal();
      videoOnly = false;
      return;
    }
    _restoreMaximized = await windowManager.isMaximized();
    if (_restoreMaximized) await windowManager.unmaximize();
    restoreBounds = await windowManager.getBounds();
    var bounds = restoreBounds!;
    try {
      await windowManager.setMinimumSize(Size.zero);
      await windowManager.setMaximizable(false);
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      // hidden alone retains Windows resize borders. Frameless makes the native
      // window and the Flutter video viewport exactly the same size.
      await windowManager.setAsFrameless();
      await _fitVideoBounds(
        Rect.fromCenter(
          center: bounds.center,
          width: surfaceSize.width,
          height: surfaceSize.height,
        ),
      );
      videoOnly = true;
    } catch (_) {
      await _restoreNormal();
      rethrow;
    }
  });

  Future<void> _restoreNormal() async {
    await windowManager.setAspectRatio(0);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setMaximizable(true);
    await windowManager.setMinimumSize(const Size(720, 480));
    if (restoreBounds != null) await windowManager.setBounds(restoreBounds!);
    if (_restoreMaximized) await windowManager.maximize();
  }

  Future<void> exitVideoOnly() => _serial(() async {
    if (!videoOnly || screenFullscreen) return;
    await _restoreNormal();
    videoOnly = false;
  });

  Future<Rect> _workArea(Rect bounds) async {
    var displays = await screenRetriever.getAllDisplays();
    for (var display in displays) {
      var area =
          (display.visiblePosition ?? Offset.zero) &
          (display.visibleSize ?? display.size);
      if (area.contains(bounds.center)) return area;
    }
    var primary = await screenRetriever.getPrimaryDisplay();
    return (primary.visiblePosition ?? Offset.zero) &
        (primary.visibleSize ?? primary.size);
  }

  Future<void> _fitVideoBounds(Rect bounds) async {
    var area = await _workArea(bounds);
    var size = fitPlaybackWindowSize(
      width: bounds.width,
      height: bounds.height,
      aspectRatio: _aspectRatio,
      maxWidth: area.width,
      maxHeight: area.height,
    );
    var minimum = fitPlaybackWindowSize(
      width: 320,
      height: 180,
      aspectRatio: _aspectRatio,
      maxWidth: area.width,
      maxHeight: area.height,
    );
    await windowManager.setMinimumSize(Size(minimum.width, minimum.height));
    await windowManager.setAspectRatio(_aspectRatio);
    await windowManager.setBounds(
      Rect.fromLTWH(
        (bounds.center.dx - size.width / 2).clamp(
          area.left,
          area.right - size.width,
        ),
        (bounds.center.dy - size.height / 2).clamp(
          area.top,
          area.bottom - size.height,
        ),
        size.width,
        size.height,
      ),
    );
  }

  Future<void> enterScreenFullscreen() => _serial(() async {
    if (screenFullscreen) return;
    await windowManager.setAspectRatio(0);
    if (videoOnly) {
      // window_manager does not expand an already-frameless window to a
      // monitor. Reset that flag before entering, then restore it on exit.
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
    }
    await windowManager.setFullScreen(true);
    screenFullscreen = true;
  });

  Future<void> exitScreenFullscreen() => _serial(() async {
    if (!screenFullscreen) return;
    await windowManager.setFullScreen(false);
    screenFullscreen = false;
    if (videoOnly) {
      await windowManager.setAsFrameless();
      await windowManager.setMaximizable(false);
      await _fitVideoBounds(await windowManager.getBounds());
    } else {
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    }
  });

  Future<void> startDragging() => windowManager.startDragging();
  Future<void> minimize() => windowManager.minimize();
  Future<void> closeWindow() => windowManager.close();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Resize hit targets overlay the video rather than reserving window borders.
class PlaybackWindowResizeFrame extends StatelessWidget {
  const PlaybackWindowResizeFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      for (var edge in ResizeEdge.values)
        Positioned(
          left: switch (edge) {
            ResizeEdge.right ||
            ResizeEdge.topRight ||
            ResizeEdge.bottomRight => null,
            _ => 0,
          },
          right: switch (edge) {
            ResizeEdge.left ||
            ResizeEdge.topLeft ||
            ResizeEdge.bottomLeft => null,
            _ => 0,
          },
          top: switch (edge) {
            ResizeEdge.bottom ||
            ResizeEdge.bottomLeft ||
            ResizeEdge.bottomRight => null,
            _ => 0,
          },
          bottom: switch (edge) {
            ResizeEdge.top || ResizeEdge.topLeft || ResizeEdge.topRight => null,
            _ => 0,
          },
          width: edge == ResizeEdge.top || edge == ResizeEdge.bottom ? null : 6,
          height: edge == ResizeEdge.left || edge == ResizeEdge.right
              ? null
              : 6,
          child: MouseRegion(
            cursor: switch (edge) {
              ResizeEdge.left ||
              ResizeEdge.right => SystemMouseCursors.resizeLeftRight,
              ResizeEdge.top ||
              ResizeEdge.bottom => SystemMouseCursors.resizeUpDown,
              ResizeEdge.topLeft || ResizeEdge.bottomRight =>
                SystemMouseCursors.resizeUpLeftDownRight,
              ResizeEdge.topRight ||
              ResizeEdge.bottomLeft => SystemMouseCursors.resizeUpRightDownLeft,
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => unawaited(windowManager.startResizing(edge)),
            ),
          ),
        ),
    ],
  );
}
