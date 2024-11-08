// Dart imports:
import 'dart:async';

// Package imports:
import 'package:dart_rss/domain/rss_feed.dart';
import 'package:dart_rss/domain/rss_item.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:xml/xml.dart';

// Project imports:
import '../../../database/app/app_rss.dart';
import '../../../models/database/app_bmf_model.dart';
import '../../../models/database/app_rss_model.dart';
import '../../../plugins/mikan/mikan_api.dart';
import '../../../store/nav_store.dart';
import '../../../tools/log_tool.dart';
import '../../../tools/notifier_tool.dart';
import '../../../ui/bt_dialog.dart';
import '../../../ui/bt_infobar.dart';
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
  final api = BtrMikanApi();

  /// sqlite
  final sqlite = BtsAppRss();

  /// AppRssModel
  AppRssModel? appRssModel;

  /// 用于对比的 rssItems
  List<XmlElement> rssItemsXml = [];

  /// rssItems
  List<RssItem> rssItems = [];

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
      if (appRssModel == null) {
        appRssModel = AppRssModel(rss: bmf.rss!, data: '', ttl: 0, updated: 0);
        setState(() {});
        await freshRss();
        return;
      }
      rssItems = RssFeed.parse(appRssModel!.data).items;
      var parse = XmlDocument.parse(appRssModel!.data);
      var channel = parse.findAllElements('channel').first;
      rssItemsXml = channel.findAllElements('item').toList();
      setState(() {});
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

  /// showNewRss
  Future<void> showNewRss(List<RssItem> newList) async {
    for (var item in newList) {
      await BTNotifierTool.showMini(
        title: 'RSS 订阅更新',
        body: '${item.title}',
        onClick: () => ref
            .read(navStoreProvider.notifier)
            .addNavItemB(subject: bmf.subject, type: '动画'),
      );
    }
  }

  /// freshRss
  Future<void> freshRss() async {
    if (bmf.rss == null || bmf.rss!.isEmpty) return;
    var rssGet = await api.getCustomRSS(bmf.rss!);
    var tryTimes = 0;
    while (rssGet.code != 0 && tryTimes < 3) {
      var warnInfo = [
        "【BsdBmfRss】【freshRss】Fail to load custom RSS,try $tryTimes times",
        "RSS Link: ${bmf.rss}",
      ];
      BTLogTool.warn(warnInfo);
      rssGet = await api.getCustomRSS(bmf.rss!);
      tryTimes++;
    }
    if (rssGet.code != 0 || rssGet.data == null) {
      if (mounted) await showRespErr(rssGet, context);
      return;
    }
    var feed = RssFeed.parse(rssGet.data);
    if (rssItems.isEmpty) {
      rssItems = feed.items;
      appRssModel = AppRssModel(
        rss: bmf.rss!,
        data: rssGet.data,
        ttl: feed.ttl,
        updated: DateTime.now().millisecondsSinceEpoch,
      );
      await sqlite.write(appRssModel!);
      BTLogTool.info('首次加载 RSS 信息');
      setState(() {});
      return;
    }
    var parse = XmlDocument.parse(rssGet.data);
    var channel = parse.findAllElements('channel').first;
    var items = channel.findAllElements('item');
    var newList = <RssItem>[];
    for (var item in items) {
      var check = rssItemsXml.any(
        (element) => element.toXmlString() == item.toXmlString(),
      );
      if (!check) newList.add(RssItem.parse(item));
    }
    rssItems = feed.items;
    rssItemsXml = items.toList();
    if (newList.isNotEmpty) {
      BTLogTool.info('发现新的 RSS 信息');
      appRssModel = AppRssModel(
        rss: bmf.rss!,
        data: rssGet.data as String,
        ttl: feed.ttl,
        updated: DateTime.now().millisecondsSinceEpoch,
      );
      await showNewRss(newList);
      await sqlite.write(appRssModel!);
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
          onLongPress: () async {
            Pasteboard.writeText(bmf.rss!);
            if (mounted) await BtInfobar.success(context, '已复制 RSS 链接');
          },
        ),
        SizedBox(width: 12.w),
        Text('Mikan RSS: ${bmf.rss}', style: TextStyle(fontSize: 20.sp)),
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
        if (rssItems.isEmpty)
          const Text('没有找到任何 RSS 信息')
        else
          Wrap(spacing: 12.w, runSpacing: 12.h, children: [
            for (var i = 0; i < rssItems.length; i++)
              RssMikanCard(
                bmf.rss!,
                rssItems[i],
                dir: bmf.download,
                subject: bmf.subject,
              ),
          ]),
      ],
    );
  }
}
