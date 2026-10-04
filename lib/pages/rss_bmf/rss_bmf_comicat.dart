// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../models/rss/rss.dart';
import '../../request/rss/comicat_api.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import 'rss_release_data.dart';
import 'rss_release_list.dart';

/// 负责 ComicatProject RSS 页面的显示
class RssBmfComicat extends StatefulWidget {
  /// 构造函数
  const RssBmfComicat({super.key});

  @override
  State<RssBmfComicat> createState() => _RssBmfComicatState();
}

/// ComicatRSS 页面状态
class _RssBmfComicatState extends State<RssBmfComicat>
    with AutomaticKeepAliveClientMixin {
  /// 请求客户端
  final ComicatAPI comicatAPI = ComicatAPI();

  /// RSS 数据
  List<RssItem> rssItems = [];
  bool _refreshing = false;
  bool _loaded = false;
  bool _loadFailed = false;

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.delayed(Duration.zero, () => refresh(notify: false)),
    );
  }

  /// 刷新数据
  Future<void> refresh({bool notify = true}) async {
    if (!mounted || _refreshing) return;
    setState(() => _refreshing = true);
    var resGet = await comicatAPI.getHomeRSS();
    if (!mounted) return;
    var success = resGet.code == 0 && resGet.data != null;
    setState(() {
      _refreshing = false;
      _loaded = true;
      _loadFailed = !success;
      if (success) rssItems = resGet.data!;
    });
    if (!success) {
      await showRespErr(resGet, context);
      return;
    }
    if (notify) await BtInfobar.success(context, '已刷新 Comicat 列表');
  }

  /// 构建标题
  Widget buildTitle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Tooltip(
          message: '打开漫猫动漫',
          child: IconButton(
            icon: Image.asset(
              'assets/images/platforms/comicat-favicon.ico',
              width: 30,
              height: 30,
              fit: BoxFit.contain,
            ),
            onPressed: () async {
              await launchUrlString('https://comicat.org');
            },
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Comicat', style: BTTypography.title(context)),
              Text('按分类浏览动画、音乐与其他发布资源', style: BTTypography.caption(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildContent() {
    return RssReleaseList(
      title: buildTitle(),
      items: rssItems,
      source: RssReleaseSource.comicat,
      refreshing: _refreshing,
      loaded: _loaded,
      loadFailed: _loadFailed,
      onRefresh: refresh,
    );
  }

  /// 构建函数
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(padding: EdgeInsets.zero, content: buildContent());
  }
}
