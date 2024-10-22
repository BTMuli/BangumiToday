// Package imports:
import 'package:app_links/app_links.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../controller/app/progress_controller.dart';
import '../../database/bangumi/bangumi_collection.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/bangumi_oauth_model.dart';
import '../../pages/bangumi/bangumi_collection.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../request/bangumi/bangumi_oauth.dart';
import '../../store/bgm_user_hive.dart';
import '../../store/nav_store.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_icon.dart';
import '../../ui/bt_infobar.dart';

/// 设置页BangumiUserInfo
class AppConfigBgmWidget extends ConsumerStatefulWidget {
  /// 构造函数
  const AppConfigBgmWidget({super.key});

  @override
  ConsumerState<AppConfigBgmWidget> createState() => _AppConfigBgmWidgetState();
}

class _AppConfigBgmWidgetState extends ConsumerState<AppConfigBgmWidget> {
  /// 用户 hive
  final BgmUserHive hive = BgmUserHive();

  /// 收藏数据库
  final BtsBangumiCollection sqlite = BtsBangumiCollection();

  /// 总收藏数
  late int collectionCount = 0;

  /// 认证相关客户端
  final BtrBangumiOauth apiOauth = BtrBangumiOauth();

  /// Bangumi 请求客户端
  final BtrBangumiApi apiBgm = BtrBangumiApi();

  /// app-link 监听
  final AppLinks appLinks = AppLinks();

