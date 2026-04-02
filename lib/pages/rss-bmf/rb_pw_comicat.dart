// Package imports:
import 'package:dart_rss/domain/rss_item.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../request/rss/comicat_api.dart';
import '../../ui/bt_dialog.dart';
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
  late List<RssItem> rssItems = [];

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      await refresh();
    });
  }

  /// 刷新数据
  Future<void> refresh() async {
    setState(rssItems.clear);
    var resGet = await comicatAPI.getHomeRSS();
    if (resGet.code != 0 || resGet.data == null) {
      if (mounted) await showRespErr(resGet, context);
      return;
    }
    setState(() => rssItems = resGet.data!);
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
        SizedBox(width: 10.w),
        const Text('Comicat'),
        SizedBox(width: 10.w),
        IconButton(icon: const Icon(FluentIcons.refresh), onPressed: refresh),
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
            const ProgressRing(),
            SizedBox(height: 20.h),
            const Text('正在加载数据...'),
          ],
        ),
      );
    } else {
      return LayoutBuilder(
        builder: (context, constraints) {
          var cardWidth = 320.0;
          var crossAxisCount = (constraints.maxWidth / cardWidth).floor().clamp(1, 6);
          var mainAxisExtent = 200.0;
          
          return Stack(
            children: [
              GridView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: mainAxisExtent,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                ),
                itemCount: rssItems.length,
                itemBuilder: (context, index) {
                  return RssComicatCardFluent(item: rssItems[index]);
                },
              ),
              Positioned(
                bottom: 16.h,
                right: 16.w,
                child: Opacity(
                  opacity: 0.3,
                  child: SizedBox(
                    width: 100.spMin,
                    child: Image.asset('assets/images/platforms/comicat-kb.png'),
                  ),
                ),
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
