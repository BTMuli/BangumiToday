// Dart imports:
import 'dart:async';
import 'dart:io';
import 'dart:ui';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

// Project imports:
import 'app.dart';
import 'core/cache/cache_manager.dart';
import 'core/container.dart';
import 'core/network/system_proxy.dart';
import 'core/services/app_link_service.dart';
import 'core/services/bangumi_oauth_coordinator.dart';
import 'core/services/bangumi_token_service.dart';
import 'core/services/bmf_rss_service.dart';
import 'core/services/bt_engine_client.dart';
import 'core/services/desktop_tray_service.dart';
import 'core/services/download_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/playback_shader_cache_service.dart';
import 'core/services/playback_window_service.dart';
import 'core/services/system_proxy_watch_service.dart';
import 'core/services/windows_app_protocol.dart';
import 'core/utils/window_effect.dart';
import 'database/app/app_config.dart';
import 'database/bt_hive.dart';
import 'database/bt_sqlite.dart';
import 'pages/playback/playback_window.dart';
import 'request/bangumi/bangumi_api.dart';
import 'request/core/client.dart';
import 'request/mikan/mikan_api.dart';
import 'store/bt_download_store.dart';
import 'store/nav_store.dart';
import 'store/playback_store.dart';
import 'store/tracker_hive.dart';
import 'tools/log_tool.dart';
import 'widgets/shell/splash.dart';

bool _applicationExitStarted = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 每个独立窗口都有自己的 Dart isolate，必须在分派入口前安装处理器。
  _configureErrorHandling();
  if (Platform.isWindows) {
    var window = await WindowController.fromCurrentEngine();
    if (window.arguments.isNotEmpty) {
      await startPlaybackWindow(window);
      return;
    }
  }
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
    if (Platform.isWindows) globalContainer.read(playbackWindowServiceProvider);
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
        globalContainer.read(navStoreProvider.notifier).goToBmf();
      },
      onOpenDownload: Platform.isWindows
          ? () async {
              globalContainer.read(navStoreProvider.notifier).goToDownload();
            }
          : null,
      onExit: _exitApplication,
    );
  });
}

Future<void> _exitApplication() async {
  if (_applicationExitStarted) return;
  _applicationExitStarted = true;
  // 先移除视频与控制条，使其取消流监听；隐藏窗口后可能不再绘制帧。
  await _runExitStep(
    '播放器',
    Platform.isWindows
        ? globalContainer.read(playbackWindowServiceProvider).shutdown
        : globalContainer.read(playbackStoreProvider).shutdown,
    // 播放器为队列、存储、界面与原生释放分别控制退出预算。
    timeout: null,
  );
  // 再藏窗、拆托盘，避免协议还原 / 引擎 shutdown 期间主窗体假死。
  await _runExitStep('隐藏主窗口', windowManager.hide);
  await _runExitStep('系统托盘', BTDesktopTrayService.instance.dispose);
  await _runExitStep('系统代理监听', SystemProxyWatchService.instance.stop);
  await _runExitStep('Shader 缓存维护', PlaybackShaderCacheService.instance.stop);
  await _runExitStep('Windows 协议还原', restoreWindowsAppProtocol);
  await _runExitStep('BMF RSS 服务', () async {
    BmfRssService.instance.stop();
  });
  await _runExitStep('App Link 服务', AppLinkService.instance.dispose);
  await _runExitStep(
    'BT 下载引擎',
    BtEngineClient.instance.shutdown,
    // shutdown 自己控制完整的退出预算，并在超时后终止、回收进程。
    timeout: null,
  );
  await _runExitStep('主窗口', windowManager.destroy);
}

Future<void> _runExitStep(
  String name,
  Future<void> Function() action, {
  Duration? timeout = const Duration(seconds: 5),
}) async {
  try {
    var step = action();
    await (timeout == null ? step : step.timeout(timeout));
  } on TimeoutException {
    BTLogTool.warn('$name 退出清理超时');
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
  unawaited(_runOptionalService('Windows 协议注册', registerWindowsAppProtocol));
  AppLinkService.instance.start();
  BangumiOAuthCoordinator.instance.attach();

  await BTSqlite.init();
  var appConfig = BtsAppConfig();
  BtrBangumiApi.setBaseUrl(await appConfig.readBangumiUrl());
  BtrMikanApi.setBaseUrl(await appConfig.readMikanUrl());
  await BtrClient.configureSystemProxy(await appConfig.readUseSystemProxy());
  await BTHiveTool.init();
  unawaited(
    _runOptionalService('Bangumi Token 预刷新', () async {
      await BangumiTokenService.instance.ensureFresh();
    }),
  );
  var btDownloadConfig = await appConfig.readBtDownloadConfig();
  var useDownloadSystemProxy = await appConfig.readUseDownloadSystemProxy();
  var themeMode = await appConfig.readThemeMode();
  var trackerStore = globalContainer.read(trackerStoreProvider.notifier);

  if (Platform.isWindows) {
    await _runOptionalService('系统代理监听', () async {
      await SystemProxyWatchService.instance.start(
        onChanged: (proxy) async {
          BtrClient.refreshSystemProxy(proxy);
          if (!await appConfig.readUseDownloadSystemProxy()) return;

          var engine = BtEngineClient.instance;
          if (engine.isReady) {
            await engine.configureProxy(proxy.toEngineJson(enabled: true));
          }
        },
      );
    });
  }

  unawaited(
    Future.wait([
      _runOptionalService('下载服务', BTDownloadTool.init),
      _runOptionalService('通知服务', BTNotifierTool.init),
      if (Platform.isWindows && btDownloadConfig.engineEnabled)
        _runOptionalService('BT 下载引擎', () async {
          await BtEngineClient.instance.start(
            config: btDownloadConfig.toEngineJson(
              additionalTrackers: trackerStore.effectiveTrackers,
            ),
            proxy: await WindowsSystemProxy.engineConfig(
              enabled: useDownloadSystemProxy,
            ),
          );
          // 引擎退出时任务会被标成暂停，启动时继续下载或做种未完成的任务。
          var resumed = await globalContainer
              .read(btDownloadStoreProvider.notifier)
              .resumeUnfinishedTasks();
          if (resumed > 0) {
            BTLogTool.info('启动时自动继续 $resumed 个下载或做种未完成的任务');
          }
        }),
    ]),
  );

  if (Platform.isWindows) {
    unawaited(_runOptionalService('Tracker 自动更新', trackerStore.checkUpdate));
  }

  unawaited(_runOptionalService('应用缓存', BTCacheManager.instance.init));
  unawaited(
    _runOptionalService('Shader 缓存', PlaybackShaderCacheService.instance.start),
  );

  unawaited(
    _runOptionalService(
      '窗口特效',
      () => applyWindowMaterial(
        dark: switch (themeMode) {
          ThemeMode.dark => true,
          ThemeMode.light => false,
          ThemeMode.system =>
            PlatformDispatcher.instance.platformBrightness == Brightness.dark,
        },
      ),
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
  BTLogTool.error(['未处理异常', error.toString(), stackTrace.toString()]);
}
