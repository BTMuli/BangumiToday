// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

// Project imports:
import '../../controller/app/progress_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/app_link_service.dart';
import '../../core/services/bangumi_oauth_coordinator.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/bangumi_oauth_model.dart';
import '../../pages/app-setting/app_setting_page.dart';
import '../../pages/app/download_page.dart';
import '../../pages/bangumi-calendar/bangumi_calendar_page.dart';
import '../../pages/rss-bmf/rss_bmf_page.dart';
import '../../pages/user-collection/user_collection_page.dart';
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

  /// bangumi用户Hive
  final BgmUserHive hive = BgmUserHive();

  /// 认证相关客户端
  final BtrBangumiOauth apiOauth = BtrBangumiOauth();

  /// Bangumi 请求客户端
  final BtrBangumiApi apiBgm = BtrBangumiApi();

  /// 应用链接订阅
  StreamSubscription<Uri>? _appLinkSubscription;

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
        onErr: (e) async {
          if (!mounted) return;
          await showRespErr(e, context);
        },
      );
      if (mounted && fresh == true) {
        await BtInfobar.success(context, '已成功刷新用户Token！');
      }
    });

    _appLinkSubscription = AppLinkService.instance.stream.listen(
      _handleAppLink,
    );
  }

  void _handleAppLink(Uri uri) {
    if (uri.scheme.toLowerCase() == BTAppConstants.urlScheme &&
        uri.host.toLowerCase() == BTAppConstants.subjectPath) {
      var subjectId = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : null;
      if (subjectId != null) {
        var id = int.tryParse(subjectId);
        if (id != null) {
          ref.read(navStoreProvider).addNavItemB(type: '条目', subject: id);
        }
      }
    }
  }

  /// dispose
  @override
  void dispose() {
    _appLinkSubscription?.cancel();
    flyoutMore.dispose();
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

  /// 退出登录
  Future<void> logoutUser() async {
    await hive.deleteUser();
    if (mounted) {
      await BtInfobar.success(context, '已成功退出登录');
      setState(() {});
    }
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
    if (!mounted) {
      progress.end();
      return;
    }
    progress.update(title: '获取用户信息成功', text: '用户信息：${hive.user!.nickname}');
    progress.end();
    if (mounted) {
      await BtInfobar.success(
        context,
        '成功获取[${hive.user!.id}]${hive.user!.nickname}信息',
      );
    }
    if (mounted) setState(() {});
  }

  /// 认证用户
  Future<void> oauthUser() async {
    if (progress.isShow) {
      progress.update(title: '处理用户授权', text: '正在前往授权页面', progress: null);
    } else {
      progress = ProgressWidget.show(context, title: '前往授权页面');
    }
    progress.update(text: '等待授权回调');
    var res = await BangumiOAuthCoordinator.instance.authorize(apiOauth);
    if (!mounted) {
      progress.end();
      return;
    }
    if (res.code != 0 || res.data == null) {
      progress.end();
      await showRespErr(res, context);
      return;
    }
    progress.update(text: '保存授权信息');
    var at = res.data as BangumiOauthTokenGetData;
    await hive.updateAccessToken(at.accessToken, update: false);
    await hive.updateRefreshToken(at.refreshToken, update: false);
    await hive.updateExpireTime(at.expiresIn, update: false);
    await hive.updateBox();
    await freshUserInfo();
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
        body: const BangumiCalendarPage(),
      ),
      PaneItem(
        icon: Image.asset('assets/images/logo.png', height: 16),
        title: const Text('RSS & BMF'),
        body: const RssBmfPage(),
      ),
      hive.user == null
          ? PaneItemAction(
              icon: const Icon(FluentIcons.account_management),
              title: const Text('未登录'),
              onTap: () async => oauthUser(),
            )
          : PaneItem(
              icon: CachedNetworkImage(
                imageUrl: BtrBangumiApi.rewriteUrl(hive.user!.avatar.small),
                width: 18,
                height: 18,
                placeholder: (_, _) => const ProgressRing(),
                errorWidget: (_, _, _) => const Icon(FluentIcons.error),
              ),
              title: Text(hive.user!.nickname),
              body: const UserCollectionPage(),
            ),
      if (Platform.isWindows)
        PaneItem(
          icon: const Icon(FluentIcons.cloud_download),
          title: const Text('下载管理'),
          body: const DownloadPage(),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return NavigationView(
      pane: NavigationPane(
        selected: curIndex,
        onChanged: (index) => ref.read(navStoreProvider).setCurIndex(index),
        displayMode: PaneDisplayMode.compact,
        items: [...getConstItems(), ..._navItems],
        footerItems: [
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
        ],
      ),
    );
  }
}