  /// 进度条
  late ProgressController progress = ProgressController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async => await init());
  }

  /// 初始化
  Future<void> init() async {
    if (hive.tokenAC == null ||
        hive.tokenRF == null ||
        hive.expireTime == null) {
      return;
    }
    collectionCount = await sqlite.getCount();
    setState(() {});
  }

  /// 刷新访问令牌
  Future<void> freshToken({bool force = false}) async {
    if (progress.isShow) {
      progress.update(title: '刷新访问令牌', text: '正在刷新访问令牌', progress: null);
    } else {
      progress = ProgressWidget.show(context, title: '刷新访问令牌');
    }
    if (hive.tokenRF == null) {
      progress.end();
      if (mounted) await BtInfobar.error(context, '未找到刷新令牌');
      return;
    }
    var res = await hive.refreshAuth(force: force);
    if (res == null || !res) {
      progress.end();
    }
    if (res == null && mounted) {
      var confirm = await showConfirm(
        context,
        title: '确认刷新？',
        content: '检测到令牌未过期，是否仍然刷新令牌？',
      );
      if (!confirm) {
        progress.end();
        return;
      }
      await freshToken(force: true);
      return;
    }
    progress.end();
    if (mounted) await BtInfobar.success(context, '刷新访问令牌成功 ${hive.tokenAC}');
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
    progress.update(title: '获取用户信息成功', text: '用户信息：${hive.user!.username}');
    await Future.delayed(const Duration(milliseconds: 500));
    progress.end();
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

  /// 刷新收藏
  Future<void> refreshCollection() async {
    if (hive.user == null) {
      await BtInfobar.error(context, '未找到用户信息');
      return;
    }
    progress = ProgressWidget.show(
      context,
      title: '刷新收藏信息',
      text: '正在刷新收藏信息',
      onTaskbar: true,
    );
    const limit = 50;
    var offset = 0;
    var resp = await apiBgm.getCollectionSubjects(
      username: hive.user!.id.toString(),
      limit: limit,
      offset: offset,
    );
    if (resp.code != 0 || resp.data == null) {
      progress.end();
      if (mounted) await showRespErr(resp, context);
      return;
    }
    await sqlite.preCheck();
    var checkFlag = true;
    var cnt = 1;
    BangumiPageT<BangumiUserSubjectCollection> pageResp = resp.data;
    var total = pageResp.total;
    while (checkFlag) {
      offset += pageResp.data.length;
      for (var item in pageResp.data) {
        progress.update(
          title: '写入收藏信息：$cnt/$total',
          text: '[${item.subject.id}] ${item.subject.name}',
          progress: cnt * 100 / total,
        );
        await sqlite.write(item, check: false);
        cnt++;
      }
      if (offset >= total) {
        checkFlag = false;
        progress.end();
        if (mounted) await BtInfobar.success(context, '收藏信息写入完成');
        break;
      }
      progress.update(
        title: '获取收藏信息',
        text: '偏移：$offset，总计：$total',
        progress: null,
      );
      resp = await apiBgm.getCollectionSubjects(
        username: hive.user!.id.toString(),
        limit: limit,
        offset: offset,
      );
      if (resp.code != 0 || resp.data == null) {
        progress.end();
        if (mounted) await showRespErr(resp, context);
        return;
      }
      pageResp = resp.data;
    }
  }

  /// 跳转到用户收藏
  Future<void> toUserCollection() async {
    var paneItem = PaneItem(
      icon: const BtIcon(FluentIcons.favorite_star),
      title: const Text('Bangumi-用户收藏'),
      body: const BangumiCollectionPage(),
    );
    ref.read(navStoreProvider).addNavItem(paneItem, 'Bangumi-用户收藏');
  }

  /// 尝试刷新用户信息
  Future<void> tryRefreshUserInfo() async {
    if (hive.user == null) {
      await BtInfobar.error(context, '未找到用户信息');
      return;
    }
    var freshConfirm = await showConfirm(
      context,
      title: '刷新用户信息',
      content: '是否刷新用户信息？',
    );
    if (!freshConfirm) return;
    await freshUserInfo();
  }

  /// 尝试删除用户信息
  Future<void> tryDeleteUserInfo() async {
    if (hive.user == null) {
      await BtInfobar.error(context, '未找到用户信息');
      return;
    }
    var deleteConfirm = await showConfirm(
      context,
      title: '删除用户信息',
      content: '是否删除用户信息？',
    );
    if (!deleteConfirm) return;
    await hive.deleteUser();
    setState(() {});
  }

  /// 构建用户刷新按钮
  Widget buildUserFreshBtn() {
    return FilledButton(
      onPressed: tryRefreshUserInfo,
      child: const Tooltip(
        message: '刷新用户信息',
        child: BtIcon(FluentIcons.refresh),
      ),
    );
  }

  /// 构建用户删除按钮
  Widget buildUserDelBtn() {
    return FilledButton(
      onPressed: tryDeleteUserInfo,
      child: const Tooltip(
        message: '删除用户',
        child: BtIcon(FluentIcons.delete),
      ),
    );
  }

  /// 构建用户
  Widget buildUser() {
    if (hive.user == null) {
      return ListTile(
        leading: const Icon(FluentIcons.user_sync),
        title: const Text('用户信息'),
        subtitle: const Text('未找到用户信息'),
        trailing: FilledButton(onPressed: oauthUser, child: const Text('前往授权')),
      );
    }
    return ListTile(
      leading: CachedNetworkImage(
        imageUrl: hive.user!.avatar.small,
        width: 20,
        height: 20,
        placeholder: (_, __) => const ProgressRing(),
        errorWidget: (_, __, ___) => const Icon(FluentIcons.error),
      ),
      title: Text(hive.user!.nickname),
      subtitle: Text('ID: ${hive.user!.id}(${hive.user!.userGroup.label})'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildUserFreshBtn(),
          SizedBox(width: 8.w),
          buildUserDelBtn(),
        ],
      ),
    );
  }

  /// 构建授权信息
  Widget buildOauth() {
    return ListTile(
      leading: const Icon(FluentIcons.authenticator_app),
      title: const Text('授权信息'),
      subtitle: hive.expireTime == DateTime.now()
          ? const Text('未找到授权信息')
          : Text('授权过期时间：${hive.expireTime}'),
      trailing: Row(
        children: [
          Button(onPressed: freshToken, child: const Text('刷新授权')),
          SizedBox(width: 8.w),
          Button(onPressed: oauthUser, child: const Text('重新授权')),
          SizedBox(width: 8.w),
          Button(
            child: const Text('查看授权'),
            onPressed: () async {
              await launchUrlString("https://next.bgm.tv/demo/access-token");
            },
          ),
        ],
      ),
    );
  }

  /// 构建收藏
  Widget buildCollection() {
    return ListTile(
      leading: const Icon(FluentIcons.favorite_star),
      title: const Text('收藏信息'),
      subtitle: Text('收藏数：$collectionCount'),
      trailing: Row(
        children: [
          Button(onPressed: toUserCollection, child: const Text('查看收藏')),
          SizedBox(width: 8.w),
          Button(onPressed: refreshCollection, child: const Text('刷新收藏')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expander(
      leading: Icon(FluentIcons.user_window),
      header: const Text('Bangumi 用户信息'),
      content: Column(children: [buildUser(), buildOauth(), buildCollection()]),
    );
  }
}
