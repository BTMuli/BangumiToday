// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../database/app/app_mikan_credential.dart';
import '../../models/rss/rss.dart';
import '../../request/mikan/mikan_api.dart';
import '../../store/app_store.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import 'mikan_mirror_combo.dart';
import 'rss_mikan_card_fluent.dart';

/// 负责 MikanProject RSS 页面的显示
/// 包括 RSSClassic 和 RSSPersonal
/// 前者是列表模式显示站点的RSS更新，后者是个人订阅的RSS更新
class RssBmfMikan extends ConsumerStatefulWidget {
  /// 构造函数
  const RssBmfMikan({super.key});

  @override
  ConsumerState<RssBmfMikan> createState() => _RssBmfMikanState();
}

/// MikanRSS 页面状态
class _RssBmfMikanState extends ConsumerState<RssBmfMikan>
    with AutomaticKeepAliveClientMixin {
  /// 请求客户端
  final BtrMikanApi mikanAPI = BtrMikanApi();

  /// RSS 数据
  List<RssItem> rssItems = [];

  /// RSS 数据
  List<RssItem> userItems = [];

  /// 用户订阅的 token
  late String token = '';

  /// 是否使用用户订阅
  late bool useUserRSS = false;

  bool _initialized = false;
  bool _refreshing = false;
  bool _mikanLoaded = false;
  bool _userLoaded = false;
  bool _loadFailed = false;

  /// mikan 镜像
  String get mikanRss => ref.watch(appStoreProvider).mikanRss;

  /// Token 仅用于请求，不在界面中明文展示。
  String get maskedToken => token.isEmpty ? '未设置' : '••••••••';

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.delayed(Duration.zero, init));
  }

  /// 刷新
  Future<void> refreshMikanRSS() => _refreshRSS(personal: false);

  /// 刷新
  Future<void> refreshUserRSS() => _refreshRSS(personal: true);

  Future<void> _refreshRSS({required bool personal, bool notify = true}) async {
    if (!mounted || _refreshing) return;
    setState(() {
      _refreshing = true;
      _loadFailed = false;
    });
    var resGet = personal
        ? await mikanAPI.getUserRSS(token)
        : await mikanAPI.getClassicRSS();
    if (!mounted) return;
    var success = resGet.code == 0 && resGet.data != null;
    setState(() {
      _refreshing = false;
      _loadFailed = !success;
      if (success) {
        if (personal) {
          userItems = resGet.data!;
          _userLoaded = true;
        } else {
          rssItems = resGet.data!;
          _mikanLoaded = true;
        }
      }
    });
    if (!success) {
      await showRespErr(resGet, context);
      return;
    }
    if (notify) {
      await BtInfobar.success(context, personal ? '已刷新用户列表' : '已刷新 Mikan 列表');
    }
  }

  /// 初始化
  Future<void> init() async {
    var mikan = await BtsMikanCredential().readToken();
    if (!mounted) return;
    _initialized = true;
    if (mikan == null || mikan.isEmpty) {
      useUserRSS = false;
      await _refreshRSS(personal: false, notify: false);
      return;
    }
    token = mikan;
    useUserRSS = true;
    await _refreshRSS(personal: true, notify: false);
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
    await BtsMikanCredential().writeToken(parsed);
    if (!mounted) return;
    setState(() {
      token = parsed;
      userItems = [];
      _userLoaded = false;
      useUserRSS = true;
    });
    await BtInfobar.success(context, 'Token 已保存');
    await refreshUserRSS();
  }

  /// 构建刷新按钮
  Widget buildAct() {
    return Tooltip(
      message: '刷新 Mikan',
      child: IconButton(
        icon: _refreshing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: ProgressRing(strokeWidth: 2),
              )
            : const Icon(FluentIcons.refresh, size: 15),
        onPressed: _refreshing || !_initialized
            ? null
            : (useUserRSS ? refreshUserRSS : refreshMikanRSS),
      ),
    );
  }

  /// 构建标题
  Widget buildTitle() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          IconButton(
            icon: Image.asset(
              'assets/images/platforms/mikan-logo.png',
              height: 30,
              fit: BoxFit.cover,
            ),
            onPressed: () async {
              await launchUrlString(mikanRss);
            },
          ),
          Image.asset(
            'assets/images/platforms/mikan-text.png',
            height: 30,
            fit: BoxFit.cover,
          ),
          SizedBox(width: 10),
          const MikanMirrorCombo(),
          SizedBox(width: 10),
          buildAct(),
          SizedBox(width: 10),
          ...buildTokenBar(),
        ],
      ),
    );
  }

  /// 构建 Token 栏
  List<Widget> buildTokenBar() {
    return [
      ToggleSwitch(
        checked: useUserRSS,
        onChanged: _refreshing || !_initialized
            ? null
            : (v) async {
                var old = useUserRSS;
                if (token == '' && v) {
                  await BtInfobar.warn(context, '未设置 Token');
                  return;
                }
                setState(() {
                  useUserRSS = v;
                  _loadFailed = false;
                });
                if (!v && !_mikanLoaded) {
                  await refreshMikanRSS();
                } else if (v && !_userLoaded) {
                  await refreshUserRSS();
                }
                if (v != old) {
                  if (v) {
                    if (mounted) await BtInfobar.success(context, '已切换到用户列表');
                  } else {
                    if (mounted) {
                      await BtInfobar.success(context, '已切换到Mikan列表');
                    }
                  }
                }
                if (mounted) setState(() {});
              },
      ),
      SizedBox(width: 10),
      FilledButton(onPressed: null, child: Text('Token: $maskedToken')),
      SizedBox(width: 10),
      Button(
        onPressed: _refreshing || !_initialized ? null : tryEditToken,
        child: const Text('编辑Token'),
      ),
    ];
  }

  /// 构建内容
  Widget buildContent(List<RssItem> data) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_refreshing || !_initialized) ...[
              const ProgressRing(),
              SizedBox(height: 20),
              const Text('正在加载数据...'),
            ] else
              Text(_loadFailed ? '加载失败，请点击刷新重试' : '暂无 RSS 数据'),
          ],
        ),
      );
    } else {
      return LayoutBuilder(
        builder: (context, constraints) {
          var cardWidth = 280.0;
          var crossAxisCount = (constraints.maxWidth / cardWidth).floor().clamp(
            1,
            6,
          );
          var mainAxisExtent = 180.0;

          return GridView.builder(
            key: PageStorageKey(useUserRSS ? 'mikan-user-rss' : 'mikan-rss'),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisExtent: mainAxisExtent,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: data.length,
            itemBuilder: (context, index) {
              return RssMikanCardFluent(item: data[index]);
            },
          );
        },
      );
    }
  }

  /// 构建函数
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage.withPadding(
      padding: EdgeInsets.zero,
      header: Padding(padding: EdgeInsets.all(8), child: buildTitle()),
      content: buildContent(useUserRSS ? userItems : rssItems),
    );
  }
}
