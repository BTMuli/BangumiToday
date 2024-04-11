import 'package:dart_rss/domain/rss_item.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../components/app/app_dialog.dart';
import '../../components/app/app_infobar.dart';
import '../../components/mikan/mk_rss_card.dart';
import '../../request/mikan/mikan_api.dart';
import '../../tools/config_tool.dart';

/// 负责 MikanProject RSS 页面的显示
/// 包括 RSSClassic 和 RSSPersonal
/// 前者是列表模式显示站点的RSS更新，后者是个人订阅的RSS更新
class MikanRSSPage extends StatefulWidget {
  /// 构造函数
  const MikanRSSPage({super.key});

  @override
  State<MikanRSSPage> createState() => _MikanRSSPageState();
}

/// MikanRSS 页面状态
class _MikanRSSPageState extends State<MikanRSSPage>
    with AutomaticKeepAliveClientMixin {
  /// 请求客户端
  final MikanAPI mikanAPI = MikanAPI();

  /// RSS 数据
  late List<RssItem> rssItems = [];

  /// RSS 数据
  late List<RssItem> userItems = [];

  /// 用户订阅的 token
  late String token = '';

  /// 是否使用用户订阅
  late bool useUserRSS = false;

  /// 配置工具
  final BTConfigTool configTool = BTConfigTool();

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      await init();
    });
  }

  /// 刷新
  Future<void> refreshMikanRSS() async {
    rssItems.clear();
    setState(() {});
    var res = await mikanAPI.getClassicRSS();
    rssItems = res;
    setState(() {});
    await BtInfobar.success(context, '已刷新Mikan列表');
  }

  /// 刷新
  Future<void> refreshUserRSS() async {
    userItems.clear();
    setState(() {});
    var res = await mikanAPI.getUserRSS(token);
    userItems = res;
    setState(() {});
    await BtInfobar.success(context, '已刷新用户列表');
  }

  /// 初始化
  Future<void> init() async {
    var mikan = await configTool.readConfig(key: 'mikan');
    if (mikan == null) {
      useUserRSS = false;
      await configTool.writeConfig('mikan', {'enable': false});
      await refreshMikanRSS();
      return;
    }
    token = await getToken(mikan['token'] ?? '');
    useUserRSS = mikan['enable'] ?? false;
    if (useUserRSS && token != '') {
      await refreshUserRSS();
    } else {
      await refreshMikanRSS();
    }
  }

  /// 解析 token
  Future<String> getToken(String token) async {
    if (await canLaunchUrlString(token)) {
      var link = Uri.parse(token);
      debugPrint(link.toString());
      // todo 站点校验
      return link.queryParameters['token'] ?? token;
    }
    return token;
  }

  /// 构建刷新按钮
  Widget buildAct() {
    return Tooltip(
      message: '刷新',
      child: IconButton(
        icon: Icon(FluentIcons.refresh),
        onPressed: () async {
          if (useUserRSS) {
            await refreshUserRSS();
          } else {
            await refreshMikanRSS();
          }
        },
      ),
    );
  }

  /// 构建标题
  Widget buildTitle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/platforms/mikan-logo.png',
          height: 60.h,
          fit: BoxFit.cover,
        ),
        Image.asset(
          'assets/images/platforms/mikan-text.png',
          height: 60.h,
          fit: BoxFit.cover,
        ),
        SizedBox(width: 20.w),
        IconButton(
          icon: Icon(FluentIcons.refresh, size: 30.h),
          onPressed: () async {
            if (useUserRSS) {
              await refreshUserRSS();
            } else {
              await refreshMikanRSS();
            }
          },
        ),
        SizedBox(width: 10.w),
        ...buildTokenBar()
      ],
    );
  }

  /// 构建 Token 栏
  List<Widget> buildTokenBar() {
    return [
      ToggleSwitch(
        checked: useUserRSS,
        onChanged: (v) async {
          var old = useUserRSS;
          useUserRSS = v;
          if (token == '' && v) {
            useUserRSS = false;
          } else if (!v && rssItems.isEmpty) {
            await refreshMikanRSS();
          } else if (v && userItems.isEmpty) {
            await refreshUserRSS();
          }
          if (v != old) {
            if (v) {
              await BtInfobar.success(context, '已切换到用户列表');
            } else {
              await BtInfobar.success(context, '已切换到Mikan列表');
            }
          }
          setState(() {});
        },
      ),
      SizedBox(width: 10.w),
      FilledButton(
        child: Text('Token: $token'),
        onPressed: null,
      ),
      SizedBox(width: 10.w),
      Button(
        onPressed: () async {
          var input = await showInputDialog(
            context,
            title: '输入 Token',
            content: '请输入你的 Token\n（在蜜柑计划的个人中心可以找到）',
          );
          if (input == null || input == "") {
            BtInfobar.warn(context, '未输入 Token');
            return;
          }
          token = await getToken(input);
          // todo 迁移到数据库
          await configTool.writeConfig('mikan', {
            'enable': true,
            'token': token,
          });
          await refreshUserRSS();
        },
        child: Text('编辑Token'),
      )
    ];
  }

  /// 构建内容
  Widget buildContent(List<RssItem> data) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProgressRing(),
            SizedBox(height: 20.h),
            Text('正在加载数据...'),
          ],
        ),
      );
    } else {
      return ListView.builder(
        itemCount: data.length,
        itemBuilder: (context, index) {
          var item = data[index];
          return MikanRssCard(item);
        },
      );
    }
  }

  /// 构建函数
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(
      header: PageHeader(title: buildTitle()),
      content: Center(
        child: buildContent(useUserRSS ? userItems : rssItems),
      ),
    );
  }
}
