// Dart imports:
import 'dart:async';
import 'dart:io';
import 'dart:ui';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

// Project imports:
import 'app.dart';
import 'core/cache/cache_manager.dart';
import 'core/cache/lru_cache_manager.dart';
import 'core/services/app_link_service.dart';
import 'core/services/bmf_rss_service.dart';
import 'core/services/bt_engine_client.dart';
import 'core/services/desktop_tray_service.dart';
import 'core/utils/window_effect.dart';
import 'database/app/app_config.dart';
import 'database/bt_sqlite.dart';
import 'request/bangumi/bangumi_api.dart';
import 'store/nav_store.dart';
import 'store/tracker_hive.dart';
import 'tools/download_tool.dart';
import 'tools/hive_tool.dart';
import 'tools/log_tool.dart';
import 'tools/notifier_tool.dart';
import 'widgets/app/app_splash.dart';

final globalContainer = ProviderContainer();
bool _applicationExitStarted = false;

Future<void> main() async {
  if (const bool.fromEnvironment('ENABLE_FLUTTER_DRIVER')) {
    enableFlutterDriverExtension();
  }

  WidgetsFlutterBinding.ensureInitialized();
  _configureErrorHandling();
  AppLifecycleListener(
    onExitRequested: () async {
      await _exitApplication();
      return AppExitResponse.exit;
    },
  );

  await Future.wait([
    windowManager.ensureInitialized(),
    Window.initialize(),
    SystemTheme.accentColor.load(),
  ]);

  // 首帧前读取主题模式并应用窗口材质，让启动加载页与窗口背景在深浅主题下
  // 都与应用主题一致，避免启动阶段先出现白屏。
  var themeMode = ThemeMode.system;
  try {
    await BTLogTool.init();
    await BTSqlite.init();
    themeMode = await BtsAppConfig().readThemeMode();
    await applyWindowMaterial(dark: _resolveDark(themeMode));
  } catch (error, stackTrace) {
    _reportUnhandledError(error, stackTrace);
  }

  WindowOptions windowOpts = const WindowOptions(
    title: kDebugMode ? 'BangumiToday[Dev]' : 'BangumiToday',
    size: Size(1280, 720),
    center: true,
  );
  await windowManager.waitUntilReadyToShow(
    (windowOpts),
    () async => await windowManager.show(),
  );

  _runApp(BTSplashScreen(themeMode: themeMode));

  try {
    await _initBackgroundServices();
    await _initDesktopTray();
    _runApp(const BTApp());
  } catch (error, stackTrace) {
    _reportUnhandledError(error, stackTrace);
    _runApp(
      BTSplashScreen(errorMessage: error.toString(), themeMode: themeMode),
    );
  }
}

Future<void> _initDesktopTray() async {
  await _runOptionalService('系统托盘', () async {
    await BTDesktopTrayService.instance.initialize(
      readMinimizeToTray: BtsAppConfig().readMinimizeToTray,
      onOpenMain: () async {},
      onOpenBmf: () async {
        globalContainer.read(navStoreProvider).goToBmf();
      },
      onOpenDownload: Platform.isWindows
          ? () async {
              globalContainer.read(navStoreProvider).goToDownload();
            }
          : null,
      onExit: _exitApplication,
    );
  });
}

Future<void> _exitApplication() async {
  if (_applicationExitStarted) return;
  _applicationExitStarted = true;
  await _runExitStep('BMF RSS 服务', () async {
    BmfRssService.instance.stop();
  });
  await _runExitStep('App Link 服务', AppLinkService.instance.dispose);
  await _runExitStep('BT 下载引擎', BtEngineClient.instance.shutdown);
  await _runExitStep('系统托盘', BTDesktopTrayService.instance.dispose);
  await _runExitStep('主窗口', windowManager.destroy);
}

Future<void> _runExitStep(String name, Future<void> Function() action) async {
  try {
    await action();
  } catch (error, stackTrace) {
    BTLogTool.error(['$name 退出清理失败', error.toString(), stackTrace.toString()]);
  }
}

/// 根据主题模式解析窗口深浅色
bool _resolveDark(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark,
  };
}

Future<void> _initBackgroundServices() async {
  await BTLogTool.init();

  await BTSqlite.init();
  var appConfig = BtsAppConfig();
  BtrBangumiApi.setBaseUrl(await appConfig.readBangumiUrl());
  await BTHiveTool.init();
  var btDownloadConfig = await appConfig.readBtDownloadConfig();
  var themeMode = await appConfig.readThemeMode();
  var trackerStore = TrackerHive();

  await Future.wait([
    _runOptionalService('下载服务', BTDownloadTool.init),
    _runOptionalService('通知服务', BTNotifierTool.init),
    if (Platform.isWindows && btDownloadConfig.engineEnabled)
      _runOptionalService(
        'BT 下载引擎',
        () => BtEngineClient.instance.start(
          config: btDownloadConfig.toEngineJson(
            additionalTrackers: trackerStore.effectiveTrackers,
          ),
        ),
      ),
  ]);

  if (Platform.isWindows) {
    unawaited(_runOptionalService('Tracker 自动更新', trackerStore.checkUpdate));
  }

  await Future.wait([
    _runOptionalService('应用缓存', BTCacheManager.instance.init),
    _runOptionalService('LRU 缓存', LRUCacheManager.instance.init),
  ]);

  await _runOptionalService(
    '窗口特效',
    () => applyWindowMaterial(
      dark: switch (themeMode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          PlatformDispatcher.instance.platformBrightness == Brightness.dark,
      },
    ),
  );

  // Let the first frame become interactive before the bulk RSS refresh.
  unawaited(
    Future<void>.delayed(
      const Duration(seconds: 3),
      () => _runOptionalService('BMF RSS 服务', BmfRssService.instance.start),
    ),
  );
}

void _runApp(Widget child) {
  runApp(UncontrolledProviderScope(container: globalContainer, child: child));
}

Future<void> _runOptionalService(
  String name,
  Future<void> Function() initialize,
) async {
  try {
    await initialize();
  } catch (error, stackTrace) {
    BTLogTool.error(['$name 初始化失败', error.toString(), stackTrace.toString()]);
  }
}

void _configureErrorHandling() {
  // 桌面集成测试由测试绑定接管错误上报，避免与应用的全局错误处理器冲突。
  // 通过 `--dart-define=BANGUMI_INTEGRATION_TEST=true` 显式开启。
  if (const bool.fromEnvironment('BANGUMI_INTEGRATION_TEST')) return;
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _reportUnhandledError(
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    _reportUnhandledError(error, stackTrace);
    return true;
  };
}

void _reportUnhandledError(Object error, StackTrace stackTrace) {
  if (BTLogTool.isInitialized) {
    BTLogTool.error(['未处理异常', error.toString(), stackTrace.toString()]);
    return;
  }

  debugPrint(BTLogTool.sanitize('未处理异常: $error\n$stackTrace'));
}
