import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pages/app/setting_page.dart';
import '../../pages/app/test_page.dart';
import '../../pages/bangumi/bangumi_calendar.dart';
import '../../pages/mikan/mikan_rss.dart';
import '../../store/app_store.dart';
import '../../utils/get_theme_label.dart';

/// 应用导航
class AppNav extends ConsumerStatefulWidget {
  /// 构造函数
  const AppNav({super.key});

  @override
  ConsumerState<AppNav> createState() => _AppNavState();
}

/// 导航状态
class _AppNavState extends ConsumerState<AppNav> {
  /// 当前索引
  late int curIndex;

  /// 当前主题模式
  ThemeMode get _curThemeMode => ref.watch(appStoreProvider).themeMode;

  @override
  void initState() {
    super.initState();
    curIndex = 0;
  }

  /// 构建主题模式项
  PaneItemAction buildThemeModeItem() {
    var config = getThemeModeConfig(_curThemeMode);
    return PaneItemAction(
      icon: Icon(config.icon),
      title: Text(config.label),
      body: Center(child: Text(config.label)),
      onTap: () async {
        await ref.read(appStoreProvider).setThemeMode(config.next);
      },
    );
  }

  /// 获取导航项
  List<PaneItem> getNavItems() {
    return [
      PaneItem(
        icon: Icon(FluentIcons.calendar),
        title: Text('Today'),
        body: CalendarPage(),
      ),
      PaneItem(
        icon: Image.asset('assets/images/platforms/mikan-favicon.ico'),
        title: Text('蜜柑计划'),
        body: MikanRSSPage(),
      ),
    ];
  }

  /// 构建调试项
  PaneItem buildDebugItem() {
    return PaneItem(
      icon: Icon(FluentIcons.bug),
      title: Text('Debug'),
      body: TestPage(),
    );
  }

  /// 获取底部项
  List<PaneItem> getFooterItems() {
    var footerItems = [
      buildThemeModeItem(),
      PaneItem(
        icon: Icon(FluentIcons.settings),
        title: Text('Settings'),
        body: SettingPage(),
      ),
    ];
    if (kDebugMode) {
      footerItems.insert(0, buildDebugItem());
    }
    return footerItems;
  }

  /// 导航面板
  NavigationPane buildNavPane() {
    return NavigationPane(
      selected: curIndex,
      onChanged: (index) {
        setState(() {
          curIndex = index;
        });
      },
      displayMode: PaneDisplayMode.compact,
      items: getNavItems(),
      footerItems: getFooterItems(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavigationView(pane: buildNavPane());
  }
}
