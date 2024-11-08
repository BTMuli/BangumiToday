// Package imports:
import 'package:dart_rss/domain/rss_item.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../database/app/app_config.dart';
import '../../plugins/mikan/mikan_api.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import 'rss_mk_card2.dart';

/// 负责 MikanProject RSS 页面的显示
/// 包括 RSSClassic 和 RSSPersonal
/// 前者是列表模式显示站点的RSS更新，后者是个人订阅的RSS更新
class RssMkPage extends StatefulWidget {
  /// 构造函数
  const RssMkPage({super.key});

  @override
  State<RssMkPage> createState() => _RssMkPageState();
}

/// MikanRSS 页面状态
class _RssMkPageState extends State<RssMkPage>
    with AutomaticKeepAliveClientMixin {
  /// 请求客户端
  final BtrMikanApi mikanAPI = BtrMikanApi();

  /// RSS 数据
  late List<RssItem> rssItems = [];

  /// RSS 数据
  late List<RssItem> userItems = [];

  /// 用户订阅的 token
  late String token = '';

  /// 是否使用用户订阅
  late bool useUserRSS = false;

  /// 数据库
  final BtsAppConfig sqlite = BtsAppConfig();

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, init);
  }

  /// 刷新
  Future<void> refreshMikanRSS() async {
    rssItems.clear();
    setState(() {});
    var resGet = await mikanAPI.getClassicRSS();
    if (resGet.code != 0 || resGet.data == null) {
      if (mounted) await showRespErr(resGet, context);
      return;
    }
    rssItems = resGet.data!;
    setState(() {});
    if (mounted) await BtInfobar.success(context, '已刷新Mikan列表');
  }

  /// 刷新
  Future<void> refreshUserRSS() async {
    userItems.clear();
    setState(() {});
    var resGet = await mikanAPI.getUserRSS(token);
    if (resGet.code != 0 || resGet.data == null) {
      if (mounted) await showRespErr(resGet, context);
      return;
    }
    userItems = resGet.data!;
    setState(() {});
    if (mounted) await BtInfobar.success(context, '已刷新用户列表');
  }

  /// 初始化
  Future<void> init() async {
    var mikan = await sqlite.readMikanToken();
    if (mikan == null || mikan.isEmpty) {
      useUserRSS = false;
      await refreshMikanRSS();
      return;
    }
    token = mikan;
    useUserRSS = true;
    await refreshUserRSS();
  }

  /// 解析 token
  Future<String> getToken(String token) async {
    if (await canLaunchUrlString(token)) {
      var link = Uri.parse(token);
      return link.queryParameters['token'] ?? token;
    }
    return token;
  }

  Future<void> tryEditToken() async {
    var input = await showInput(
      context,
      title: '输入 Token',
      content: '请输入你的 Token\n（在蜜柑计划的个人中心可以找到）',
    );
    if (input == null || input == "") {
      if (mounted) await BtInfobar.warn(context, '未输入 Token');
      return;
    }
    var parsed = await getToken(input);
    if (parsed == token) {
      if (mounted) await BtInfobar.warn(context, 'Token 未变更');
      return;
    }
    token = parsed;
    await sqlite.writeMikanToken(token);
    if (mounted) await BtInfobar.success(context, 'Token 已保存');
    useUserRSS = true;
    setState(() {});
  }

  Future<void> tryEditUrl() async {
    var url = await sqlite.readMikanUrl();
    if (url == null || url.isEmpty) url = defaultMikanMirror;
    if (mounted) {
      var input = await showInput(
        context,
        title: '输入 URL',
        content: '请输入你的 Mikan URL\n（默认为 $defaultMikanMirror）',
        value: url,
      );
      if (input == null || input == "") {
        if (mounted) await BtInfobar.warn(context, '未输入 URL');
        return;
      }
      if (input == url) {
        if (mounted) await BtInfobar.warn(context, 'URL 未变更');
        return;
      }
      await sqlite.writeMikanUrl(input);
      if (mounted) await BtInfobar.success(context, 'URL 已保存');
    }
  }

  /// 构建刷新按钮
  Widget buildAct() {
    return Tooltip(
      message: '刷新',
      child: IconButton(
        icon: const Icon(FluentIcons.refresh),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        IconButton(
          icon: Image.asset(
            'assets/images/platforms/mikan-logo.png',
            height: 30.h,
            fit: BoxFit.cover,
          ),
          onPressed: () async {
            await launchUrlString('https://mikanani.me/');
          },
        ),
        Image.asset(
          'assets/images/platforms/mikan-text.png',
          height: 30.h,
          fit: BoxFit.cover,
        ),
        SizedBox(width: 10.w),
        IconButton(
          icon: Icon(FluentIcons.refresh, size: 15.sp),
          onPressed: useUserRSS ? refreshUserRSS : refreshMikanRSS,
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
            await BtInfobar.warn(context, '未设置 Token');
            return;
          } else if (!v && rssItems.isEmpty) {
            await refreshMikanRSS();
          } else if (v && userItems.isEmpty) {
            await refreshUserRSS();
          }
          if (v != old) {
            if (v) {
              if (mounted) await BtInfobar.success(context, '已切换到用户列表');
            } else {
              if (mounted) await BtInfobar.success(context, '已切换到Mikan列表');
            }
          }
          setState(() {});
        },
      ),
      SizedBox(width: 10.w),
      FilledButton(onPressed: null, child: Text('Token: $token')),
      SizedBox(width: 10.w),
      Button(onPressed: tryEditToken, child: const Text('编辑Token')),
      SizedBox(width: 10.w),
      Button(onPressed: tryEditUrl, child: const Text('编辑URL')),
    ];
  }

  /// 构建内容
  Widget buildContent(List<RssItem> data) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ProgressRing(),
            SizedBox(height: 20.h),
            const Text('正在加载数据...'),
          ],
        ),
      );
    } else {
      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: double.infinity),
          child: Wrap(
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.start,
            direction: Axis.horizontal,
            runAlignment: WrapAlignment.start,
            spacing: 12.w,
            runSpacing: 12.h,
            children: data.map(RssMikanCard2.new).toList(),
          ),
        ),
      );
    }
  }

  /// 构建函数
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage.withPadding(
      padding: EdgeInsets.zero,
      header: PageHeader(title: buildTitle()),
      content: buildContent(useUserRSS ? userItems : rssItems),
    );
  }
}
