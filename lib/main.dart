import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'tools/config_tool.dart';

void main() async {
  // todo 平台适配
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await Window.initialize();
  SystemTheme.accentColor.load();

  await BTConfigTool.init();

  runApp(ProviderScope(child: BTApp()));
}
