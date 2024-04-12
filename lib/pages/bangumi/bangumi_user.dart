import 'package:app_links/app_links.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../components/app/app_dialog.dart';
import '../../components/app/app_dialog_resp.dart';
import '../../components/app/app_infobar.dart';
import '../../controller/app/progress_controller.dart';
import '../../database/bangumi/bangumi_user.dart';
import '../../models/bangumi/bangumi_oauth_model.dart';
import '../../models/bangumi/user_request.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../request/bangumi/bangumi_oauth.dart';
import '../../store/nav_store.dart';

/// bangumi 用户界面
class BangumiUser extends ConsumerStatefulWidget {
  /// 构造函数
  const BangumiUser({super.key});

  @override
  ConsumerState<BangumiUser> createState() => _BangumiUserState();
}

/// bangumi 用户界面状态
class _BangumiUserState extends ConsumerState<BangumiUser>
    with AutomaticKeepAliveClientMixin {
  /// 用户数据
  BangumiUserInfo? user;

  /// 数据库
  final BtsBangumiUser sqlite = BtsBangumiUser();

  /// 认证相关客户端
  final BtrBangumiOauth oauth = BtrBangumiOauth();

  /// 一般请求客户端
  final BtrBangumiApi api = BtrBangumiApi();

  /// app-link 监听
  final AppLinks _appLinks = AppLinks();

  /// 授权过期时间
  late DateTime expireTime = DateTime.now();

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
    var atGet = await sqlite.readAccessToken();
    var rtGet = await sqlite.readRefreshToken();
    var etGet = await sqlite.readExpireTime();
    if (atGet == null || rtGet == null || etGet == null) {
      progress.update(text: '未找到访问令牌');
      await Future.delayed(Duration(milliseconds: 500));
      progress.end();
      var oauthConfirm = await showConfirmDialog(
        context,
        title: '未找到访问令牌',
        content: '是否前往授权页面？',
      );
      if (!oauthConfirm) return;
      await oauthUser();
      return;
    }
    expireTime = etGet;
    setState(() {});
    progress.update(text: '读取用户信息...');
    user = await sqlite.readUser();
    setState(() {});
    if (user != null) {
      progress.update(text: '用户信息：${user!.username}');
      await Future.delayed(Duration(milliseconds: 500));
      progress.end();
      return;
    }
    progress.update(text: '尝试获取用户信息');
    var isExpired = await sqlite.isTokenExpired();
    if (isExpired) {
      progress.end();
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
    var rt = await sqlite.readRefreshToken();
    if (rt == null) {
      progress.end();
      await BtInfobar.error(context, '未找到刷新令牌');
      return;
    }
    var res = await oauth.refreshToken(rt);
    if (res.code != 0 || res.data == null) {
      progress.end();
      showRespErr(res, context);
      return;
    }
    assert(res.data != null);
    var at = res.data as BangumiOauthTokenRefreshData;
    progress.update(title: '刷新访问令牌成功', text: '访问令牌：${at.accessToken}');
    await sqlite.writeAccessToken(at.accessToken);
    await sqlite.writeRefreshToken(at.refreshToken);
    await sqlite.writeExpireTime(at.expiresIn);
    expireTime = (await sqlite.readExpireTime())!;
    setState(() {});
    await Future.delayed(Duration(milliseconds: 500));
    progress.end();
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
          showRespErr(res, context);
          return;
        }
        assert(res.data != null);
        var at = res.data as BangumiOauthTokenGetData;
        await sqlite.writeAccessToken(at.accessToken);
        await sqlite.writeRefreshToken(at.refreshToken);
        await sqlite.writeExpireTime(at.expiresIn);
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
    var at = await sqlite.readAccessToken();
    if (at == null) {
      progress.end();
      await BtInfobar.error(context, '未找到访问令牌');
      return;
    }
    await api.refreshGetAccessToken(token: at);
    var userResp = await api.getUserInfo();
    if (userResp.code != 0 || userResp.data == null) {
      progress.end();
      showRespErr(userResp, context);
      return;
    }
    user = userResp.data! as BangumiUserInfo;
    progress.update(title: '获取用户信息成功', text: '用户信息：${user!.username}');
    await sqlite.writeUser(user!);
    await Future.delayed(Duration(milliseconds: 500));
    progress.end();
  }

  /// 构建顶部栏
  Widget buildHeader() {
    var titleW = Text('Bangumi 用户界面');
    return PageHeader(
      title: titleW,
      leading: IconButton(
        icon: Icon(FluentIcons.back),
        onPressed: () {
          ref.read(navStoreProvider).removeNavItem('Bangumi 用户界面');
        },
      ),
    );
  }

  /// 构建用户
  Widget buildUser() {
    if (user == null) {
      return ListTile(
        leading: Icon(FluentIcons.user_window),
        title: Text('用户信息'),
        subtitle: Text('未找到用户信息'),
        trailing: FilledButton(
          child: Text('前往授权'),
          onPressed: () async {
            await oauthUser();
          },
        ),
      );
    }
    assert(user != null);
    return ListTile(
      leading: CachedNetworkImage(
        imageUrl: user!.avatar.large,
        width: 32.spMax,
        height: 32.spMax,
        placeholder: (context, url) => ProgressRing(),
        errorWidget: (context, url, error) => Icon(FluentIcons.error),
      ),
      title: Text(user?.nickname ?? '用户信息'),
      subtitle: Text('ID: ${user?.id ?? 'unknown'}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            child: Tooltip(
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
      leading: Icon(FluentIcons.authenticator_app),
      title: Text('授权信息'),
      subtitle: expireTime == DateTime.now()
          ? Text('未找到授权信息')
          : Text(
              '授权过期时间：$expireTime',
            ),
      trailing: Row(
        children: [
          FilledButton(
            child: Text('刷新授权'),
            onPressed: () async {
              await freshToken();
            },
          ),
          SizedBox(width: 8.w),
          FilledButton(
            child: Text('重新授权'),
            onPressed: () async {
              await oauthUser();
            },
          ),
          SizedBox(width: 8.w),
          FilledButton(
            child: Text('查看授权'),
            onPressed: () async {
              await launchUrlString("https://next.bgm.tv/demo/access-token");
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
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        children: [
          buildUser(),
          buildOauth(),
        ],
      ),
    );
  }
}
