// Dart imports:
import 'dart:async';
import 'dart:io';

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

// Project imports:
import '../../models/playback/playback_on_top.dart';
import '../../models/playback/playback_window_size.dart';
import '../../tools/log_tool.dart';

/// Owns native presentation of the independent player window. That window is
/// always a frameless video surface: [PlaybackPage] renders only the video and
/// its floating controls, so there is no windowed layout and no switch between
/// the two. The main window keeps its own embedded page.
class PlaybackWindowMode extends ChangeNotifier {
  PlaybackWindowMode({this.persistOnTop});

  /// 置顶偏好的持久化写入端；由窗口持有者注入，切换状态时按需调用。
  final Future<void> Function(PlaybackOnTop value)? persistOnTop;

  /// 无边框视频窗口允许的最小尺寸。
  static const minimumSize = Size(320, 180);

  /// 未载入视频（停止播放）时数字键仍可用的基准尺寸。
  static const defaultVideoSize = Size(1920, 1080);

  static const _frameChannel = MethodChannel(
    'bangumi_today/playback_window_frame',
  );

  Future<void> _setFullscreenFrame(bool fullscreen) async {
    if (!Platform.isWindows) return;
    await _frameChannel.invokeMethod<void>('setFullscreenFrame', fullscreen);
  }

  bool screenFullscreen = false;
  bool transitioning = false;
  bool _disposed = false;
  PlaybackOnTop _onTop = PlaybackOnTop.off;
  bool _onTopApplied = false;
  bool _playing = false;
  double _aspectRatio = 16 / 9;
  Size? _videoSize;

  /// 用户手动移动/缩放（含系统吸附与最大化）后，窗口尺寸由用户决定，
  /// 不再随视频分辨率自动调整；数字键仍然生效并重新接管。
  bool _userSized = false;

  /// 自绘拖动的状态：起始窗口边界、起始光标屏幕坐标、显示器可用区域、
  /// 待写入的位置，以及是否已把拖动交还给系统移动循环。
  Rect? _dragOrigin;
  Offset? _dragCursor;
  List<Rect> _dragAreas = const [];
  Offset? _dragTarget;
  bool _dragWriting = false;
  bool _dragHandedOff = false;
  double? _lastCursorY;

  /// 光标进入屏幕顶端多少像素内交给系统拖动（Windows 的吸附布局就在顶端触发）。
  static const _systemDragTopBand = 8.0;

  /// 窗口倍率，基准是视频像素尺寸；1 表示逐像素显示，数字键 1/2/3 修改。
  double _videoScale = 1;
  Future<void> _operation = Future.value();

  PlaybackOnTop get onTop => _onTop;

  /// 当前视频的显示像素尺寸，未载入视频时为 `null`。
  Size? get videoSize => _videoSize;

  /// 数字键使用的基准尺寸：停止播放时退回 1080p。
  Size get scaleBaseSize => _videoSize ?? defaultVideoSize;

  /// 物理像素与逻辑像素之比：原始尺寸按它换算，做到逐像素显示。
  double get _devicePixelRatio {
    for (var view in WidgetsBinding.instance.platformDispatcher.views) {
      var ratio = view.devicePixelRatio;
      if (ratio.isFinite && ratio > 0) return ratio;
    }
    return 1;
  }

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

  /// 把原生窗口变成无边框视频窗口。在窗口显示前调用，避免先出现标题栏。
  /// 保留可缩放与可最大化样式，Windows 才会提供贴边吸附、拖到顶端最大化与
  /// 吸附布局；无边框客户区由插件的 NCCALCSIZE 处理，视口仍等于窗口尺寸。
  Future<void> applyFramelessWindow() async {
    await windowManager.setAspectRatio(0);
    await windowManager.setMinimumSize(minimumSize);
    await windowManager.setResizable(true);
    await windowManager.setMaximizable(true);
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setAsFrameless();
    // Remove native caption styles before window_manager captures the windowed
    // baseline. Its frameless flag alone only changes non-client layout.
    await _setFullscreenFrame(false);
  }

