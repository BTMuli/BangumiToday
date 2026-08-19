// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

// Project imports:
import 'package:bangumi_today/core/services/desktop_tray_service.dart';

void main() {
  late _FakeTrayAdapter tray;
  late _FakeWindowAdapter window;
  late BTDesktopTrayService service;

  setUp(() {
    tray = _FakeTrayAdapter();
    window = _FakeWindowAdapter();
    service = BTDesktopTrayService.forTesting(
      tray: tray,
      window: window,
      isWindows: true,
    );
  });

  tearDown(() async {
    await service.dispose();
  });

  Future<void> initialize({
    bool minimizeToTray = true,
    Future<void> Function()? onOpenMain,
    Future<void> Function()? onOpenBmf,
    Future<void> Function()? onOpenDownload,
    Future<void> Function()? onExit,
  }) {
    return service.initialize(
      readMinimizeToTray: () async => minimizeToTray,
      onOpenMain: onOpenMain ?? () async {},
      onOpenBmf: onOpenBmf ?? () async {},
      onOpenDownload: onOpenDownload ?? () async {},
      onExit: onExit ?? () async {},
    );
  }

  Future<void> flushCallbacks() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('initializes tray menu and close interception', () async {
    await initialize();

    expect(service.isInitialized, isTrue);
    expect(tray.iconPath, 'assets/images/tray/tray_icon.ico');
    expect(tray.toolTip, 'BangumiToday');
    expect(window.preventCloseValues, [true]);
    expect(tray.menu?.items?.map((item) => item.key), [
      BTDesktopTrayService.showMainKey,
      null,
      BTDesktopTrayService.openBmfKey,
      BTDesktopTrayService.openDownloadKey,
      null,
      BTDesktopTrayService.exitAppKey,
    ]);
  });

  test('double click opens and focuses the main window', () async {
    var now = DateTime(2026, 1, 1);
    service = BTDesktopTrayService.forTesting(
      tray: tray,
      window: window,
      isWindows: true,
      now: () => now,
    );
    var mainOpened = 0;
    await initialize(onOpenMain: () async => mainOpened++);

    service.onTrayIconMouseDown();
    await flushCallbacks();
    expect(window.showCount, 0);

    now = now.add(const Duration(milliseconds: 300));
    service.onTrayIconMouseDown();
    await flushCallbacks();

    expect(mainOpened, 1);
    expect(window.showCount, 1);
    expect(window.focusCount, 1);
  });

  test('right click opens the context menu', () async {
    await initialize();

    service.onTrayIconRightMouseDown();
    await flushCallbacks();

    expect(tray.popupCount, 1);
  });

  test('close hides the window when the setting is enabled', () async {
    await initialize();

    service.onWindowClose();
    await flushCallbacks();

    expect(window.hideCount, 1);
    expect(window.destroyCount, 0);
  });

  test(
    'close requests application exit when the setting is disabled',
    () async {
      var exitCount = 0;
      await initialize(minimizeToTray: false, onExit: () async => exitCount++);

      service.onWindowClose();
      await flushCallbacks();
      service.onWindowClose();
      await flushCallbacks();

      expect(exitCount, 1);
      expect(window.hideCount, 1);
    },
  );

  test('exit menu item hides the window then requests exit', () async {
    var exitCount = 0;
    await initialize(onExit: () async => exitCount++);

    service.onTrayMenuItemClick(
      tray.menu!.getMenuItem(BTDesktopTrayService.exitAppKey)!,
    );
    await flushCallbacks();

    expect(window.hideCount, 1);
    expect(exitCount, 1);
  });

  test('exit waits for the tray menu to close before tearing down', () async {
    var menu = Completer<void>();
    tray.popUpBarrier = menu;
    var exitCount = 0;
    await initialize(onExit: () async => exitCount++);

    service.onTrayIconRightMouseDown();
    await flushCallbacks();
    expect(tray.popupCount, 1);

    service.onTrayMenuItemClick(
      tray.menu!.getMenuItem(BTDesktopTrayService.exitAppKey)!,
    );
    await flushCallbacks();
    expect(exitCount, 0);
    expect(window.hideCount, 0);

    menu.complete();
    await flushCallbacks();

    expect(window.hideCount, 1);
    expect(exitCount, 1);
  });

  test('menu commands navigate and show the window', () async {
    var bmfCount = 0;
    var downloadCount = 0;
    await initialize(
      onOpenBmf: () async => bmfCount++,
      onOpenDownload: () async => downloadCount++,
    );

    service.onTrayMenuItemClick(
      tray.menu!.getMenuItem(BTDesktopTrayService.openBmfKey)!,
    );
    await flushCallbacks();
    expect(bmfCount, 1);
    expect(window.showCount, 1);

    service.onTrayMenuItemClick(
      tray.menu!.getMenuItem(BTDesktopTrayService.openDownloadKey)!,
    );
    await flushCallbacks();
    expect(downloadCount, 1);
    expect(window.showCount, 2);
  });

  test('macOS menu does not expose the Windows download entry', () async {
    service = BTDesktopTrayService.forTesting(
      tray: tray,
      window: window,
      isWindows: false,
    );
    await initialize(onOpenDownload: null);

    expect(
      tray.menu?.getMenuItem(BTDesktopTrayService.openDownloadKey),
      isNull,
    );
  });
}

class _FakeTrayAdapter implements BTTrayAdapter {
  TrayListener? listener;
  Menu? menu;
  String? iconPath;
  String? toolTip;
  Completer<void>? popUpBarrier;
  int popupCount = 0;
  int destroyCount = 0;

  @override
  void addListener(TrayListener listener) {
    this.listener = listener;
  }

  @override
  void removeListener(TrayListener listener) {
    if (identical(this.listener, listener)) this.listener = null;
  }

  @override
  Future<void> setIcon(String iconPath) async {
    this.iconPath = iconPath;
  }

  @override
  Future<void> setToolTip(String toolTip) async {
    this.toolTip = toolTip;
  }

  @override
  Future<void> setContextMenu(Menu menu) async {
    this.menu = menu;
  }

  @override
  Future<void> popUpContextMenu() async {
    popupCount++;
    var barrier = popUpBarrier;
    if (barrier != null) await barrier.future;
  }

  @override
  Future<void> destroy() async {
    destroyCount++;
  }
}

class _FakeWindowAdapter implements BTWindowAdapter {
  WindowListener? listener;
  final List<bool> preventCloseValues = [];
  int showCount = 0;
  int focusCount = 0;
  int hideCount = 0;
  int destroyCount = 0;

  @override
  void addListener(WindowListener listener) {
    this.listener = listener;
  }

  @override
  void removeListener(WindowListener listener) {
    if (identical(this.listener, listener)) this.listener = null;
  }

  @override
  Future<void> setPreventClose(bool value) async {
    preventCloseValues.add(value);
  }

  @override
  Future<void> show() async {
    showCount++;
  }

  @override
  Future<void> focus() async {
    focusCount++;
  }

  @override
  Future<void> hide() async {
    hideCount++;
  }
}
