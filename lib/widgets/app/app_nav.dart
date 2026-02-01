// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:app_links/app_links.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

// Project imports:
import '../../controller/app/progress_controller.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/bangumi_oauth_model.dart';
import '../../pages/app-setting/app_setting_page.dart';
import '../../pages/app/bmf_page.dart';
import '../../pages/app/download_page.dart';
import '../../pages/app/rss_page.dart';
import '../../pages/app/test_page.dart';
import '../../pages/bangumi-calendar/bangumi_calendar_page.dart';
import '../../pages/bangumi/bangumi_collection.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../request/bangumi/bangumi_oauth.dart';
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

  /// moreFlyoutController
  final FlyoutController flyoutMore = FlyoutController();

  /// UserFlyoutController
  final FlyoutController flyoutUser = FlyoutController();

  /// bangumi用户Hive
  final BgmUserHive hive = BgmUserHive();

  /// 认证相关客户端
  final BtrBangumiOauth apiOauth = BtrBangumiOauth();

  /// Bangumi 请求客户端
  final BtrBangumiApi apiBgm = BtrBangumiApi();

  /// app-link 监听
  final AppLinks appLinks = AppLinks();

  /// 进度条
  late ProgressController progress = ProgressController();

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
    flyoutMore.dispose();
    flyoutUser.dispose();
    super.dispose();
  }

  /// 展示设置flyout
  void showOptionsFlyout() {
    flyoutMore.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      dismissWithEsc: true,
      builder: (context) =>
          MenuFlyout(items: [buildResetWinItem(), buildPinWinItem()]),
    );
  }

  /// 展示用户 Flyout
  void showUserFlyout() {
    flyoutUser.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      dismissWithEsc: true,
      builder: (context) =>
          MenuFlyout(items: [buildResetWinItem(), buildPinWinItem()]),
    );
  }

  /// 刷新用户信息
  Future<void> freshUserInfo() async {
    if (progress.isShow) {
      progress.update(title: '获取用户信息', text: '正在获取用户信息', progress: null);
    } else {
      progress = ProgressWidget.show(context, title: '获取用户信息');
    }
    if (hive.tokenAC == null) {
      progress.end();
      if (mounted) await BtInfobar.error(context, '未找到访问令牌');
      return;
    }
    var userResp = await apiBgm.getUserInfo();
    if (userResp.code != 0 || userResp.data == null) {
      progress.end();
      if (mounted) await showRespErr(userResp, context);
      return;
    }
    await hive.updateUser(userResp.data! as BangumiUser);
    progress.update(title: '获取用户信息成功', text: '用户信息：${hive.user!.nickname}');
    progress.end();
    if (mounted) {
      await BtInfobar.success(
        context,
        '成功获取[${hive.user!.id}]${hive.user!.nickname}信息',
      );
    }
    setState(() {});
  }

  /// 认证用户
  Future<void> oauthUser() async {
    if (progress.isShow) {
      progress.update(title: '处理用户授权', text: '正在前往授权页面', progress: null);
    } else {
      progress = ProgressWidget.show(context, title: '前往授权页面');
    }
    await apiOauth.openAuthorizePage();
    progress.update(text: '等待授权回调');
    appLinks.uriLinkStream.listen((uri) async {
      debugPrint(uri.toString());
      if (uri.toString().startsWith('bangumitoday://oauth')) {
        progress.update(text: '处理授权回调');
        var code = uri.queryParameters['code'];
        if (code == null) {
          if (mounted) await BtInfobar.error(context, '授权失败：未找到授权码');
          progress.end();
          // 停止监听
          appLinks.uriLinkStream.listen((_) {});
          return;
        }
        progress.update(text: '授权码：$code');
        var res = await apiOauth.getAccessToken(code);
        if (res.code != 0 || res.data == null) {
          progress.end();
          if (mounted) await showRespErr(res, context);
          return;
        }
        assert(res.data != null);
        var at = res.data as BangumiOauthTokenGetData;
        await hive.updateAccessToken(at.accessToken, update: false);
        await hive.updateRefreshToken(at.refreshToken, update: false);
        await hive.updateExpireTime(at.expiresIn, update: false);
        await hive.updateBox();
        await freshUserInfo();
      }
    });
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

  /// 构建用户信息项
  PaneItem buildUserItem() {
    if (hive.user == null) {
      return PaneItemAction(
        icon: const Icon(FluentIcons.account_management),
        title: const Text('未登录'),
        onTap: () async => oauthUser(),
      );
    }
    return PaneItem(
      icon: CachedNetworkImage(
        imageUrl: hive.user!.avatar.small,
        width: 18,
        height: 18,
        placeholder: (_, _) => const ProgressRing(),
        errorWidget: (_, _, _) => const Icon(FluentIcons.error),
      ),
      title: Text(hive.user!.nickname),
      body: BangumiCollectionPage(),
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
        body: const BangumiCalendarPage(),
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
        ),
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
      buildUserItem(),
      PaneItemAction(
        icon: FlyoutTarget(
          controller: flyoutMore,
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
