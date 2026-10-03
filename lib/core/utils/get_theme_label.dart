// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

/// 侧边栏主题模式配置
class ThemeModeConfig {
  /// 当前主题模式
  ThemeMode cur;

  /// 对应 hint
  String label;

  /// 对应图标
  IconData icon;

  /// 下一个主题模式
  ThemeMode next;

  /// 构造函数
  ThemeModeConfig({
    required this.cur,
    required this.label,
    required this.icon,
    required this.next,
  });
}

/// 获取侧边栏主题模式配置
ThemeModeConfig getThemeModeConfig(ThemeMode themeMode) {
  switch (themeMode) {
    case ThemeMode.system:
      return ThemeModeConfig(
        cur: ThemeMode.system,
        label: '跟随系统',
        icon: FluentIcons.lightning_bolt,
        next: ThemeMode.light,
      );
    case ThemeMode.light:
      return ThemeModeConfig(
        cur: ThemeMode.light,
        label: '浅色模式',
        icon: FluentIcons.sunny,
        next: ThemeMode.dark,
      );
    case ThemeMode.dark:
      return ThemeModeConfig(
        cur: ThemeMode.dark,
        label: '深色模式',
        icon: FluentIcons.clear_night,
        next: ThemeMode.system,
      );
  }
}

/// 获取侧边栏主题模式配置列表
List<ThemeModeConfig> getThemeModeConfigList() {
  return [
    getThemeModeConfig(ThemeMode.system),
    getThemeModeConfig(ThemeMode.light),
    getThemeModeConfig(ThemeMode.dark),
  ];
}
