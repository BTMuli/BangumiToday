import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:system_theme/system_theme.dart';
import 'package:video_player_win/video_player_win_plugin.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'tools/config_tool.dart';
import 'utils/get_platform.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isMobile == true) {
    // todo android 适配
    debugPrint('isMobile');
  } else {
    debugPrint('isPC');
    WindowsVideoPlayer.registerWith();
    await windowManager.ensureInitialized();
    await Window.initialize();
  }

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  SystemTheme.accentColor.load();
  await BTConfigTool.init();

  /// 应用启动
  runApp(ProviderScope(child: BTApp()));

  /// 亚克力效果
  if (isMobile == false) {
    Window.setEffect(effect: WindowEffect.acrylic);
  }
}
