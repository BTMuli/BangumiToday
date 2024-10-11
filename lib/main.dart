// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

// Project imports:
import 'app.dart';
import 'database/bt_sqlite.dart';
import 'tools/hive_tool.dart';
import 'tools/log_tool.dart';
import 'tools/notifier_tool.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  MediaKit.ensureInitialized();
  await Window.initialize();
  await SystemTheme.accentColor.load();
  await dotenv.load(fileName: ".env");

  /// 初始化配置
  await BTLogTool().init();
  await BTNotifierTool().init();
  await BTSqlite().init();
  await BTHiveTool().init();
  runApp(const ProviderScope(child: BTApp()));
  await Window.setEffect(effect: WindowEffect.acrylic);
}
