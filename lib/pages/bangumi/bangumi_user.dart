// Package imports:
import 'package:app_links/app_links.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../components/app/app_dialog.dart';
import '../../components/app/app_dialog_resp.dart';
import '../../components/app/app_infobar.dart';
import '../../controller/app/progress_controller.dart';
import '../../database/bangumi/bangumi_collection.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/bangumi/bangumi_oauth_model.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../request/bangumi/bangumi_oauth.dart';
import '../../store/bgm_user_hive.dart';
import '../../store/nav_store.dart';
import 'bangumi_collection.dart';

/// bangumi 用户界面
class BangumiUserPage extends ConsumerStatefulWidget {
  /// 构造函数
  const BangumiUserPage({super.key});

  @override
  ConsumerState<BangumiUserPage> createState() => _BangumiUserState();
}

/// bangumi 用户界面状态
class _BangumiUserState extends ConsumerState<BangumiUserPage>
    with AutomaticKeepAliveClientMixin {
  /// 用户hive
  final BgmUserHive hive = BgmUserHive();

  /// 数据库-收藏
  final BtsBangumiCollection sqlite = BtsBangumiCollection();

  /// 总收藏数
  late int collectionCount = 0;

  /// 认证相关客户端
  final BtrBangumiOauth oauth = BtrBangumiOauth();

  /// 一般请求客户端
  final BtrBangumiApi api = BtrBangumiApi();

  /// app-link 监听
  final AppLinks _appLinks = AppLinks();

  /// 进度条
  late ProgressController progress = ProgressController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      await init();
    });
  }

  /// 初始化
  Future<void> init() async {
    progress = ProgressWidget.show(
      context,
      title: '读取本地数据库',
      text: '读取tokens',
    );
    if (hive.tokenAC == null ||
        hive.tokenRF == null ||
        hive.expireTime == null) {
      progress.update(text: '未找到访问令牌');
      await Future.delayed(const Duration(milliseconds: 500));
      progress.end();
      if (!mounted) return;
      var oauthConfirm = await showConfirmDialog(
        context,
        title: '未找到访问令牌',
        content: '是否前往授权页面？',
      );
      if (!oauthConfirm) return;
      await oauthUser();
      return;
    }
    progress.update(text: '读取用户信息...');
    var collectionCountGet = await sqlite.getCount();
    collectionCount = collectionCountGet;
    setState(() {});
    if (hive.user != null) {
      progress.update(text: '用户信息：${hive.user!.username}');
      await Future.delayed(const Duration(milliseconds: 500));
      progress.end();
      return;
    }
    progress.update(text: '尝试获取用户信息');
    var isExpired = await hive.checkExpired();
    if (isExpired == null || !isExpired) {
      progress.end();
      if (!mounted) return;
      var freshConfirm = await showConfirmDialog(
        context,
        title: '访问令牌已过期',
        content: '是否尝试刷新？',
      );
      if (!freshConfirm) return;
      await freshToken();
    }
    await freshUserInfo();
  }

  /// 刷新访问令牌
  Future<void> freshToken() async {
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
    // todo 存在bug
    var res = await hive.refreshAuth(onErr: (e) async {
      if (mounted) await showRespErr(e, context);
    });
    if (res == null || !res) {
      progress.end();
      return;
    }
    progress.end();
    if (mounted) await BtInfobar.success(context, '刷新访问令牌成功 ${hive.tokenAC}');
  }

  /// 认证用户
  Future<void> oauthUser() async {
    if (progress.isShow) {
      progress.update(title: '处理用户授权', text: '正在前往授权页面', progress: null);
    } else {
      progress = ProgressWidget.show(context, title: '前往授权页面');
    }
    await oauth.openAuthorizePage();
    progress.update(text: '等待授权回调');
    _appLinks.uriLinkStream.listen((uri) async {
      if (uri.toString().startsWith('bangumitoday://oauth')) {
        progress.update(text: '处理授权回调');
        var code = uri.queryParameters['code'];
        if (code == null) {
          await BtInfobar.error(context, '授权失败：未找到授权码');
          progress.end();
          // 停止监听
          _appLinks.uriLinkStream.listen((_) {});
          return;
        }
        progress.update(text: '授权码：$code');
        var res = await oauth.getAccessToken(code);
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
    var userResp = await api.getUserInfo();
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

  /// 构建顶部栏
  Widget buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Tooltip(
          message: '返回',
          child: IconButton(
            icon: const Icon(FluentIcons.back),
            onPressed: () {
              ref.read(navStoreProvider).removeNavItem('Bangumi 用户界面');
            },
          ),
        ),
        SizedBox(width: 16.w),
        Image.asset('assets/images/platforms/bangumi-text.png'),
        SizedBox(width: 16.w),
        Tooltip(
          message: '刷新',
          child: IconButton(
            icon: const Icon(FluentIcons.refresh),
            onPressed: () async {
              await init();
            },
          ),
        ),
        const Spacer(),
        SizedBox(
          height: 36.spMax,
          child: Image.asset(
            'assets/images/platforms/bangumi-logo.png',
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(width: 16.w),
      ],
    );
  }

  /// 构建用户
  Widget buildUser() {
    if (hive.user == null) {
      return ListTile(
        leading: const Icon(FluentIcons.user_window),
        title: const Text('用户信息'),
        subtitle: const Text('未找到用户信息'),
        trailing: FilledButton(
          child: const Text('前往授权'),
          onPressed: () async {
            await oauthUser();
          },
        ),
      );
    }
    return ListTile(
      leading: CachedNetworkImage(
        imageUrl: hive.user!.avatar.large,
        width: 32.spMax,
        height: 32.spMax,
        placeholder: (context, url) => const ProgressRing(),
        errorWidget: (context, url, error) => const Icon(FluentIcons.error),
      ),
      title: Text(hive.user!.nickname),
      subtitle: Text('ID: ${hive.user!.id}(${hive.user!.userGroup.label})'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            child: const Tooltip(
              message: '刷新用户信息',
              child: Icon(FluentIcons.refresh),
            ),
            onPressed: () async {
              var freshConfirm = await showConfirmDialog(
                context,
                title: '刷新用户信息',
                content: '是否刷新用户信息？',
              );
              if (!freshConfirm) return;
              await freshUserInfo();
            },
          ),
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
          FilledButton(
            child: const Text('刷新授权'),
            onPressed: () async {
              await freshToken();
            },
          ),
          SizedBox(width: 8.w),
          FilledButton(
            child: const Text('重新授权'),
            onPressed: () async {
              await oauthUser();
            },
          ),
          SizedBox(width: 8.w),
          FilledButton(
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
          FilledButton(
            child: const Text('查看收藏'),
            onPressed: () async {
              var paneItem = PaneItem(
                icon: const Icon(FluentIcons.favorite_star),
                title: const Text('Bangumi-用户收藏'),
                body: const BangumiCollectionPage(),
              );
              ref.read(navStoreProvider).addNavItem(paneItem, 'Bangumi-用户收藏');
            },
          ),
          SizedBox(width: 8.w),
          FilledButton(
            child: const Text('刷新收藏'),
            onPressed: () async {
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
              var resp = await api.getCollectionSubjects(
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
              var pageResp =
                  resp.data as BangumiPageT<BangumiUserSubjectCollection>;
              var total = pageResp.total;
              while (checkFlag) {
                offset += pageResp.data.length;
                for (var item in pageResp.data) {
                  progress.update(
                    title: '正在写入收藏信息：$cnt/$total',
                    text: '[${item.subject.id}] ${item.subject.name}',
                    progress: cnt / total,
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
                  title: '正在获取收藏信息',
                  text: '偏移：$offset，总计：$total',
                  progress: null,
                );
                resp = await api.getCollectionSubjects(
                  username: hive.user!.id.toString(),
                  limit: limit,
                  offset: offset,
                );
                if (resp.code != 0 || resp.data == null) {
                  progress.end();
                  if (mounted) await showRespErr(resp, context);
                  return;
                }
                pageResp =
                    resp.data as BangumiPageT<BangumiUserSubjectCollection>;
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(
      header: buildHeader(),
      content: ListView(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        children: [
          Card(padding: EdgeInsets.zero, child: buildUser()),
          SizedBox(height: 16.h),
          Card(padding: EdgeInsets.zero, child: buildOauth()),
          SizedBox(height: 16.h),
          Card(padding: EdgeInsets.zero, child: buildCollection()),
        ],
      ),
    );
  }
}
