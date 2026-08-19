// Dart imports:
import 'dart:async';
import 'dart:io';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

// Project imports:
import '../../tools/log_tool.dart';

/// 托盘原生能力抽象，便于在单元测试中替换 MethodChannel。
abstract interface class BTTrayAdapter {
  /// 注册托盘事件监听器。
  void addListener(TrayListener listener);

  /// 移除托盘事件监听器。
  void removeListener(TrayListener listener);

  /// 设置托盘图标。
  Future<void> setIcon(String iconPath);

  /// 设置托盘提示文本。
  Future<void> setToolTip(String toolTip);

  /// 设置托盘右键菜单。
  Future<void> setContextMenu(Menu menu);

  /// 弹出托盘右键菜单。
  Future<void> popUpContextMenu();

  /// 销毁托盘图标。
  Future<void> destroy();
}

/// [tray_manager] 的默认适配器。
class _TrayManagerAdapter implements BTTrayAdapter {
  @override
  void addListener(TrayListener listener) => trayManager.addListener(listener);

  @override
  void removeListener(TrayListener listener) {
    trayManager.removeListener(listener);
  }

  @override
  Future<void> setIcon(String iconPath) => trayManager.setIcon(iconPath);

  @override
  Future<void> setToolTip(String toolTip) => trayManager.setToolTip(toolTip);

  @override
  Future<void> setContextMenu(Menu menu) => trayManager.setContextMenu(menu);

  @override
  Future<void> popUpContextMenu() => trayManager.popUpContextMenu();

  @override
  Future<void> destroy() => trayManager.destroy();
}

/// 窗口原生能力抽象，便于在单元测试中替换 [windowManager]。
abstract interface class BTWindowAdapter {
  /// 注册窗口事件监听器。
  void addListener(WindowListener listener);

  /// 移除窗口事件监听器。
  void removeListener(WindowListener listener);

  /// 设置是否拦截原生关闭事件。
  Future<void> setPreventClose(bool value);

  /// 显示窗口并恢复最小化状态。
  Future<void> show();

  /// 聚焦窗口。
  Future<void> focus();

  /// 隐藏窗口。
  Future<void> hide();
}

/// [window_manager] 的默认适配器。
class _WindowManagerAdapter implements BTWindowAdapter {
  @override
  void addListener(WindowListener listener) =>
      windowManager.addListener(listener);

  @override
  void removeListener(WindowListener listener) {
    windowManager.removeListener(listener);
  }

  @override
  Future<void> setPreventClose(bool value) =>
      windowManager.setPreventClose(value);

  @override
  Future<void> show() => windowManager.show();

  @override
  Future<void> focus() => windowManager.focus();

  @override
  Future<void> hide() => windowManager.hide();
}

/// 桌面托盘与主窗口生命周期服务。
///
/// 托盘监听器只在本服务中注册，页面通过初始化时注入的回调完成导航，避免
/// 原生生命周期与 Flutter 页面互相持有。
class BTDesktopTrayService with TrayListener, WindowListener {
  /// 创建默认的桌面托盘服务。
  BTDesktopTrayService()
    : _tray = _TrayManagerAdapter(),
      _window = _WindowManagerAdapter(),
      _isSupported = Platform.isWindows || Platform.isMacOS,
      _isWindows = Platform.isWindows,
      _now = DateTime.now,
      _doubleClickWindow = const Duration(milliseconds: 500);

  BTDesktopTrayService._({
    required BTTrayAdapter tray,
    required BTWindowAdapter window,
    required bool isSupported,
    required bool isWindows,
    required DateTime Function() now,
    required Duration doubleClickWindow,
  }) : _tray = tray,
       _window = window,
       _isSupported = isSupported,
       _isWindows = isWindows,
       _now = now,
       _doubleClickWindow = doubleClickWindow;

  /// 用于测试的构造函数。
  @visibleForTesting
  BTDesktopTrayService.forTesting({
    required BTTrayAdapter tray,
    required BTWindowAdapter window,
    bool isSupported = true,
    bool isWindows = true,
    DateTime Function()? now,
    Duration doubleClickWindow = const Duration(milliseconds: 500),
  }) : this._(
         tray: tray,
         window: window,
         isSupported: isSupported,
         isWindows: isWindows,
         now: now ?? DateTime.now,
         doubleClickWindow: doubleClickWindow,
       );

  /// 全局服务实例。
  static final BTDesktopTrayService instance = BTDesktopTrayService();

  static const String showMainKey = 'show_main';
  static const String openBmfKey = 'open_bmf';
  static const String openDownloadKey = 'open_download';
  static const String exitAppKey = 'exit_app';

