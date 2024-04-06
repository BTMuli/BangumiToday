import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:system_theme/system_theme.dart';
import 'package:video_player_win/video_player_win_plugin.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'tools/config_tool.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WindowsVideoPlayer.registerWith();
  await windowManager.ensureInitialized();
  await Window.initialize();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  SystemTheme.accentColor.load();
  await BTConfigTool.init();
  runApp(ProviderScope(child: BTApp()));
  Window.setEffect(effect: WindowEffect.acrylic);
}
