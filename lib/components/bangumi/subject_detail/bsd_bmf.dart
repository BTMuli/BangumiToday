import 'dart:async';

import 'package:dart_rss/dart_rss.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

import '../../../database/app/app_bmf.dart';
import '../../../database/app/app_rss.dart';
import '../../../models/app/nav_model.dart';
import '../../../models/database/app_bmf_model.dart';
import '../../../models/database/app_rss_model.dart';
import '../../../pages/bangumi/bangumi_detail.dart';
import '../../../pages/bangumi/bangumi_play.dart';
import '../../../request/mikan/mikan_api.dart';
import '../../../store/nav_store.dart';
import '../../../tools/file_tool.dart';
import '../../../tools/log_tool.dart';
import '../../app/app_dialog.dart';
import '../../app/app_dialog_resp.dart';
import '../../app/app_infobar.dart';
import '../../rss/rss_mk_card.dart';

/// Bangumi Subject Detail 的 Bangumi-Mikan-File Widget
/// 用于管理该 Subject 对应的 MikanRSS 及下载目录
class BsdBmf extends ConsumerStatefulWidget {
  /// subjectId
  final int subjectId;

  /// 模式-是用于详情页还是用于配置页
  final bool isConfig;

  /// 构造函数
  const BsdBmf(this.subjectId, {super.key, this.isConfig = false});

  @override
  ConsumerState<BsdBmf> createState() => _BsdBmfState();
}

