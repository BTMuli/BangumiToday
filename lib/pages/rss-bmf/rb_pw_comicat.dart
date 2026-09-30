// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../models/rss/rss.dart';
import '../../request/rss/comicat_api.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/rss/rss_comicat_card_fluent.dart';

/// 负责 ComicatProject RSS 页面的显示
class RbpComicatWidget extends StatefulWidget {
  /// 构造函数
  const RbpComicatWidget({super.key});

  @override
  State<RbpComicatWidget> createState() => _RbpComicatState();
}

/// ComicatRSS 页面状态
class _RbpComicatState extends State<RbpComicatWidget>
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
        IconButton(
          icon: Image.asset(
            'assets/images/platforms/comicat-favicon.ico',
            fit: BoxFit.cover,
          ),
          onPressed: () async {
            await launchUrlString('https://comicat.org');
          },
        ),
        SizedBox(width: 10),
        const Text('Comicat'),
        SizedBox(width: 10),
        Tooltip(
          message: '刷新 Comicat',
          child: IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: ProgressRing(strokeWidth: 2),
                  )
                : const Icon(FluentIcons.refresh),
            onPressed: _refreshing ? null : refresh,
          ),
        ),
      ],
    );
  }

  /// 构建内容
  Widget buildContent() {
    if (rssItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_refreshing || !_loaded) ...[
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
          var cardWidth = 320.0;
          var crossAxisCount = (constraints.maxWidth / cardWidth).floor().clamp(
            1,
            6,
          );
          var mainAxisExtent = 200.0;

          return Stack(
            children: [
              Positioned(
                bottom: 16,
                right: 16,
                child: Opacity(
                  opacity: 0.3,
                  child: SizedBox(
                    width: 100,
                    child: Image.asset(
                      'assets/images/platforms/comicat-kb.png',
                    ),
                  ),
                ),
              ),
              GridView.builder(
                key: const PageStorageKey('comicat-rss'),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: mainAxisExtent,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: rssItems.length,
                itemBuilder: (context, index) {
                  return RssComicatCardFluent(item: rssItems[index]);
                },
              ),
            ],
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
      content: buildContent(),
    );
  }
}
