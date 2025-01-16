// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

// Project imports:
import '../../pages/app/bmf_page.dart';
import '../../pages/app/download_page.dart';
import '../../pages/app/rss_page.dart';
import '../../pages/app/setting_page.dart';
import '../../pages/app/test_page.dart';
import '../../pages/bangumi/bangumi_calendar.dart';
import '../../store/app_store.dart';
import '../../store/bgm_user_hive.dart';
import '../../store/nav_store.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../utils/get_theme_label.dart';

/// 应用导航
class AppNavWidget extends ConsumerStatefulWidget {
  /// 构造函数
  const AppNavWidget({super.key});

  @override
  ConsumerState<AppNavWidget> createState() => _AppNavWidgetState();
}

/// 导航状态
class _AppNavWidgetState extends ConsumerState<AppNavWidget>
    with AutomaticKeepAliveClientMixin {
  /// 当前索引
  int get curIndex => ref.watch(navStoreProvider).curIndex;

  /// 当前主题模式
  ThemeMode get _curThemeMode => ref.watch(appStoreProvider).themeMode;

  /// 侧边动态组件
  List<PaneItem> get _navItems => ref.watch(navStoreProvider).navItems;

  /// flyoutController
  final FlyoutController flyout = FlyoutController();

  /// bangumi用户Hive
  final BgmUserHive hive = BgmUserHive();

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      var check = await hive.checkExpired();
      if (check == null || !check) return;
      var fresh = await hive.refreshAuth(
        onErr: (e) async => await showRespErr(e, context),
      );
      if (mounted && fresh == true) {
        await BtInfobar.success(context, '已成功刷新用户Token！');
      }
    });
  }

  /// dispose
  @override
  void dispose() {
    flyout.dispose();
    super.dispose();
  }

  /// 展示设置flyout
  void showOptionsFlyout() {
    flyout.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      dismissWithEsc: true,
      builder: (context) => MenuFlyout(
        items: [
          buildResetWinItem(),
          buildPinWinItem(),
        ],
      ),
    );
  }

  /// 构建重置窗口大小项
  MenuFlyoutItem buildResetWinItem() {
    return MenuFlyoutItem(
      leading: const Icon(FluentIcons.reset_device),
      text: const Text('重置窗口大小'),
      onPressed: () async {
        var size = await windowManager.getSize();
        var target = const Size(1280, 720);
        if (size == target) {
          if (mounted) await BtInfobar.warn(context, '无需重置大小！');
          return;
        }
        await windowManager.setSize(target);
        if (mounted) await BtInfobar.success(context, '已成功重置窗口大小！');
      },
    );
  }

  /// 构建置顶窗口项
  MenuFlyoutItem buildPinWinItem() {
    return MenuFlyoutItem(
      leading: const Icon(FluentIcons.pinned_solid),
      text: const Text('窗口置顶/取消置顶'),
      onPressed: () async {
        var isAlwaysOnTop = await windowManager.isAlwaysOnTop();
        await windowManager.setAlwaysOnTop(!isAlwaysOnTop);
        var str = isAlwaysOnTop ? '取消置顶' : '置顶';
        if (mounted) await BtInfobar.success(context, '$str成功');
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
        title: const Text('Bangumi-今日放送'),
        body: const CalendarPage(),
      ),
      PaneItem(
        icon: Image.asset(
          'assets/images/platforms/mikan-favicon.ico',
          height: 16,
        ),
        title: const Text('RSS 页面'),
        body: const RssPage(),
      ),
      PaneItem(
        icon: Image.asset('assets/images/logo.png', height: 16),
        title: const Text('BMF配置'),
        body: const BmfPage(),
      ),
      if (kDebugMode)
        PaneItem(
          icon: const Icon(FluentIcons.cloud_download),
          title: const Text('下载管理'),
          body: const DownloadPage(),
        )
    ];
  }

  /// 获取导航项
  List<PaneItem> getNavItems(BuildContext context) {
    var constItems = getConstItems();
    var items = [...constItems, ..._navItems];
    return items;
  }

  /// 获取底部项
  List<PaneItem> getFooterItems() {
    var debugPane = PaneItem(
      icon: const Icon(FluentIcons.bug),
      title: const Text('调试页面'),
      body: const TestPage(),
    );
    var footerItems = [
      PaneItemAction(
        icon: FlyoutTarget(
          controller: flyout,
          child: const Icon(FluentIcons.graph_symbol),
        ),
        title: const Text('更多设置'),
        onTap: showOptionsFlyout,
      ),
      buildThemeModeItem(),
      PaneItem(
        icon: const Icon(FluentIcons.settings),
        title: const Text('应用设置'),
        body: const SettingPage(),
      ),
    ];
    if (kDebugMode) footerItems.insert(0, debugPane);
    return footerItems;
  }

  /// 导航面板
  NavigationPane buildNavPane(BuildContext context) {
    return NavigationPane(
      selected: curIndex,
      onChanged: (index) => ref.read(navStoreProvider).setCurIndex(index),
      displayMode: PaneDisplayMode.compact,
      items: getNavItems(context),
      footerItems: getFooterItems(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return NavigationView(pane: buildNavPane(context));
  }
}
