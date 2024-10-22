// Package imports:
import 'package:dart_rss/domain/rss_item.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../request/rss/comicat_api.dart';
import '../../ui/bt_dialog.dart';
import 'rss_cmc_card.dart';

/// 负责 ComicatProject RSS 页面的显示
class RssCmcPage extends StatefulWidget {
  /// 构造函数
  const RssCmcPage({super.key});

  @override
  State<RssCmcPage> createState() => _RssCmcPageState();
}

/// ComicatRSS 页面状态
class _RssCmcPageState extends State<RssCmcPage>
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
        SizedBox(width: 20.w),
        IconButton(
          icon: const Icon(FluentIcons.refresh),
          onPressed: () async {
            await refresh();
          },
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
            const ProgressRing(),
            SizedBox(height: 20.h),
            const Text('正在加载数据...'),
          ],
        ),
      );
    } else {
      return ListView.builder(
        itemCount: rssItems.length,
        itemBuilder: (context, index) {
          var item = rssItems[index];
          return RssCmcCard(item);
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
      header: PageHeader(title: buildTitle()),
      content: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: buildContent(),
          ),
          Positioned(
            bottom: 8.h,
            right: 8.w,
            child: SizedBox(
              width: 200.w,
              child: Image.asset('assets/images/platforms/comicat-kb.png'),
            ),
          ),
        ],
      ),
    );
  }
}
