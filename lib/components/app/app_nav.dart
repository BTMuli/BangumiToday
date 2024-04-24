import 'package:bangumi_today/components/app/app_dialog_resp.dart';
import 'package:bangumi_today/models/bangumi/bangumi_oauth_model.dart';
import 'package:bangumi_today/pages/app/rss_page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../database/bangumi/bangumi_user.dart';
import '../../pages/app/bmf_page.dart';
import '../../pages/app/download_page.dart';
import '../../pages/app/setting_page.dart';
import '../../pages/app/test_page.dart';
import '../../pages/bangumi/bangumi_calendar.dart';
import '../../request/bangumi/bangumi_oauth.dart';
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

  /// bangumi用户数据库
  final BtsBangumiUser _bangumiUser = BtsBangumiUser();

  /// bangumi客户端
  final BtrBangumiOauth _bangumiOauth = BtrBangumiOauth();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await checkExpired();
    });
  }

  /// 检查是否过期
  Future<void> checkExpired() async {
    var now = DateTime.now();
    var token = await _bangumiUser.readRefreshToken();
    var expired = await _bangumiUser.readExpireTime();
    if (expired == null || token == null) return;
    if (token.isEmpty || expired.isBefore(now)) return;
    var resp = await _bangumiOauth.refreshToken(token);
    if (resp.code != 0 || resp.data == null) {
      if (mounted) showRespErr(resp, context, title: '刷新用户Token失败');
      return;
    }
    var data = resp.data! as BangumiOauthTokenRefreshData;
    await _bangumiUser.writeAccessToken(data.accessToken);
    await _bangumiUser.writeRefreshToken(data.refreshToken);
    await _bangumiUser.writeExpireTime(data.expiresIn);
    if (mounted) BtInfobar.success(context, '已成功刷新用户Token！');
  }

  /// 构建重置窗口大小项
  PaneItemAction buildResetWinItem() {
    return PaneItemAction(
      icon: const Icon(FluentIcons.reset_device),
      title: const Text('ResetWin'),
      onTap: () async {
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

  /// 获取底部项
  List<PaneItem> getFooterItems() {
    var downloadPane = PaneItem(
      icon: const Icon(FluentIcons.download),
      title: const Text('下载列表'),
      body: const DownloadPage(),
    );
    var debugPane = PaneItem(
      icon: const Icon(FluentIcons.bug),
      title: const Text('Debug'),
      body: const TestPage(),
    );
    var footerItems = [
      buildResetWinItem(),
      buildThemeModeItem(),
      PaneItem(
        icon: const Icon(FluentIcons.settings),
        title: const Text('Settings'),
        body: const SettingPage(),
      ),
    ];
    if (kDebugMode) {
      footerItems.insert(0, downloadPane);
      footerItems.insert(0, debugPane);
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