  /// 用户拖动、缩放、吸附（含最大化）或恢复过保存尺寸后，尺寸交给用户。
  void markUserSized() {
    if (_disposed || _userSized) return;
    _userSized = true;
  }

  /// 记录当前流的显示比例与像素尺寸。默认倍率为 1，因此新分辨率会按视频原始
  /// 像素重新开窗；用户自己调整过窗口后不再自动改动，只更新比例。
  void updateVideo(double? ratio, Size? size) {
    if (_disposed) return;
    var changed = false;
    if (ratio != null && ratio.isFinite && ratio > 0 && ratio != _aspectRatio) {
      _aspectRatio = ratio;
      changed = true;
    }
    if (size != null &&
        size.isFinite &&
        size.width > 0 &&
        size.height > 0 &&
        size != _videoSize) {
      _videoSize = size;
      changed = true;
    }
    if (!changed || screenFullscreen || _userSized) return;
    unawaited(
      _serial(() async {
        if (screenFullscreen || _userSized) return;
        await _fitToVideo(await windowManager.getBounds());
      }).catchError((Object _) {}),
    );
  }

  /// 按当前倍率调整窗口；[center] 为 true 时居中，否则只在溢出时移动。
  Future<Size> _fitToVideo(Rect current, {bool center = false}) async {
    var area = await _workArea(current);
    var pixel = _videoSize ?? defaultVideoSize;
    // 停止播放时基准是 16:9，不沿用上一个视频的比例。
    var ratio = _videoSize == null ? pixel.width / pixel.height : null;
    var dpr = _devicePixelRatio;
    return _fitVideoBounds(
      Rect.fromLTWH(
        current.left,
        current.top,
        pixel.width * _videoScale / dpr,
        pixel.height * _videoScale / dpr,
      ),
      area: area,
      aspectRatio: ratio,
      center: center,
    );
  }

  /// 把窗口调整到视频像素尺寸的 [scale] 倍，返回实际尺寸与是否受屏幕限制。
  /// 默认保留左上角位置；[center] 为 true 时在工作区居中。
  /// 未载入视频时以 1080p 为基准，数字键在停止播放后仍然生效。
  Future<({Size size, bool clamped})?> setVideoScale(
    double scale, {
    bool center = false,
  }) async {
    if (_disposed || !scale.isFinite || scale <= 0) return null;
    var pixel = _videoSize ?? defaultVideoSize;
    var dpr = _devicePixelRatio;
    var requested = Size(pixel.width * scale / dpr, pixel.height * scale / dpr);
    Size? applied;
    await _serial(() async {
      if (screenFullscreen) return;
      // 显式选定的倍率重新接管窗口尺寸。
      _userSized = false;
      _videoScale = scale;
      applied = await _fitToVideo(
        await windowManager.getBounds(),
        center: center,
      );
    });
    var size = applied;
    if (size == null) return null;
    // 可用工作区不足时 fitPlaybackWindowSize 会等比缩小，如实报告而不是
    // 让用户以为窗口已经是请求的倍率。
    var clamped =
        size.width < requested.width - 0.5 ||
        size.height < requested.height - 0.5;
    return (size: size, clamped: clamped);
  }

  /// 所有显示器的可用区域。
  Future<List<Rect>> _displayAreas() async {
    var displays = await screenRetriever.getAllDisplays();
    return [
      for (var display in displays)
        (display.visiblePosition ?? Offset.zero) &
            (display.visibleSize ?? display.size),
    ];
  }

  /// 光标所在屏幕的可用区域；没有屏幕包含该点时取最近的一块。
  Rect? _areaForPoint(Offset point) {
    Rect? nearest;
    var distance = double.infinity;
    for (var area in _dragAreas) {
      if (area.contains(point)) return area;
      var delta = area.center - point;
      var squared = delta.dx * delta.dx + delta.dy * delta.dy;
      if (squared >= distance) continue;
      distance = squared;
      nearest = area;
    }
    return nearest;
  }

