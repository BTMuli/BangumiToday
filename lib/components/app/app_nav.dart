import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../pages/app/bmf_page.dart';
import '../../pages/app/download_page.dart';
import '../../pages/app/setting_page.dart';
import '../../pages/app/test_page.dart';
import '../../pages/bangumi/bangumi_calendar.dart';
import '../../pages/comicat/comicat_rss.dart';
import '../../pages/mikan/mikan_rss.dart';
import '../../store/app_store.dart';
import '../../store/nav_store.dart';
import '../../utils/get_theme_label.dart';
import 'app_infobar.dart';

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
  int get curIndex => ref.watch(navStoreProvider).curIndex;

  /// 当前主题模式
  ThemeMode get _curThemeMode => ref.watch(appStoreProvider).themeMode;

  /// 侧边动态组件
  List<PaneItem> get _navItems => ref.watch(navStoreProvider).navItems;

  @override
  void initState() {
    super.initState();
  }

  /// 构建重置窗口大小项
  PaneItemAction buildResetWinItem() {
    return PaneItemAction(
      icon: Icon(FluentIcons.reset_device),
      title: Text('ResetWin'),
      onTap: () async {
        var size = await windowManager.getSize();
        var target = Size(1280, 720);
        if (size == target) {
          await BtInfobar.warn(context, '无需重置大小！');
          return;
        }
        await windowManager.setSize(Size(1280, 720));
        await BtInfobar.success(context, '已成功重置窗口大小！');
      },
    );
  }

  /// 构建主题模式项
  PaneItemAction buildThemeModeItem() {
    var config = getThemeModeConfig(_curThemeMode);
    return PaneItemAction(
      icon: Icon(config.icon),
      title: Text(config.label),
      onTap: () async {
        await ref.read(appStoreProvider).setThemeMode(config.next);
      },
    );
  }

  /// 获取常量项
  List<PaneItem> getConstItems() {
    return [
      PaneItem(
        icon: Image.asset('assets/images/platforms/bangumi-favicon.ico'),
        title: Text('Bangumi-今日放送'),
        body: CalendarPage(),
      ),
      PaneItem(
        icon: Image.asset(
          'assets/images/platforms/mikan-favicon.ico',
          height: 16,
        ),
        title: Text('Mikan'),
        body: MikanRSSPage(),
      ),
      PaneItem(
        icon: Image.asset('assets/images/platforms/comicat-favicon.ico'),
        title: Text('Comicat'),
        body: ComicatRSSPage(),
      ),
      PaneItem(
        icon: Image.asset('assets/images/logo.png', height: 16),
        title: Text('BMF配置'),
        body: BmfPage(),
      ),
      PaneItem(
        icon: Icon(FluentIcons.download),
        title: Text('下载列表'),
        body: DownloadPage(),
      ),
    ];
  }

  /// 获取导航项
  List<PaneItem> getNavItems(BuildContext context) {
    var navStore = ref.read(navStoreProvider);
    navStore.addListener(() {
      setState(() {});
    });
    var constItems = getConstItems();
    var items = [...constItems, ..._navItems];
    return items;
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
      buildResetWinItem(),
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
  NavigationPane buildNavPane(BuildContext context) {
    return NavigationPane(
      selected: curIndex,
      onChanged: (index) {
        ref.read(navStoreProvider).setCurIndex(index);
      },
      displayMode: PaneDisplayMode.compact,
      items: getNavItems(context),
      footerItems: getFooterItems(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavigationView(pane: buildNavPane(context));
  }
}
