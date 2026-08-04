// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import 'core/utils/window_effect.dart';
import 'store/app_store.dart';
import 'widgets/app/app_nav.dart';

/// 应用入口
class BTApp extends ConsumerStatefulWidget {
  /// 构造函数
  const BTApp({super.key});

  @override
  ConsumerState<BTApp> createState() => _BTAppState();
}

class _BTAppState extends ConsumerState<BTApp> {
  /// 已应用的窗口材质深浅色，避免重复设置
  bool? _appliedWindowDark;

  /// 获取主题配置
  FluentThemeData getTheme(BuildContext context, BTAppStore appStore) {
    Brightness brightness;
    switch (appStore.themeMode) {
      case ThemeMode.system:
        brightness = MediaQuery.platformBrightnessOf(context);
        break;
      case ThemeMode.light:
        brightness = Brightness.light;
        break;
      case ThemeMode.dark:
        brightness = Brightness.dark;
        break;
    }
    return FluentThemeData(
      brightness: brightness,
      accentColor: appStore.accentColor,
      fontFamily: 'SMonoSC',
    );
  }

  /// 让窗口背景材质跟随应用主题（含系统模式下系统深浅色的变化）
  void _syncWindowMaterial(BuildContext context, ThemeMode mode) {
    var dark = switch (mode) {
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
      ThemeMode.light => false,
      ThemeMode.dark => true,
    };
    if (_appliedWindowDark == dark) return;
    _appliedWindowDark = dark;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await applyWindowMaterial(dark: dark);
      } catch (error) {
        debugPrint('设置窗口背景材质失败: $error');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var appStore = ref.watch(appStoreProvider);
    _syncWindowMaterial(context, appStore.themeMode);
    return FluentApp(
      title: 'BangumiToday',
      themeMode: appStore.themeMode,
      theme: getTheme(context, appStore),
      home: const AppNavWidget(),
      debugShowCheckedModeBanner: false,
    );
  }
}
