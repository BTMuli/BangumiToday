// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../controller/app/progress_controller.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../providers/app_providers.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../store/bgm_user_hive.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import 'uc_pw_tab.dart';

/// user-collection.tv 用户收藏页面
class UserCollectionPage extends ConsumerStatefulWidget {
  /// 构造函数
  const UserCollectionPage({super.key});

  @override
  ConsumerState<UserCollectionPage> createState() => _UserCollectionPageState();
}

/// user-collection.tv 用户收藏页面状态
class _UserCollectionPageState extends ConsumerState<UserCollectionPage>
    with AutomaticKeepAliveClientMixin {
  /// tabIndex
  int tabIndex = 0;

  /// 用户菜单 flyout 控制器
  final FlyoutController flyoutUser = FlyoutController();

  /// 用户 hive
  final BgmUserHive hive = BgmUserHive();

  /// 进度条
  late ProgressController progress = ProgressController();

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// 构建标签
  List<Tab> buildTabs() {
    var values = [
      BangumiCollectionType.doing,
      BangumiCollectionType.wish,
      BangumiCollectionType.collect,
      BangumiCollectionType.onHold,
      BangumiCollectionType.dropped,
    ];
    var result = <Tab>[];
    for (var i = 0; i < values.length; i++) {
      var type = values[i];
      result.add(
        Tab(
          selectedBackgroundColor: WidgetStateColor.resolveWith(
            (_) => FluentTheme.of(context).accentColor,
          ),
          icon: Icon(type.icon),
          text: Text(type.label),
          body: UcpTabWidget(type),
        ),
      );
    }
    return result;
  }

  /// 刷新授权
  Future<void> refreshAuth() async {
    var result = await hive.refreshAuth(force: true);
    if (!mounted) return;
    if (result == null) {
      await BtInfobar.info(context, '授权未过期，无需刷新');
    } else if (result) {
      await BtInfobar.success(context, '授权刷新成功');
    } else {
      await BtInfobar.error(context, '授权刷新失败');
    }
  }

  /// 展示用户菜单flyout
  void showUserMenuFlyout() {
    flyoutUser.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      dismissWithEsc: true,
      margin: 40,
      horizontalOffset: 36,
      builder: (context) => MenuFlyout(items: buildUserMenuItems()),
    );
  }

  /// 构建用户菜单项
  List<MenuFlyoutItemBase> buildUserMenuItems() {
    return [
      MenuFlyoutItem(
        leading: const Icon(FluentIcons.refresh),
        text: const Text('刷新用户信息'),
        onPressed: () async {
          await refreshUserInfo();
        },
      ),
      MenuFlyoutItem(
        leading: const Icon(FluentIcons.permissions),
        text: const Text('刷新授权'),
        onPressed: () async {
          await refreshAuth();
        },
      ),
      const MenuFlyoutSeparator(),
      MenuFlyoutItem(
        leading: const Icon(FluentIcons.sign_out),
        text: const Text('退出登录'),
        onPressed: () async {
          await logoutUser();
        },
      ),
    ];
  }

  /// 刷新用户信息
  Future<void> refreshUserInfo() async {
    if (hive.tokenAC == null) {
      if (mounted) await BtInfobar.error(context, '未找到访问令牌');
      return;
    }
    if (progress.isShow) {
      progress.update(title: '获取用户信息', text: '正在获取用户信息', progress: null);
    } else {
      progress = ProgressWidget.show(context, title: '获取用户信息');
    }
    var repository = ref.read(bangumiRepositoryProvider);
    var userResp = await repository.getUserInfo();
    if (userResp.code != 0 || userResp.data == null) {
      progress.end();
      if (mounted) await showRespErr(userResp, context);
      return;
    }
    await hive.updateUser(userResp.data!);
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

  /// 退出登录
  Future<void> logoutUser() async {
    await hive.deleteUser();
    if (mounted) {
      await BtInfobar.success(context, '已成功退出登录');
    }
    setState(() {});
  }

  /// 构建用户图标（根据登录状态）
  Widget buildUserIcon() {
    if (hive.user == null) {
      return const Icon(FluentIcons.account_management);
    }
    return CachedNetworkImage(
      imageUrl: BtrBangumiApi.rewriteUrl(hive.user!.avatar.small),
      width: 24,
      height: 24,
      placeholder: (_, _) => const ProgressRing(),
      errorWidget: (_, _, _) => const Icon(FluentIcons.error),
    );
  }

  /// 构建底部
  Widget buildFooter() {
    return Row(
      children: [
        FlyoutTarget(
          controller: flyoutUser,
          child: IconButton(
            icon: buildUserIcon(),
            onPressed: showUserMenuFlyout,
          ),
        ),
        SizedBox(width: 4),
        Image.asset('assets/images/platforms/bangumi-logo.png'),
      ],
    );
  }

  /// build
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TabView(
      tabs: buildTabs(),
      header: Image.asset('assets/images/platforms/bangumi-text.png'),
      currentIndex: tabIndex,
      onChanged: (index) => setState(() => tabIndex = index),
      footer: buildFooter(),
      closeButtonVisibility: CloseButtonVisibilityMode.never,
      tabWidthBehavior: TabWidthBehavior.sizeToContent,
    );
  }
}
