import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'components/app/app_nav.dart';
import 'store/app_store.dart';

/// 应用入口
class BTApp extends ConsumerWidget {
  /// 构造函数
  const BTApp({super.key});

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
        fontFamily: 'SMonoSC');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStore = ref.watch(appStoreProvider);
    // todo 平台适配
    return ScreenUtilInit(
      designSize: const Size(1920, 1080),
      builder: (_, child) {
        // todo 国际化
        return FluentApp(
          title: 'BangumiToday',
          themeMode: appStore.themeMode,
          theme: getTheme(context, appStore),
          home: AppNav(),
        );
      },
    );
  }
}
