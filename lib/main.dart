import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'tools/config_tool.dart';
import 'tools/log_tool.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await Window.initialize();
  SystemTheme.accentColor.load();

  /// 初始化配置
  await BTLogTool.init();
  await BTConfigTool.init();
  runApp(ProviderScope(child: BTApp()));
  Window.setEffect(effect: WindowEffect.acrylic);
}
