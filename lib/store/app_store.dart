import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';

import '../tools/config_tool.dart';

/// 应用状态提供者
final appStoreProvider = ChangeNotifierProvider<BTAppStore>((ref) {
  return BTAppStore();
});

/// 应用状态
class BTAppStore extends ChangeNotifier {
  /// 配置工具
  final BTConfigTool _configTool = BTConfigTool();

  /// 构造函数
  BTAppStore() {
    initTheme();
    initAccentColor();
    initSource();
  }

  /// 初始化主题
  void initTheme() {
    var themeMode = _configTool.readConfig(key: 'themeMode');
    switch (themeMode) {
      case 'ThemeMode.system':
        _themeMode = ThemeMode.system;
        break;
      case 'ThemeMode.light':
        _themeMode = ThemeMode.light;
        break;
      case 'ThemeMode.dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
        break;
    }
    notifyListeners();
  }

  /// 初始化主题色
  void initAccentColor() {
    var accentColor = _configTool.readConfig(key: 'accentColor');
    _accentColor = Color(accentColor).toAccentColor();
    notifyListeners();
  }

  /// 初始化番剧数据源
  void initSource() {
    var source = _configTool.readConfig(key: 'source');
    _source = source;
    notifyListeners();
  }

  /// 主题
  ThemeMode _themeMode = ThemeMode.system;

  /// 主题色
  AccentColor _accentColor = Colors.blue.toAccentColor();

  /// 番剧数据源
  String _source = 'bangumi';

  /// 获取主题
  ThemeMode get themeMode => _themeMode;

  /// 设置主题
  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    await _configTool.writeConfig('themeMode', value.toString());
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
    await _configTool.writeConfig('accentColor', value.value);
    notifyListeners();
  }

  /// 获取番剧数据源
  String get source => _source;

  /// 设置番剧数据源
  Future<void> setSource(String value) async {
    _source = value;
    await _configTool.writeConfig('source', value);
    notifyListeners();
  }
}
