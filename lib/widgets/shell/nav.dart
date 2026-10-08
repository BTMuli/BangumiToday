// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

// Project imports:
import '../../controller/progress_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/app_link_service.dart';
import '../../core/services/bangumi_oauth_coordinator.dart';
import '../../core/services/playback_window_service.dart';
import '../../core/utils/get_theme_label.dart';
import '../../models/bangumi/bangumi_oauth_model.dart';
import '../../pages/app_setting/app_setting_page.dart';
import '../../pages/bangumi_calendar/bangumi_calendar_page.dart';
import '../../pages/download/download_page.dart';
import '../../pages/playback/playback_actions.dart';
import '../../pages/playback/playback_page.dart';
import '../../pages/rss_bmf/rss_bmf_page.dart';
import '../../pages/user_collection/user_collection_page.dart';
import '../../providers/app_providers.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../request/bangumi/bangumi_oauth.dart';
import '../../tools/log_tool.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import 'nav_page_stack.dart';

/// 应用导航
class NavWidget extends ConsumerStatefulWidget {
  /// 构造函数
  const NavWidget({super.key});

  @override
  ConsumerState<NavWidget> createState() => _NavWidgetState();
}

/// 导航状态
class _NavWidgetState extends ConsumerState<NavWidget>
    with AutomaticKeepAliveClientMixin {
  /// 当前主题模式
  ThemeMode get _curThemeMode => ref.watch(appStoreProvider).themeMode;

  /// 侧边动态组件
  List<PaneItem> get _navItems => ref.watch(navStoreProvider).paneItems;

  /// moreFlyoutController
  final FlyoutController flyoutMore = FlyoutController();

  /// 当前登录用户
  BgmUserState get _user => ref.watch(bgmUserStoreProvider);

  /// 认证相关客户端
  final BtrBangumiOauth apiOauth = BtrBangumiOauth();

  /// 应用链接订阅
  StreamSubscription<Uri>? _appLinkSubscription;

  bool _playbackErrorFramePending = false;
  bool _isLoggingIn = false;

  /// 进度条
  late ProgressController progress = ProgressController();

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

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
          ref
              .read(navStoreProvider.notifier)
              .addNavItemB(type: '条目', subject: id);
        }
      }
    }
  }

  void _schedulePlaybackWindowError() {
    if (!Platform.isWindows) return;
    var error = ref.watch(
      playbackWindowServiceProvider.select((service) => service.error),
    );
    if (error == null || _playbackErrorFramePending) return;
    _playbackErrorFramePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playbackErrorFramePending = false;
      if (!mounted) return;
      var windows = ref.read(playbackWindowServiceProvider);
      var message = windows.error;
      if (message == null) return;
      windows.clearError();
      unawaited(BtInfobar.error(context, message));
    });
  }

  /// dispose
  @override
  void dispose() {
    if (_isLoggingIn) BangumiOAuthCoordinator.instance.cancel();
    _appLinkSubscription?.cancel();
    flyoutMore.dispose();
    super.dispose();
  }

  /// 展示设置flyout
  void showOptionsFlyout() {
    flyoutMore.showFlyout(
      placementMode: FlyoutPlacementMode.rightCenter,
      additionalOffset: 8,
      forceAvailableSpace: true,
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      dismissWithEsc: true,
      builder: (context) => MenuFlyout(
        items: [
          if (Platform.isWindows) buildPlaybackWinItem(),
          buildResetWinItem(),
          buildPinWinItem(),
        ],
      ),
    );
  }

  /// 退出登录
  Future<void> logoutUser() async {
    await ref.read(bgmUserStoreProvider.notifier).deleteUser();
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
    if (ref.read(bgmUserStoreProvider).accessToken == null) {
      progress.end();
      if (mounted) await BtInfobar.error(context, '未找到访问令牌');
      return;
    }
    var userResp = await ref.read(bangumiRepositoryProvider).getUserInfo();
    if (userResp.code != 0 || userResp.data == null) {
      progress.end();
      if (mounted) await showRespErr(userResp, context);
      return;
    }
    await ref.read(bgmUserStoreProvider.notifier).updateUser(userResp.data!);
    if (!mounted) {
      progress.end();
      return;
    }
    progress.update(title: '获取用户信息成功', text: '用户信息：${_user.user!.nickname}');
    progress.end();
    if (mounted) {
      await BtInfobar.success(
        context,
        '成功获取[${_user.user!.id}]${_user.user!.nickname}信息',
      );
    }
    if (mounted) setState(() {});
  }

  /// 认证用户
  Future<void> oauthUser() async {
    var coordinator = BangumiOAuthCoordinator.instance;
    if (_isLoggingIn || coordinator.isAuthorizing || progress.isShow) return;
    _isLoggingIn = true;
    var authProgress = ProgressWidget.show(
      context,
      title: '登录 Bangumi',
      text: '正在打开浏览器授权页面',
      onCancel: coordinator.cancel,
      cancelText: '取消授权',
    );
    progress = authProgress;
    try {
      var res = await coordinator.authorize(
        apiOauth,
        onProgress: (text) => authProgress.update(text: text),
      );
      if (!mounted || res.code == 499) return;
      if (res.code != 0 || res.data == null) {
        authProgress.end();
        await showRespErr(res, context);
        return;
      }
      authProgress.onCancel = null;
      authProgress.update(text: '保存授权信息');
      var at = res.data as BangumiOauthTokenGetData;
      await ref
          .read(bgmUserStoreProvider.notifier)
          .updateTokenSet(
            accessToken: at.accessToken,
            refreshToken: at.refreshToken,
            expiresIn: at.expiresIn,
          );
      if (mounted) await freshUserInfo();
    } catch (error) {
      BTLogTool.error('用户登录失败：$error');
      authProgress.end();
      if (mounted) await BtInfobar.error(context, '登录失败，请重试');
    } finally {
      authProgress.end();
      _isLoggingIn = false;
    }
  }

  /// 构建打开播放窗口项
  MenuFlyoutItem buildPlaybackWinItem() {
    return MenuFlyoutItem(
      leading: const Icon(FluentIcons.play),
      text: const Text('打开播放窗口'),
      onPressed: () async {
        try {
          await ref.read(playbackWindowServiceProvider).open();
        } catch (error) {
          if (mounted) await reportPlaybackError(context, ref, error);
        }
      },
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
        await ref.read(appStoreProvider.notifier).setThemeMode(config.next);
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
      if (Platform.isWindows)
        PaneItem(
          icon: const Icon(FluentIcons.cloud_download),
          title: const Text('下载管理'),
          body: const DownloadPage(),
        ),
      _user.user == null
          ? PaneItemAction(
              icon: const Icon(FluentIcons.account_management),
              title: const Text('未登录'),
              onTap: () async => oauthUser(),
            )
          : PaneItem(
              icon: CachedNetworkImage(
                imageUrl: BtrBangumiApi.rewriteUrl(_user.user!.avatar.small),
                width: 18,
                height: 18,
                placeholder: (_, _) => const ProgressRing(),
                errorWidget: (_, _, _) => const Icon(FluentIcons.error),
              ),
              title: Text(_user.user!.nickname),
              body: const UserCollectionPage(),
            ),
      if (!Platform.isWindows)
        PaneItem(
          icon: const Icon(FluentIcons.play),
          title: const Text('播放'),
          body: const PlaybackPage(),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var store = ref.watch(navStoreProvider);
    var constItems = getConstItems();
    _schedulePlaybackWindowError();
    // Fluent 只给页面编号；store 的固定位置也包含登录动作。
    var paneIndices = <int>[
      for (var i = 0; i < constItems.length; i++)
        if (constItems[i] is! PaneItemAction && constItems[i].body != null) i,
      for (var i = 0; i < store.navItems.length; i++) store.topNavCount + i,
      store.topNavCount + store.navItems.length,
    ];
    var selected = paneIndices.indexOf(store.curIndex);
    if (selected < 0) {
      // 登出或热重载移除当前页后，回到首页并同步导航状态。
      selected = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(navStoreProvider).curIndex == store.curIndex) {
          ref.read(navStoreProvider.notifier).setCurIndex(paneIndices.first);
        }
      });
    }
    var selectedKey = store.pageKeyForIndex(paneIndices[selected]);
    return NavigationView(
      paneBodyBuilder: (_, _) {
        return NavPageStack(
          key: const ValueKey('nav-page-stack'),
          selectedKey: selectedKey,
          pages: _stackPages(store, constItems, selectedKey),
        );
      },
      pane: NavigationPane(
        selected: selected,
        onChanged: (index) =>
            ref.read(navStoreProvider.notifier).setCurIndex(paneIndices[index]),
        displayMode: PaneDisplayMode.compact,
        items: [...constItems, ..._navItems],
        footerItems: [
          _FlyoutPaneItemAction(
            controller: flyoutMore,
            icon: const Icon(FluentIcons.graph_symbol),
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

  List<NavPageEntry> _stackPages(
    BTNavState store,
    List<PaneItem> constItems,
    String selectedKey,
  ) {
    var alive = store.aliveKeys;
    var entries = <NavPageEntry>[];
    for (var i = 0; i < constItems.length; i++) {
      var item = constItems[i];
      if (item is PaneItemAction || item.body == null) continue;
      var key = 'const_$i';
      if (alive.contains(key) || key == selectedKey) {
        entries.add(NavPageEntry(pageKey: key, body: item.body!));
      }
    }
    for (var item in store.dynamicNavItems) {
      var body = item.body.body;
      if (body == null) continue;
      var key = store.pageKeyForItem(item);
      if (alive.contains(key) || key == selectedKey) {
        entries.add(NavPageEntry(pageKey: key, body: body));
      }
    }
    const settingsKey = BTNavNotifier.settingsPageKey;
    if (alive.contains(settingsKey) || selectedKey == settingsKey) {
      entries.add(
        const NavPageEntry(pageKey: settingsKey, body: SettingPage()),
      );
    }
    return entries;
  }
}

/// 以完整导航按钮为锚点，避免 flyout 遮挡按钮边缘。
class _FlyoutPaneItemAction extends PaneItemAction {
  _FlyoutPaneItemAction({
    required this.controller,
    required super.icon,
    required super.title,
    required super.onTap,
  });

  final FlyoutController controller;

  @override
  Widget build({
    required BuildContext context,
    required bool selected,
    required VoidCallback? onPressed,
    required PaneDisplayMode? displayMode,
    required int itemIndex,
    bool? autofocus,
    bool showTextOnTop = true,
    int depth = 0,
  }) {
    return FlyoutTarget(
      controller: controller,
      child: super.build(
        context: context,
        selected: selected,
        onPressed: onPressed,
        displayMode: displayMode,
        itemIndex: itemIndex,
        autofocus: autofocus,
        showTextOnTop: showTextOnTop,
        depth: depth,
      ),
    );
  }
}
