// Flutter imports:
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

// Project imports:
import 'app.dart';
import 'core/cache/cache_manager.dart';
import 'core/cache/lru_cache_manager.dart';
import 'core/memory/memory_manager.dart';
import 'core/services/bmf_rss_service.dart';
import 'database/app/app_config.dart';
import 'database/bt_sqlite.dart';
import 'request/bangumi/bangumi_api.dart';
import 'tools/download_tool.dart';
import 'tools/hive_tool.dart';
import 'tools/log_tool.dart';
import 'tools/notifier_tool.dart';
import 'widgets/app/app_splash.dart';

final globalContainer = ProviderContainer();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureErrorHandling();

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
  BtrBangumiApi.setBaseUrl(await BtsAppConfig().readBangumiUrl());

  await BTHiveTool.init();

  await Future.wait([
    _runOptionalService('下载服务', BTDownloadTool.init),
    _runOptionalService('通知服务', BTNotifierTool.init),
  ]);

  await Future.wait([
    _runOptionalService('应用缓存', BTCacheManager.instance.init),
    _runOptionalService('LRU 缓存', LRUCacheManager.instance.init),
  ]);

  MemoryManager.instance.startMonitoring(interval: const Duration(seconds: 60));

  await _runOptionalService(
    '窗口特效',
    () => Window.setEffect(effect: WindowEffect.acrylic),
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