  /// 窗口所在屏幕的可用区域：取重叠面积最大的显示器；完全在屏幕外时按
  /// 光标所在屏幕处理，便于把窗口收回来。
  Future<Rect> _workArea(Rect bounds) async {
    var displays = await screenRetriever.getAllDisplays();
    Rect? best;
    var bestOverlap = 0.0;
    for (var display in displays) {
      var area =
          (display.visiblePosition ?? Offset.zero) &
          (display.visibleSize ?? display.size);
      var overlap = area.intersect(bounds);
      if (overlap.width <= 0 || overlap.height <= 0) continue;
      var size = overlap.width * overlap.height;
      if (size <= bestOverlap) continue;
      bestOverlap = size;
      best = area;
    }
    if (best != null) return best;
    var cursor = await screenRetriever.getCursorScreenPoint();
    for (var display in displays) {
      var area =
          (display.visiblePosition ?? Offset.zero) &
          (display.visibleSize ?? display.size);
      if (area.contains(cursor)) return area;
    }
    var primary = await screenRetriever.getPrimaryDisplay();
    return (primary.visiblePosition ?? Offset.zero) &
        (primary.visibleSize ?? primary.size);
  }

  Future<Size> _fitVideoBounds(
    Rect bounds, {
    Rect? area,
    double? aspectRatio,
    bool center = false,
  }) async {
    var work = area ?? await _workArea(bounds);
    var ratio = aspectRatio ?? _aspectRatio;
    // 已被系统最大化或吸附时先还原，否则新尺寸只会写进还原矩形。
    if (await windowManager.isMaximized()) await windowManager.unmaximize();
    var size = fitPlaybackWindowSize(
      width: bounds.width,
      height: bounds.height,
      aspectRatio: ratio,
      maxWidth: work.width,
      maxHeight: work.height,
    );
    var minimum = fitPlaybackWindowSize(
      width: minimumSize.width,
      height: minimumSize.height,
      aspectRatio: ratio,
      maxWidth: work.width,
      maxHeight: work.height,
    );
    await windowManager.setMinimumSize(Size(minimum.width, minimum.height));
    // 应用算好的尺寸本身已符合视频比例；顺带清掉可能残留的比例锁，避免它
    // 影响系统贴边吸附与用户自由调整（只有拖边调整大小时才短暂加锁）。
    await releaseRatioLock();
    var position = positionPlaybackWindow(
      left: bounds.left,
      top: bounds.top,
      width: size.width,
      height: size.height,
      workLeft: work.left,
      workTop: work.top,
      workWidth: work.width,
      workHeight: work.height,
      center: center,
    );
    await windowManager.setBounds(
      Rect.fromLTWH(position.left, position.top, size.width, size.height),
    );
    return Size(size.width, size.height);
  }

  /// 首次显示或主窗口唤起时居中；尺寸超过工作区时等比缩小。
  Future<void> centerWindow({Rect? area}) => _serial(() async {
    if (screenFullscreen || await windowManager.isFullScreen()) return;
    if (await windowManager.isMaximized()) await windowManager.unmaximize();
    var bounds = await windowManager.getBounds();
    await _fitVideoBounds(
      bounds,
      area: area,
      aspectRatio: bounds.width / bounds.height,
      center: true,
    );
  });

  Future<void> _applyScreenFullscreen(bool fullscreen) async {
    await windowManager.setAspectRatio(0);
    // The Windows override preserves frameless state through fullscreen.
    // Other platforms still use the plugin's original presentation path.
    if (fullscreen && !Platform.isWindows) {
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
    }
    await windowManager.setFullScreen(fullscreen);
    if (!fullscreen && !Platform.isWindows) {
      await windowManager.setAsFrameless();
      await windowManager.setResizable(true);
      await windowManager.setMaximizable(true);
    }
    if (await windowManager.isFullScreen() != fullscreen) {
      throw StateError('播放器原生全屏状态未更新');
    }
    await _setFullscreenFrame(fullscreen);
    if (!fullscreen && !await windowManager.isMaximized()) {
      await _fitVideoBounds(await windowManager.getBounds());
      // Fitting the restored video window can update its child viewport again.
      await _setFullscreenFrame(false);
    }
    screenFullscreen = fullscreen;
  }