  final BTTrayAdapter _tray;
  final BTWindowAdapter _window;
  final bool _isSupported;
  final bool _isWindows;
  final DateTime Function() _now;
  final Duration _doubleClickWindow;

  Future<bool> Function()? _readMinimizeToTray;
  Future<void> Function()? _onOpenMain;
  Future<void> Function()? _onOpenBmf;
  Future<void> Function()? _onOpenDownload;
  Future<void> Function()? _onExit;

  bool _initialized = false;
  bool _trayCreated = false;
  bool _listenersRegistered = false;
  bool _closePrevented = false;
  bool _windowActionInProgress = false;
  bool _closeActionInProgress = false;
  bool _exitRequested = false;
  DateTime? _lastLeftClick;
  Menu? _menu;
  Future<void>? _contextMenuFuture;

  /// 服务是否已完成托盘初始化。
  bool get isInitialized => _initialized;

  /// 当前生成的菜单，仅供测试检查菜单项。
  @visibleForTesting
  Menu? get menu => _menu;

  /// 初始化托盘、菜单和窗口关闭拦截。
  ///
  /// 只有图标、菜单和监听器全部准备成功后才启用窗口关闭拦截；初始化失败
  /// 会向上抛出，由启动流程记录并继续显示普通窗口。
  Future<void> initialize({
    required Future<bool> Function() readMinimizeToTray,
    required Future<void> Function() onOpenMain,
    required Future<void> Function() onOpenBmf,
    Future<void> Function()? onOpenDownload,
    required Future<void> Function() onExit,
    String windowsIconPath = 'assets/images/tray/tray_icon.ico',
    String macIconPath = 'assets/images/tray/tray_icon.png',
  }) async {
    if (!_isSupported || _initialized) return;
    if (_isWindows && onOpenDownload == null) {
      throw ArgumentError(
        'Windows tray requires a download navigation callback',
      );
    }

    _readMinimizeToTray = readMinimizeToTray;
    _onOpenMain = onOpenMain;
    _onOpenBmf = onOpenBmf;
    _onOpenDownload = onOpenDownload;
    _onExit = onExit;
    _lastLeftClick = null;
    _contextMenuFuture = null;
    _exitRequested = false;

    try {
      await _tray.setIcon(_isWindows ? windowsIconPath : macIconPath);
      _trayCreated = true;
      await _tray.setToolTip('BangumiToday');
      _menu = _buildMenu();
      await _tray.setContextMenu(_menu!);

      _tray.addListener(this);
      _window.addListener(this);
      _listenersRegistered = true;
      await _window.setPreventClose(true);
      _closePrevented = true;
      _initialized = true;
      BTLogTool.info('系统托盘初始化完成');
    } catch (error, stackTrace) {
      await _cleanupAfterFailedInitialize();
      BTLogTool.error(['系统托盘初始化失败', error.toString(), stackTrace.toString()]);
      rethrow;
    }
  }

  Menu _buildMenu() {
    var items = <MenuItem>[
      MenuItem(key: showMainKey, label: '打开主界面'),
      MenuItem.separator(),
      MenuItem(key: openBmfKey, label: 'BMF'),
    ];
    if (_isWindows) {
      items.add(MenuItem(key: openDownloadKey, label: '下载'));
    }
    items.addAll([
      MenuItem.separator(),
      MenuItem(key: exitAppKey, label: '退出应用'),
    ]);
    return Menu(items: items);
  }

  Future<void> _cleanupAfterFailedInitialize() async {
    if (_listenersRegistered) {
      _tray.removeListener(this);
      _window.removeListener(this);
      _listenersRegistered = false;
    }
    if (_closePrevented) {
      await _setPreventCloseSafely(false);
      _closePrevented = false;
    }
    if (_trayCreated) {
      await _destroyTraySafely();
      _trayCreated = false;
    }
    _menu = null;
  }

  /// 注销监听器、关闭关闭拦截并销毁托盘图标。
  Future<void> dispose() async {
    _lastLeftClick = null;
    _contextMenuFuture = null;
    _initialized = false;
    if (_listenersRegistered) {
      _tray.removeListener(this);
      _window.removeListener(this);
      _listenersRegistered = false;
    }
    if (_closePrevented) {
      await _setPreventCloseSafely(false);
      _closePrevented = false;
    }
    if (_trayCreated) {
      await _destroyTraySafely();
      _trayCreated = false;
    }
    _menu = null;
  }

  Future<void> _setPreventCloseSafely(bool value) async {
    try {
      await _window.setPreventClose(value);
    } catch (error, stackTrace) {
      BTLogTool.warn([
        '设置窗口关闭拦截失败',
        value.toString(),
        error.toString(),
        stackTrace.toString(),
      ]);
    }
  }