/// BsdBmfState
class _BsdBmfState extends ConsumerState<BsdBmf>
    with AutomaticKeepAliveClientMixin {
  /// 数据库
  final BtsAppBmf sqliteBmf = BtsAppBmf();

  /// rss 数据库
  final BtsAppRss sqliteRss = BtsAppRss();

  /// mikan请求客户端
  final MikanAPI mikanAPI = MikanAPI();

  /// flyout controller
  final FlyoutController controller = FlyoutController();

  /// file tool
  final BTFileTool fileTool = BTFileTool();

  /// bmf
  late AppBmfModel bmf = AppBmfModel(subject: widget.subjectId);

  /// rss 数据
  late List<RssItem> rssItems = [];

  /// isNew列表，索引与rssItems对应
  late List<bool> isNewList = [];

  /// 是否需要提醒
  late bool notify = false;

  /// 本地文件
  late List<String> files = [];

  /// 定时器
  late Timer timer;

  /// 是否保持状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      await init();
    });

    /// 如果是设置页面，隔15min刷新一次，如果不是，隔5min刷新一次
    if (widget.isConfig) {
      timer = Timer.periodic(Duration(minutes: 15), (timer) async {
        await freshRss();
        BTLogTool.warn('BMF RSS 页面刷新 ${widget.subjectId}');
        setState(() {});
      });
    } else {
      timer = Timer.periodic(Duration(minutes: 5), (timer) async {
        await freshRss();
        BTLogTool.warn('BMF RSS 页面刷新 ${widget.subjectId}');
        setState(() {});
      });
    }
  }

  /// dispose
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// 初始化
  Future<void> init() async {
    var bmfGet = await sqliteBmf.read(widget.subjectId);
    if (bmfGet == null) return;
    bmf = bmfGet;
    setState(() {});
    await freshRss();
    await freshFiles();
    setState(() {});
  }

  /// freshRss
  Future<void> freshRss() async {
    if (bmf.rss == null || bmf.rss!.isEmpty) return;
    var rssGet = await mikanAPI.getCustomRSS(bmf.rss!);
    if (rssGet.code != 0 || rssGet.data == null) {
      showRespErr(rssGet, context);
    }
    var feed = rssGet.data! as RssFeed;
    setState(() {
      rssItems = feed.items;
    });
    var rssList = await sqliteRss.read(bmf.rss!);
    if (rssList == null) {
      setState(() {
        notify = false;
        isNewList = List.filled(rssItems.length, true);
      });
      await sqliteRss.write(
        AppRssModel.fromRssFeed(bmf.rss!, feed),
      );
    } else {
      setState(() {
        notify = false;
        notify = true;
        isNewList = rssItems.map((e) {
          var index = rssList.data.indexWhere(
            (element) => element.site == e.link,
          );
          return index == -1;
        }).toList();
      });
    }
  }

  /// freshFiles
  Future<void> freshFiles() async {
    if (bmf.download == null || bmf.download!.isEmpty) return;
    files = await fileTool.getFileNames(bmf.download!);
    setState(() {});
  }

  /// buildHeaderActRss
  Widget buildHeaderActRss(BuildContext context) {
    var text = '';
    if (bmf.rss == null || bmf.rss!.isEmpty) {
      text = '设置 RSS';
    } else {
      text = '修改 RSS';
    }
    return Button(
      child: Text(text),
      onPressed: () async {
        var input = await showInputDialog(
          context,
          title: '设置 MikanRSS',
          content: '建议精准到字幕组',
        );
        if (input == null) return;
        var check = await sqliteBmf.checkRss(input);
        if (check) {
          BtInfobar.error(context, '该RSS已经被其他BMF使用');
          return;
        }
        bmf.rss = input;
        await sqliteBmf.write(bmf);
        var read = await sqliteBmf.read(bmf.subject);
        if (read != null) {
          bmf = read;
          setState(() {});
        }
        await BtInfobar.success(context, '成功设置 MikanRSS');
        await freshRss();
      },
    );
  }

  /// buildHeaderActFile
  Widget buildHeaderActFile(BuildContext context) {
    var text = '';
    if (bmf.download == null || bmf.download!.isEmpty) {
      text = '设置下载目录';
    } else {
      text = '修改下载目录';
    }
    return Button(
      child: Text(text),
      onPressed: () async {
        var dir = await getDirectoryPath();
        if (dir == null) return;
        var check = await sqliteBmf.checkDir(dir);
        if (check) {
          BtInfobar.error(context, '该目录已经被其他BMF使用');
          return;
        }
        bmf.download = dir;
        await sqliteBmf.write(bmf);
        var read = await sqliteBmf.read(bmf.subject);
        if (read != null) {
          bmf = read;
          setState(() {});
        }
        await BtInfobar.success(context, '成功设置下载目录');
        await freshFiles();
      },
      onLongPress: () async {
        if (bmf.download == null || bmf.download!.isEmpty) {
          await BtInfobar.error(context, '请先设置下载目录');
          return;
        }
        var res = await fileTool.openDir(bmf.download!);
        if (res == null) {
          await BtInfobar.error(context, '打开目录失败：不支持该平台');
          return;
        }
        if (!res) {
          await BtInfobar.error(context, '打开目录失败：未检测到该目录');
        }
      },
    );
  }

  /// buildHeaderDel
  Widget buildHeaderDel(BuildContext context) {
    return Button(
      child: Text('删除'),
      onPressed: () async {
        var confirm = await showConfirmDialog(
          context,
          title: '删除 BMF',
          content: '确定删除 BMF 信息吗？',
        );
        if (!confirm) return;
        await sqliteBmf.delete(bmf.subject);
        if (bmf.rss != null && bmf.rss!.isNotEmpty) {
          await sqliteRss.delete(bmf.rss!);
        }
        await BtInfobar.success(context, '成功删除 BMF 信息');
        setState(() {
          bmf = AppBmfModel(subject: widget.subjectId);
          rssItems = [];
          files = [];
        });
      },
    );
  }

  /// buildHeaderAction
  Widget buildHeaderAction(BuildContext context) {
    return Row(
      children: [
        buildHeaderActRss(context),
        SizedBox(width: 12.w),
        buildHeaderActFile(context),
        SizedBox(width: 12.w),
        if (bmf.id != -1) buildHeaderDel(context),
      ],
    );
  }

  /// openByPotPlayer
  Future<void> openByPotPlayer(String file) async {
    var filePath = path.join(bmf.download!, file);
    filePath = filePath.replaceAll(r'\', '/');
    var url = 'potplayer://$filePath';
    debugPrint('url: $url');
    await launchUrlString(url);
  }

  /// buildPotBtn
  Widget buildPotBtn(String file) {
    return Button(
      child: Row(
        children: [
          Icon(FluentIcons.play, color: FluentTheme.of(context).accentColor),
          SizedBox(width: 8.w),
          Text('调用PotPlayer打开'),
        ],
      ),
      onPressed: () async {
        await openByPotPlayer(file);
      },
    );
  }

  /// openByInnerPlayer
  void openByInnerPlayer(String file) {
    var navStore = ref.read(navStoreProvider);
    var filePath = path.join(bmf.download!, file);
    var pane = PaneItem(
      icon: Icon(FluentIcons.play),
      title: Text('内置播放'),
      body: BangumiPlayPage(filePath),
    );
    navStore.addNavItem(pane, '内置播放');
  }

  /// buildInnerBtn
  Widget buildInnerBtn(String file) {
    return Button(
      child: Row(
        children: [
          Icon(FluentIcons.box_play_solid,
              color: FluentTheme.of(context).accentColor),
          SizedBox(width: 8.w),
          Text('内置播放器打开'),
        ],
      ),
      onPressed: () async {
        openByInnerPlayer(file);
      },
    );
  }

  /// deleteFile
  Future<void> deleteFile(String file) async {
    var confirm = await showConfirmDialog(
      context,
      title: '删除文件',
      content: '确定删除文件 $file 吗？',
    );
    if (!confirm) return;
    var filePath = path.join(bmf.download!, file);
    await fileTool.deleteFile(filePath);
    await freshFiles();
  }

  /// buildDelBtn
  Widget buildDelBtn(String file) {
    return Button(
      child: Row(
        children: [
          Icon(FluentIcons.delete, color: FluentTheme.of(context).accentColor),
          SizedBox(width: 8.w),
          Text('删除文件'),
        ],
      ),
      onPressed: () async {
        await deleteFile(file);
      },
    );
  }

  /// buildFileAct
  List<Widget> buildFileAct(BuildContext context, String file) {
    var potplayerBtn = buildPotBtn(file);
    var innerPlayerBtn = buildInnerBtn(file);
    var deleteBtn = buildDelBtn(file);
    if (file.endsWith(".torrent")) {
      return [deleteBtn];
    }
    if (kDebugMode) {
      return [
        potplayerBtn,
        SizedBox(height: 6),
        innerPlayerBtn,
        SizedBox(height: 6),
        deleteBtn,
      ];
    }
    return [
      potplayerBtn,
      SizedBox(height: 6),
      deleteBtn,
    ];
  }

  /// buildFileCards
  List<Widget> buildFileCards(BuildContext context) {
    var res = <Widget>[];
    for (var file in files) {
      var title = Tooltip(
        message: file,
        child: Text(
          file,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      );
      var card = SizedBox(
        width: 275,
        height: 200,
        child: Card(
          padding: EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              Spacer(),
              ...buildFileAct(context, file),
            ],
          ),
        ),
      );
      res.add(card);
    }
    return res;
  }

  /// buildDirTitle
  Widget buildDirTitle() {
    return Row(
      children: [
        Button(
            child: Text('刷新'),
            onPressed: () async {
              if (bmf.download == null || bmf.download!.isEmpty) {
                await BtInfobar.error(context, '请先设置下载目录');
                return;
              }
              await freshFiles();
              await BtInfobar.success(context, '刷新文件成功');
            }),
        SizedBox(width: 12.w),
        Text('下载目录: ${bmf.download}', style: TextStyle(fontSize: 24.sp)),
      ],
    );
  }

  /// buildRssTitle
  Widget buildRssTitle() {
    return Row(
      children: [
        Button(
          child: Text('刷新'),
          onPressed: () async {
            if (bmf.rss == null || bmf.rss!.isEmpty) {
              await BtInfobar.error(context, '请先设置 RSS');
              return;
            }
            await freshRss();
            await BtInfobar.success(context, '刷新 RSS 成功');
          },
        ),
        SizedBox(width: 12.w),
        Text('Mikan RSS: ${bmf.rss}', style: TextStyle(fontSize: 24.sp)),
      ],
    );
  }

  /// buildRssList
  List<Widget> buildRssList(BuildContext context) {
    var res = <Widget>[];
    if (isNewList.length != rssItems.length) return res;
    for (var i = 0; i < rssItems.length; i++) {
      var item = rssItems[i];
      var isNew = isNewList[i];
      var card = RssMikanCard(
        bmf.rss!,
        item,
        dir: bmf.download,
        isNew: isNew,
        notify: notify,
        subject: bmf.subject,
      );
      res.add(card);
    }
    return res;
  }

  /// buildContent
  List<Widget> buildContent(BuildContext context) {
    return <Widget>[
      buildDirTitle(),
      SizedBox(height: 12.h),
      if (files.isEmpty)
        Text('没有找到任何文件')
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: buildFileCards(context),
        ),
      SizedBox(height: 12.h),
      buildRssTitle(),
      SizedBox(height: 12.h),
      if (rssItems.isEmpty)
        Text('没有找到任何 RSS 信息')
      else
        Wrap(
          spacing: 12.w,
          runSpacing: 12.h,
          children: buildRssList(context),
        ),
    ];
  }

  /// toSubjectDetail
  void toSubjectDetail() {
    var navStore = ref.read(navStoreProvider);
    var pane = PaneItem(
      icon: Icon(FluentIcons.info),
      title: Text('条目详情 ${bmf.subject}'),
      body: BangumiDetail(id: bmf.subject.toString()),
    );
    navStore.addNavItem(
      pane,
      '条目详情 ${bmf.subject}',
      type: BtmAppNavItemType.bangumiSubject,
      param: 'subjectDetail_${bmf.subject}',
    );
  }

  /// buildLeading
  Widget buildLeading() {
    if (widget.isConfig) {
      return IconButton(
        icon: Icon(FluentIcons.settings),
        onPressed: toSubjectDetail,
      );
    }
    return IconButton(
      icon: Icon(FluentIcons.settings),
      onPressed: () {
        ref.read(navStoreProvider).goIndex(3);
      },
    );
  }

  /// buildHeader
  Widget buildHeader() {
    var title = 'BMF Config';
    if (widget.isConfig) {
      title = bmf.subject.toString();
    }
    return Text(title, style: TextStyle(fontSize: 24.sp));
  }

  /// buildEmpty
  Widget buildEmpty() {
    return ListTile(
      leading: Icon(FluentIcons.error_badge),
      title: Text('没有找到对应的 BMF 配置信息'),
      trailing: buildHeaderAction(context),
    );
  }

  /// build
  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (bmf.id == -1) {
      return buildEmpty();
    }
    return Container(
      margin: EdgeInsets.only(right: 12.w),
      child: Expander(
        leading: buildLeading(),
        header: buildHeader(),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: buildContent(context),
        ),
        trailing: buildHeaderAction(context),
      ),
    );
  }
}
