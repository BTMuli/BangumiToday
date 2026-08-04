// Flutter imports:
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

// Project imports:
import 'app.dart';
import 'core/cache/cache_manager.dart';
import 'core/cache/lru_cache_manager.dart';
import 'core/memory/memory_manager.dart';
import 'core/services/bt_engine_client.dart';
import 'core/services/bmf_rss_service.dart';
import 'core/utils/window_effect.dart';
import 'database/app/app_config.dart';
import 'database/bt_sqlite.dart';
import 'request/bangumi/bangumi_api.dart';
import 'store/tracker_hive.dart';
import 'tools/download_tool.dart';
import 'tools/hive_tool.dart';
import 'tools/log_tool.dart';
import 'tools/notifier_tool.dart';
import 'widgets/app/app_splash.dart';

final globalContainer = ProviderContainer();

Future<void> main() async {
  if (const bool.fromEnvironment('ENABLE_FLUTTER_DRIVER')) {
    enableFlutterDriverExtension();
  }

  WidgetsFlutterBinding.ensureInitialized();
  _configureErrorHandling();
  AppLifecycleListener(
    onExitRequested: () async {
      await BtEngineClient.instance.shutdown();
      return AppExitResponse.exit;
    },
  );

  await Future.wait([
    windowManager.ensureInitialized(),
    Window.initialize(),
    SystemTheme.accentColor.load(),
    dotenv.load(fileName: ".env"),
  ]);

  WindowOptions windowOpts = const WindowOptions(
    title: kDebugMode ? 'BangumiToday[Dev]' : 'BangumiToday',
    size: Size(1280, 720),
    center: true,
  );
  await windowManager.waitUntilReadyToShow(
    (windowOpts),
    () async => await windowManager.show(),
  );

  _runApp(const BTSplashScreen());

  try {
    await _initBackgroundServices();
    _runApp(const BTApp());
  } catch (error, stackTrace) {
    _reportUnhandledError(error, stackTrace);
    _runApp(BTSplashScreen(errorMessage: error.toString()));
  }
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

  MemoryManager.instance.startMonitoring(interval: const Duration(seconds: 60));

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

  unawaited(_runOptionalService('BMF RSS 服务', BmfRssService.instance.start));
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
  if (BTLogTool.isInitialized) {
    BTLogTool.error(['未处理异常', error.toString(), stackTrace.toString()]);
    return;
  }

  debugPrint('未处理异常: $error\n$stackTrace');
}
