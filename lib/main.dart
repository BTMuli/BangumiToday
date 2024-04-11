import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'database/bt_sqlite.dart';
import 'tools/log_tool.dart';
import 'tools/scheme_tool.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await Window.initialize();
  SystemTheme.accentColor.load();
  await dotenv.load(fileName: ".env");

  /// 初始化配置
  await BTLogTool().init();
  await BTSchemeTool().init();
  await BTSqlite().init();
  runApp(ProviderScope(child: BTApp()));
  Window.setEffect(effect: WindowEffect.acrylic);
}
