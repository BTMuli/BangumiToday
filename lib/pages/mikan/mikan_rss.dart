import 'package:dart_rss/domain/rss_item.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../components/mikan/rss_card.dart';
import '../../request/mikan/mikan_api.dart';

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

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      var res = await mikanAPI.getClassicRSS();
      rssItems = res;
      setState(() {});
    });
  }

  /// 构建刷新按钮
  Widget buildAct() {
    return Tooltip(
      message: '刷新',
      child: IconButton(
        icon: Icon(FluentIcons.refresh),
        onPressed: () async {
          var res = await mikanAPI.getClassicRSS();
          rssItems.addAll(res);
          setState(() {});
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
            rssItems.clear();
            setState(() {});
            var res = await mikanAPI.getClassicRSS();
            rssItems = res;
            setState(() {});
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
            ProgressRing(),
            SizedBox(height: 20.h),
            Text('正在加载数据...'),
          ],
        ),
      );
    } else {
      return ListView.builder(
        itemCount: rssItems.length,
        itemBuilder: (context, index) {
          var item = rssItems[index];
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
        content: Center(child: buildContent()));
  }
}
