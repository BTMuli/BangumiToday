// Flutter imports:
import 'dart:async';

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
import 'database/bt_sqlite.dart';
import 'tools/download_tool.dart';
import 'tools/hive_tool.dart';
import 'tools/log_tool.dart';
import 'tools/notifier_tool.dart';
import 'widgets/app/app_splash.dart';

final globalContainer = ProviderContainer();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(UncontrolledProviderScope(
    container: globalContainer,
    child: const BTSplashScreen(),
  ));

  unawaited(_initBackgroundServices());
}

Future<void> _initBackgroundServices() async {
  await BTLogTool.init();

  await BTSqlite.init();

  await Future.wait([
    BTDownloadTool.init(),
    BTNotifierTool.init(),
    BTHiveTool.init(),
  ]);

  await Future.wait([
    BTCacheManager.instance.init(),
    LRUCacheManager.instance.init(),
  ]);

  MemoryManager.instance.startMonitoring(
    interval: const Duration(seconds: 60),
  );

  await Window.setEffect(effect: WindowEffect.acrylic);

  unawaited(BmfRssService.instance.start());

  runApp(UncontrolledProviderScope(
    container: globalContainer,
    child: const BTApp(),
  ));
}