  Future<void> _switchScreenFullscreen(bool fullscreen) => _serial(() async {
    if (screenFullscreen == fullscreen) return;
    var previous = screenFullscreen;
    _dragOrigin = null;
    _dragCursor = null;
    _dragTarget = null;
    var visible = Platform.isWindows || await windowManager.isVisible();
    if (Platform.isWindows) {
      await _frameChannel.invokeMethod<void>('beginFullscreenTransition');
    } else if (visible) {
      await windowManager.hide();
    }
    try {
      await _applyScreenFullscreen(fullscreen);
      if (!_disposed) notifyListeners();
      if (Platform.isWindows) {
        // Cloaking preserves frame production. Wait for Dart layout, then the
        // native raster callback reveals the completed frame without a sleep.
        await WidgetsBinding.instance.endOfFrame.timeout(
          const Duration(seconds: 2),
        );
        await _frameChannel.invokeMethod<void>('finishFullscreenTransition');
      }
    } catch (_) {
      try {
        await _applyScreenFullscreen(previous);
      } catch (error) {
        BTLogTool.warn('恢复播放器窗口模式失败：$error');
      }
      rethrow;
    } finally {
      if (Platform.isWindows) {
        await _frameChannel.invokeMethod<void>('abortFullscreenTransition');
      } else if (visible && !_disposed) {
        await windowManager.show();
      }
    }
  });

  Future<void> enterScreenFullscreen() => _switchScreenFullscreen(true);

  Future<void> exitScreenFullscreen() => _switchScreenFullscreen(false);

  /// 拖动窗口。系统移动循环（`SC_MOVE`）在拖动过程中无法限制位置，因此播放器
  /// 窗口自己按光标位移移动窗口，并在移动过程中就把它限制在所在屏幕内。
  /// 用光标屏幕坐标而不是手势坐标：窗口跟随光标移动后，手势坐标会随之漂移。
  Future<void> beginDrag() async {
    if (_disposed || transitioning || screenFullscreen) return;
    try {
      var bounds = await windowManager.getBounds();
      _dragOrigin = bounds;
      _dragCursor = await screenRetriever.getCursorScreenPoint();
      // 显示器可用区域在拖动开始时取一次，拖动过程中只在本地换算。
      _dragAreas = await _displayAreas();
      if (_disposed || transitioning || screenFullscreen) {
        _dragOrigin = null;
        _dragCursor = null;
        _dragAreas = const [];
        return;
      }
      _dragTarget = null;
      _dragHandedOff = false;
      _lastCursorY = null;
      await releaseRatioLock();
    } catch (error) {
      _dragOrigin = null;
      _dragCursor = null;
      _dragAreas = const [];
      BTLogTool.warn('开始拖动播放器窗口失败：$error');
    }
  }

