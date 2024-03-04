import 'package:fluent_ui/fluent_ui.dart';

/// 侧边栏主题模式配置
class NavThemeModeConfig {
  /// 当前主题模式
  ThemeMode cur;

  /// 对应 hint
  String label;

  /// 对应图标
  IconData icon;

  /// 下一个主题模式
  ThemeMode next;

  /// 构造函数
  NavThemeModeConfig({
    required this.cur,
    required this.label,
    required this.icon,
    required this.next,
  });
}

/// 获取侧边栏主题模式配置
NavThemeModeConfig getNavThemeModeConfig(ThemeMode themeMode) {
  switch (themeMode) {
    case ThemeMode.system:
      return NavThemeModeConfig(
        cur: ThemeMode.system,
        label: 'System',
        icon: FluentIcons.lightning_bolt,
        next: ThemeMode.light,
      );
    case ThemeMode.light:
      return NavThemeModeConfig(
        cur: ThemeMode.light,
        label: 'Light',
        icon: FluentIcons.sunny,
        next: ThemeMode.dark,
      );
    case ThemeMode.dark:
      return NavThemeModeConfig(
        cur: ThemeMode.dark,
        label: 'Dark',
        icon: FluentIcons.clear_night,
        next: ThemeMode.system,
      );
  }
}

/// 获取侧边栏主题模式配置列表
List<NavThemeModeConfig> getNavThemeModeConfigList() {
  return [
    getNavThemeModeConfig(ThemeMode.system),
    getNavThemeModeConfig(ThemeMode.light),
    getNavThemeModeConfig(ThemeMode.dark),
  ];
}
