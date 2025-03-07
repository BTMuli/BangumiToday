// Dart imports:
import 'dart:async';

// Package imports:
import 'package:dart_rss/domain/rss_feed.dart';
import 'package:dart_rss/domain/rss_item.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:xml/xml.dart';

// Project imports:
import '../../../database/app/app_rss.dart';
import '../../../models/database/app_bmf_model.dart';
import '../../../models/database/app_rss_model.dart';
import '../../../plugins/mikan/mikan_api.dart';
import '../../../store/app_store.dart';
import '../../../store/nav_store.dart';
import '../../../tools/log_tool.dart';
import '../../../tools/notifier_tool.dart';
import '../../../ui/bt_dialog.dart';
import '../../../ui/bt_icon.dart';
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

  String? get mikanRss => ref.watch(appStoreProvider).mikanRss;

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
    Future.microtask(() async {
      if (bmf.mkBgmId == null || bmf.mkBgmId!.isEmpty) {
        appRssModel = await sqlite.read(bmf.rss!);
      } else {
        appRssModel = await sqlite.readByMkId(bmf.mkBgmId!);
      }
      if (appRssModel == null) {
        appRssModel = AppRssModel(
          rss: getRss(),
          data: '',
          ttl: 0,
          updated: 0,
          mkBgmId: bmf.mkBgmId,
          mkGroupId: bmf.mkGroupId,
        );
        await sqlite.write(appRssModel!);
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

  @override
  void didUpdateWidget(BsdBmfRss oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bmf.rss != widget.bmf.rss) {
      Future.microtask(() async => await freshRss());
    }
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
    if (newList.length > 1) {
      await BTNotifierTool.showMini(
        title: 'RSS 订阅更新',
        body: bmf.title ?? '动画：${bmf.subject}',
        onClick: () => ref.read(navStoreProvider.notifier).addNavItemB(
            subject: bmf.subject, type: '动画', paneTitle: bmf.title),
      );
    }
    if (newList.length == 1) {
      await BTNotifierTool.showMini(
        title: 'RSS 订阅更新',
        body: '${newList[0].title}',
        onClick: () => ref.read(navStoreProvider.notifier).addNavItemB(
              subject: bmf.subject,
              type: '动画',
              paneTitle: bmf.title,
            ),
      );
    }
  }

  /// 获取rss
  String getRss() {
    if (bmf.mkBgmId == null || bmf.mkBgmId!.isEmpty) {
      return bmf.rss!;
    }
    var url = '$mikanRss/RSS/Bangumi?bangumiId=${bmf.mkBgmId}';
    if (bmf.mkGroupId != null) url += '&subgroupid=${bmf.mkGroupId}';
    return url;
  }

  /// freshRss
  Future<void> freshRss() async {
    if (bmf.rss == null || bmf.rss!.isEmpty) return;
    var url = getRss();
    var rssGet = await api.getCustomRSS(url);
    var tryTimes = 0;
    while (rssGet.code != 0 && tryTimes < 3) {
      var warnInfo = [
        "【BsdBmfRss】【freshRss】Fail to load custom RSS,try $tryTimes times",
        "RSS Link: ${bmf.rss}",
      ];
      BTLogTool.warn(warnInfo);
      rssGet = await api.getCustomRSS(url);
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
        mkBgmId: bmf.mkBgmId,
        mkGroupId: bmf.mkGroupId,
        rss: url,
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
        mkBgmId: bmf.mkBgmId,
        mkGroupId: bmf.mkGroupId,
        rss: url,
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
    var rssLink = getRss();
    return Flex(direction: Axis.horizontal, children: [
      Flexible(
        child: Tooltip(
          message: rssLink,
          child: Text(
            'Mikan RSS: $rssLink',
            style: TextStyle(fontSize: 20),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Tooltip(
        message: '刷新 RSS',
        child: IconButton(
          icon: BtIcon(FluentIcons.refresh),
          onPressed: freshRss,
        ),
      ),
      Tooltip(
        message: '打开 RSS',
        child: IconButton(
          icon: BtIcon(FluentIcons.edge_logo),
          onPressed: () async => await launchUrlString(rssLink),
        ),
      )
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildTitle(),
        const SizedBox(height: 12),
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