  Future<void> _destroyTraySafely() async {
    try {
      await _tray.destroy();
    } catch (error, stackTrace) {
      BTLogTool.warn(['销毁系统托盘失败', error.toString(), stackTrace.toString()]);
    }
  }

  @override
  void onTrayIconMouseDown() {
    if (!_initialized || _exitRequested) return;
    var now = _now();
    var previous = _lastLeftClick;
    if (previous != null &&
        now.difference(previous) >= Duration.zero &&
        now.difference(previous) <= _doubleClickWindow) {
      _lastLeftClick = null;
      unawaited(_showMainWindow());
      return;
    }
    _lastLeftClick = now;
  }

  @override
  void onTrayIconRightMouseDown() {
    if (!_initialized || _exitRequested) return;
    _lastLeftClick = null;
    var menuFuture = _showContextMenu();
    _contextMenuFuture = menuFuture;
    unawaited(menuFuture);
  }

  Future<void> _showContextMenu() async {
    try {
      await _tray.popUpContextMenu();
    } catch (error, stackTrace) {
      BTLogTool.warn(['打开系统托盘菜单失败', error.toString(), stackTrace.toString()]);
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (!_initialized || _exitRequested) return;
    _lastLeftClick = null;
    switch (menuItem.key) {
      case showMainKey:
        unawaited(_showMainWindow());
        return;
      case openBmfKey:
        unawaited(_openPage(_onOpenBmf));
        return;
      case openDownloadKey:
        unawaited(_openPage(_onOpenDownload));
        return;
      case exitAppKey:
        unawaited(_requestExit());
        return;
    }
  }

  Future<void> _openPage(Future<void> Function()? callback) async {
    if (callback == null || _windowActionInProgress) return;
    _windowActionInProgress = true;
    try {
      await callback();
      await _showWindow();
    } catch (error, stackTrace) {
      BTLogTool.error(['托盘导航失败', error.toString(), stackTrace.toString()]);
    } finally {
      _windowActionInProgress = false;
    }
  }

  Future<void> _showMainWindow() async {
    if (_windowActionInProgress) return;
    _windowActionInProgress = true;
    try {
      await _onOpenMain?.call();
      await _showWindow();
    } catch (error, stackTrace) {
      BTLogTool.error(['显示主窗口失败', error.toString(), stackTrace.toString()]);
    } finally {
      _windowActionInProgress = false;
    }
  }

  Future<void> _showWindow() async {
    await _window.show();
    await _window.focus();
  }

  @override
  void onWindowClose() {
    if (!_initialized || _closeActionInProgress || _exitRequested) return;
    unawaited(_handleWindowClose());
  }

  Future<void> _handleWindowClose() async {
    if (_closeActionInProgress || _exitRequested) return;
    _closeActionInProgress = true;
    try {
      var minimizeToTray = true;
      try {
        minimizeToTray = await _readMinimizeToTray!();
      } catch (error, stackTrace) {
        BTLogTool.warn([
          '读取关闭后最小化到托盘配置失败，按默认开启处理',
          error.toString(),
          stackTrace.toString(),
        ]);
      }
      if (minimizeToTray) {
        await _window.hide();
      } else {
        await _requestExit();
      }
    } catch (error, stackTrace) {
      BTLogTool.error(['处理窗口关闭事件失败', error.toString(), stackTrace.toString()]);
    } finally {
      _closeActionInProgress = false;
    }
  }

  Future<void> _requestExit() async {
    if (_exitRequested) return;
    _exitRequested = true;
    try {
      // tray_manager 在 Windows 上用 TrackPopupMenu 弹出菜单，该方法会卡住
      // 平台线程直到菜单关闭。菜单点击回调会在这段嵌套消息循环里送达，
      // 此时若立刻 hide/destroy 窗口或托盘，主窗体会无响应直到菜单返回。
      await _waitForContextMenuToClose();
      await _hideWindowSafely();
      await _onExit?.call();
    } catch (error, stackTrace) {
      _exitRequested = false;
      BTLogTool.error(['退出应用失败', error.toString(), stackTrace.toString()]);
    }
  }

  Future<void> _waitForContextMenuToClose() async {
    var menuFuture = _contextMenuFuture;
    if (menuFuture == null) return;
    try {
      await menuFuture.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      BTLogTool.warn('等待系统托盘菜单关闭超时，继续退出');
    } catch (_) {}
  }

  Future<void> _hideWindowSafely() async {
    try {
      await _window.hide();
    } catch (error, stackTrace) {
      BTLogTool.warn(['退出前隐藏主窗口失败', error.toString(), stackTrace.toString()]);
    }
  }
}