  /// 拖动中：窗口位置 = 起始位置 + 光标位移，并按光标所在屏幕钳制，过程中
  /// 就不会越出屏幕。高频事件只保留最新位置，避免平台调用堆积。
  Future<void> updateDrag() async {
    var origin = _dragOrigin;
    var start = _dragCursor;
    if (_disposed ||
        transitioning ||
        screenFullscreen ||
        _dragHandedOff ||
        origin == null ||
        start == null) {
      return;
    }
    try {
      var cursor = await screenRetriever.getCursorScreenPoint();
      if (_disposed || transitioning || screenFullscreen) return;
      var area = _areaForPoint(cursor);
      var left = origin.left + (cursor.dx - start.dx);
      var top = origin.top + (cursor.dy - start.dy);
      if (area != null && origin.width <= area.width) {
        left = left.clamp(area.left, area.right - origin.width);
      }
      if (area != null && origin.height <= area.height) {
        top = top.clamp(area.top, area.bottom - origin.height);
      }
      _dragTarget = Offset(left, top);
      await _flushDrag();
      // 光标贴到屏幕顶端时把拖动交还系统：Windows 的“拖到顶端唤起吸附布局”
      // 与最大化预览只在系统移动循环里出现。要求光标确实在向上移动，避免
      // 窗口本来就贴顶、只是横向拖动时被误触发。
      var movingUp = _lastCursorY != null && cursor.dy < _lastCursorY! - 1.5;
      _lastCursorY = cursor.dy;
      if (area != null &&
          movingUp &&
          cursor.dy <= area.top + _systemDragTopBand) {
        await _handoffToSystemDrag();
      }
    } catch (error) {
      BTLogTool.warn('移动播放器窗口失败：$error');
    }
  }

  /// 把当前拖动交给系统移动循环（`SC_MOVE | HTCAPTION`）。调用会在系统移动
  /// 结束（松手）后返回，之后按用户结果做收尾。
  ///
  /// 交还后**不再**钳制窗口位置：系统移动循环把窗口推到屏幕外时，如果同时
  /// 用定时器把窗口拉回来，两个写入方会让窗口在溢出位与修正位之间抖动
  /// （Windows 上 Dart 定时器粒度约 15.6ms，无法压到一帧内）。取舍是保留
  /// Windows 原生吸附布局条，允许交还期间拖出屏幕，松手时统一收回屏内。
  Future<void> _handoffToSystemDrag() async {
    if (_disposed || transitioning || screenFullscreen || _dragHandedOff) {
      return;
    }
    _dragHandedOff = true;
    try {
      await windowManager.startDragging();
    } catch (error) {
      BTLogTool.warn('交给系统拖动播放器窗口失败：$error');
    } finally {
      _dragOrigin = null;
      _dragCursor = null;
      _dragAreas = const [];
      _dragTarget = null;
      _lastCursorY = null;
      markUserSized();
      await settleAfterUserBoundsChange();
    }
  }

  Future<void> _flushDrag() async {
    if (_dragWriting) return;
    _dragWriting = true;
    try {
      while (_dragTarget != null && !transitioning && !screenFullscreen) {
        var next = _dragTarget!;
        _dragTarget = null;
        await windowManager.setPosition(next);
      }
    } catch (error) {
      BTLogTool.warn('写入播放器窗口位置失败：$error');
    } finally {
      _dragWriting = false;
    }
  }

  /// 结束拖动：窗口已在屏幕内，这里只做尺寸与比例的收尾。交还给系统拖动后
  /// 手势结束事件可能不再到达，因此这条路径必须可重复执行。
  Future<void> endDrag() async {
    if (_dragHandedOff) return;
    _dragOrigin = null;
    _dragCursor = null;
    _dragAreas = const [];
    _dragTarget = null;
    _lastCursorY = null;
    if (_disposed) return;
    markUserSized();
    await settleAfterUserBoundsChange();
  }

  /// 拖动窗口边缘调整大小：只有这段时间加比例锁。原生 `startResizing` 是
  /// `PostMessage`，调用立即返回，因此锁由缩放结束的窗口事件释放
  /// （`onWindowResized` → [releaseRatioLock]）。
  Future<void> beginResize(ResizeEdge edge) async {
    if (_disposed || transitioning || screenFullscreen) return;
    await windowManager.setAspectRatio(_aspectRatio);
    if (_disposed || transitioning || screenFullscreen) return;
    await windowManager.startResizing(edge);
  }

  /// 释放比例锁。窗口尺寸本身已按视频比例算好，持久加锁只会让系统吸附、
  /// 最大化与自由调整都被拉回视频比例。
  Future<void> releaseRatioLock() async {
    if (_disposed) return;
    try {
      await windowManager.setAspectRatio(0);
    } catch (error) {
      BTLogTool.warn('释放播放器窗口比例锁失败：$error');
    }
  }

