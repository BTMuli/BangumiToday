import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';

import '../database/app/app_config.dart';

/// 应用状态提供者
final appStoreProvider = ChangeNotifierProvider<BTAppStore>((ref) {
  return BTAppStore();
});

/// 应用状态
class BTAppStore extends ChangeNotifier {
  /// 应用配置数据库
  final BtsAppConfig sqlite = BtsAppConfig();

  /// 构造函数
  BTAppStore() {
    initTheme();
    initAccentColor();
  }

  /// 初始化主题
  Future<void> initTheme() async {
    _themeMode = await sqlite.readThemeMode();
    notifyListeners();
  }

  /// 初始化主题色
  Future<void> initAccentColor() async {
    _accentColor = await sqlite.readAccentColor();
    notifyListeners();
  }

  /// 主题
  ThemeMode _themeMode = ThemeMode.system;

  /// 主题色
  AccentColor _accentColor = Colors.blue.toAccentColor();

  /// 获取主题
  ThemeMode get themeMode => _themeMode;

  /// 设置主题
  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    await sqlite.writeThemeMode(value);
    notifyListeners();
  }

  /// 获取主题色
  AccentColor get accentColor {
    if (_themeMode == ThemeMode.system) {
      return SystemTheme.accentColor.accent.toAccentColor();
    } else {
      return _accentColor;
    }
  }

  /// 设置主题色
  Future<void> setAccentColor(AccentColor value) async {
    _accentColor = value;
    await sqlite.writeAccentColor(value);
    notifyListeners();
  }
}
