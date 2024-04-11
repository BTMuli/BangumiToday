import 'package:app_links/app_links.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/app/app_dialog.dart';
import '../../components/app/app_dialog_resp.dart';
import '../../components/app/app_infobar.dart';
import '../../controller/app/progress_controller.dart';
import '../../database/bangumi/bangumi_user.dart';
import '../../models/bangumi/oauth.dart';
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
class _BangumiUserState extends ConsumerState<BangumiUser> {
  /// 用户数据
  BangumiUserInfo? user;

  /// 数据库
  final BtsBangumiUser sqlite = BtsBangumiUser();

  /// 认证相关客户端
  final BangumiOauth oauth = BangumiOauth();

  /// 一般请求客户端
  final BangumiAPI api = BangumiAPI();

  /// app-link 监听
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      await init();
    });
  }

  /// 初始化
  Future<void> init() async {
    var progress = AppProgress(context, title: '读取本地数据库');
    progress.start();
    user = await sqlite.readUser();
    if (user != null) {
      progress.update(title: '读取本地数据库成功', text: '用户信息：${user!.username}');
      await Future.delayed(Duration(milliseconds: 500));
      progress.end();
      return;
    }
    progress.update(title: '读取用户数据失败', text: '尝试刷新数据');
    var atGet = await sqlite.readAccessToken();
    if (atGet == null) {
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
    var atResp = await oauth.getStatus(atGet);
    if (atResp.code != 0 || atResp.data == null) {
      progress.end();
      showRespErr(atResp, context);
      return;
    }
    progress.update(title: '访问令牌有效', text: '尝试获取用户信息');
    var atRespd = atResp.data! as BangumiTstrData;
    var at = atRespd.accessToken;
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
    progress.end();
  }

  /// 认证用户
  Future<void> oauthUser() async {
    var progress = AppProgress(context, title: '前往授权页面');
    progress.start();
    await oauth.openAuthorizePage();
    progress.update(title: '等待授权回调');
    _appLinks.uriLinkStream.listen((uri) async {
      if (uri.toString().startsWith('bangumitoday://oauth')) {
        progress.update(title: '处理授权回调');
        var code = uri.queryParameters['code'];
        if (code == null) {
          await BtInfobar.error(context, '授权失败：未找到授权码');
          progress.end();
          // 停止监听
          _appLinks.uriLinkStream.listen((_) {});
          return;
        }
        progress.update(title: '获取访问令牌');
        await freshUser(code, progress);
      }
    });
  }

  /// 刷新用户
  Future<void> freshUser(String code, AppProgress progress) async {
    progress.update(text: '获取AccessToken');
    var res = await oauth.getAccessToken(code);
    await sqlite.writeAccessToken(res.accessToken);
    await api.refreshGetAccessToken(token: res.accessToken);
    await sqlite.writeRefreshToken(res.refreshToken);
    progress.update(text: '获取用户信息');
    var userResp = await api.getUserInfo();
    if (userResp.code != 0 || userResp.data == null) {
      progress.end();
      showRespErr(userResp, context);
      return;
    }
    user = userResp.data! as BangumiUserInfo;
    progress.update(
      title: '获取用户信息成功',
      text: '请关闭授权页面',
    );
    await sqlite.writeUser(user!);
    await Future.delayed(Duration(seconds: 1));
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
          ref.read(navStoreProvider).removeNavItemByTitle(titleW.toString());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: buildHeader(),
      content: Center(
        child: Text('bangumi 用户界面'),
      ),
    );
  }
}
