import 'dart:async';

import 'package:bangumi_today/database/app/app_rss.dart';
import 'package:bangumi_today/models/database/app_bmf_model.dart';
import 'package:bangumi_today/request/rss/mikan_api.dart';
import 'package:bangumi_today/tools/notifier_tool.dart';
import 'package:dart_rss/domain/rss_feed.dart';
import 'package:dart_rss/domain/rss_item.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../models/app/nav_model.dart';
import '../../../models/database/app_rss_model.dart';
import '../../../pages/bangumi/bangumi_detail.dart';
import '../../../store/nav_store.dart';
import '../../../tools/log_tool.dart';
import '../../app/app_dialog_resp.dart';
import '../../app/app_infobar.dart';
import '../../rss/rss_mk_card.dart';

/// bmf RSS部分的组件
class BsdBmfRss extends ConsumerStatefulWidget {
  /// bmf 配置
  final AppBmfModel bmf;

  /// 是否是配置页面
  final bool isConfig;

  /// 构造
  const BsdBmfRss(this.bmf, this.isConfig, {super.key});

  @override
  ConsumerState<BsdBmfRss> createState() => _BsdBmfRssState();
}

/// 状态
class _BsdBmfRssState extends ConsumerState<BsdBmfRss>
    with AutomaticKeepAliveClientMixin {
  /// bmf
  AppBmfModel get bmf => widget.bmf;

  /// mikanApi
  final api = MikanAPI();

  /// sqlite
  final sqlite = BtsAppRss();

  /// AppRssModel
  AppRssModel? appRssModel;

  /// rssItems
  List<RssItem> rssItems = [];

  /// isNewList
  late List<bool> isNewList;

  /// notify
  bool notify = false;

  /// 刷新定时器
  late Timer timerRss;

  /// 是否保持状态
  @override
  bool get wantKeepAlive => true;

  /// initState
  @override
  void initState() {
    super.initState();
    timerRss = getTimerRss();
    Future.delayed(Duration.zero, () async {
      appRssModel = await sqlite.read(bmf.rss!);
      await freshRss();
    });
  }

  /// dispose
  @override
  void dispose() {
    timerRss.cancel();
    super.dispose();
  }

  /// 初始化 timerRss
  Timer getTimerRss() {
    var minute = widget.isConfig ? 15 : 5;
    return Timer.periodic(Duration(minutes: minute), (timer) async {
      await freshRss();
      BTLogTool.info('BMF RSS 页面刷新 ${bmf.subject}');
    });
  }

  /// freshRss
  Future<void> freshRss() async {
    if (bmf.rss == null || bmf.rss!.isEmpty) return;
    var rssGet = await api.getCustomRSS(bmf.rss!);
    var tryTimes = 0;
    while (rssGet.code != 0 && tryTimes < 3) {
      BTLogTool.error('Failed to load custom RSS, try again');
      rssGet = await api.getCustomRSS(bmf.rss!);
      tryTimes++;
    }
    if (rssGet.code != 0 || rssGet.data == null) {
      if (mounted) showRespErr(rssGet, context);
      return;
    }
    var feed = rssGet.data! as RssFeed;
    rssItems = feed.items;
    setState(() {});
    var newModel = AppRssModel.fromRssFeed(bmf.rss!, feed);
    if (appRssModel == null) {
      await sqlite.write(newModel);
      appRssModel = newModel;
      setState(() {});
      return;
    }
    var check = false;
    for (var i = 0; i < rssItems.length; i++) {
      var model = AppRssItemModel.fromRssItem(bmf.rss!, rssItems[i]);
      var index = appRssModel!.data.indexWhere((element) => element != model);
      if (index != -1) continue;
      check = true;
      await BTNotifierTool.showMini(
        title: 'RSS 订阅更新',
        body: '${rssItems[i].title}',
        onClick: () async {
          var title = '条目详情 ${bmf.subject}';
          var pane = PaneItem(
            icon: const Icon(FluentIcons.info),
            title: Text(title),
            body: BangumiDetail(id: bmf.subject.toString()),
          );
          ref.read(navStoreProvider.notifier).addNavItem(
                pane,
                title,
                type: BtmAppNavItemType.bangumiSubject,
                param: 'subjectDetail_${bmf.subject}',
              );
        },
      );
    }
    if (check) {
      BTLogTool.info('发现新的 RSS 信息');
      await sqlite.write(newModel);
      appRssModel = newModel;
    }
    setState(() {});
  }

  /// buildRssTitle
  Widget buildTitle() {
    return Row(
      children: [
        Button(
          child: const Text('刷新'),
          onPressed: () async {
            await freshRss();
            if (mounted) await BtInfobar.success(context, '刷新 RSS 成功');
          },
        ),
        SizedBox(width: 12.w),
        Text('Mikan RSS: ${bmf.rss}', style: TextStyle(fontSize: 24.sp)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildTitle(),
        SizedBox(height: 12.h),
        if (rssItems.isEmpty || rssItems.length != isNewList.length)
          const Text('没有找到任何 RSS 信息')
        else
          Wrap(spacing: 12.w, runSpacing: 12.h, children: [
            for (var i = 0; i < rssItems.length; i++)
              RssMikanCard(
                bmf.rss!,
                rssItems[i],
                dir: bmf.download!,
                subject: bmf.subject,
              ),
          ]),
      ],
    );
  }
}