  /// 用户拖动/缩放/吸附结束后：先释放比例锁，再把窗口收回所在屏幕内。
  Future<void> settleAfterUserBoundsChange() => _serial(() async {
    if (screenFullscreen) return;
    await releaseRatioLock();
    await _containToScreen();
  });

  /// 不允许窗口溢出显示屏幕：屏幕能完整容纳整个窗口时把它整体收回屏幕内，
  /// 容不下时只在窗口完全跑到屏幕外时拉回来，避免窗口丢失。
  Future<void> _containToScreen() async {
    if (_disposed || screenFullscreen) return;
    try {
      if (await windowManager.isMaximized() ||
          await windowManager.isMinimized() ||
          await windowManager.isFullScreen()) {
        return;
      }
      var bounds = await windowManager.getBounds();
      var area = await _workArea(bounds);
      if (bounds.width > area.width || bounds.height > area.height) {
        if (bounds.overlaps(area)) return;
        await windowManager.setBounds(
          Rect.fromLTWH(area.left, area.top, bounds.width, bounds.height),
        );
        return;
      }
      var left = bounds.left.clamp(area.left, area.right - bounds.width);
      var top = bounds.top.clamp(area.top, area.bottom - bounds.height);
      if ((left - bounds.left).abs() < 0.5 && (top - bounds.top).abs() < 0.5) {
        return;
      }
      await windowManager.setBounds(
        Rect.fromLTWH(left, top, bounds.width, bounds.height),
      );
    } catch (error) {
      BTLogTool.warn('把播放器窗口收回屏幕失败：$error');
    }
  }

  Future<void> minimize() => windowManager.minimize();
  Future<void> closeWindow() => windowManager.close();

  /// 采用已保存的置顶偏好；启动阶段不回写同一值。
  void restoreOnTop(PlaybackOnTop value) {
    if (_disposed || _onTop == value) return;
    _onTop = value;
    notifyListeners();
    unawaited(_applyOnTop().catchError((Object _) {}));
  }

  /// 切换置顶策略。播放时置顶还要跟随播放状态，两处变化都落到同一个原生调用。
  Future<void> setOnTop(PlaybackOnTop value) async {
    if (_disposed || _onTop == value) return;
    _onTop = value;
    notifyListeners();
    await _applyOnTop();
    try {
      await persistOnTop?.call(value);
    } catch (error) {
      BTLogTool.warn('保存播放器置顶偏好失败：$error');
    }
  }

  void updatePlaying(bool value) {
    if (_disposed || _playing == value) return;
    _playing = value;
    unawaited(_applyOnTop().catchError((Object _) {}));
  }

  Future<void> _applyOnTop() async {
    if (_disposed) return;
    var pinned =
        _onTop == PlaybackOnTop.always ||
        (_onTop == PlaybackOnTop.playing && _playing);
    if (pinned == _onTopApplied) return;
    _onTopApplied = pinned;
    if (Platform.isWindows) {
      // This preference is the only reason the native window enters the topmost
      // band. Fullscreen keeps the ordinary band so the shell hides the taskbar
      // while overlay layers such as the NVIDIA one stay above the video.
      await _frameChannel.invokeMethod<void>('setAlwaysOnTop', pinned);
    } else {
      await windowManager.setAlwaysOnTop(pinned);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Resize hit targets overlay the video rather than reserving window borders.
/// Dragging one of them goes through [PlaybackWindowMode.beginResize], which is
/// the only place the video aspect ratio is locked.
class PlaybackWindowResizeFrame extends StatelessWidget {
  const PlaybackWindowResizeFrame({
    super.key,
    required this.child,
    required this.onResizeStart,
  });
  final Widget child;
  final void Function(ResizeEdge edge) onResizeStart;

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
              onPanStart: (_) => onResizeStart(edge),
            ),
          ),
        ),
    ],
  );
}
