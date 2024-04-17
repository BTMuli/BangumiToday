import 'package:dart_rss/domain/rss_item.dart';
import 'package:file_selector/file_selector.dart';
import 'package:filesize/filesize.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

import '../../../database/app/app_bmf.dart';
import '../../../models/app/nav_model.dart';
import '../../../models/database/app_bmf_model.dart';
import '../../../pages/bangumi/bangumi_detail.dart';
import '../../../pages/bangumi/bangumi_play.dart';
import '../../../request/mikan/mikan_api.dart';
import '../../../store/nav_store.dart';
import '../../../tools/file_tool.dart';
import '../../app/app_dialog.dart';
import '../../app/app_dialog_resp.dart';
import '../../app/app_infobar.dart';
import '../../mikan/mk_rss_card.dart';

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
  final BtsAppBmf sqlite = BtsAppBmf();

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

  /// 本地文件
  late List<String> files = [];

  /// aria2 文件
  late List<String> aria2Files = [];

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
  }

  /// dispose
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// 初始化
  Future<void> init() async {
    var bmfGet = await sqlite.read(widget.subjectId);
    if (bmfGet == null) return;
    setState(() {
      bmf = bmfGet;
    });
    if (bmfGet.rss == null || bmfGet.rss!.isEmpty) {
      debugPrint('rss is empty');
    } else {
      await freshRss(bmfGet);
    }
    if (bmfGet.download == null || bmfGet.download!.isEmpty) {
      debugPrint('download is empty');
    } else {
      await freshFiles(bmfGet);
    }
    setState(() {});
  }

  /// freshRss
  Future<void> freshRss(AppBmfModel bmf) async {
    if (bmf.rss == null || bmf.rss!.isEmpty) return;
    var rssGet = await mikanAPI.getCustomRSS(bmf.rss!);
    if (rssGet.code != 0 || rssGet.data == null) {
      showRespErr(rssGet, context);
    }
    rssItems = rssGet.data!;
    setState(() {});
  }

  /// freshFiles
  Future<void> freshFiles(AppBmfModel data) async {
    if (data.download == null || data.download!.isEmpty) return;
    var filesGet = await fileTool.getFileNames(data.download!);

    /// 获取aria2文件，将移除了.aia2的文件名保存到aria2Files
    aria2Files = filesGet
        .where((element) => element.endsWith('.aria2'))
        .map((e) => e.replaceAll('.aria2', ''))
        .toList();
    filesGet.removeWhere((element) => element.endsWith('.aria2'));
    files = filesGet;
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
        bmf.rss = input;
        await sqlite.write(bmf);
        var read = await sqlite.read(bmf.subject);
        if (read != null) {
          bmf = read;
          setState(() {});
        }
        await BtInfobar.success(context, '成功设置 MikanRSS');
        await freshRss(bmf);
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
        bmf.download = dir;
        await sqlite.write(bmf);
        var read = await sqlite.read(bmf.subject);
        if (read != null) {
          bmf = read;
          setState(() {});
        }
        await BtInfobar.success(context, '成功设置下载目录');
        await freshFiles(bmf);
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
        await sqlite.delete(bmf.subject);
        await BtInfobar.success(context, '成功删除 BMF 信息');
        setState(() {
          bmf = AppBmfModel(subject: widget.subjectId);
          rssItems = [];
          files = [];
          aria2Files = [];
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
    await freshFiles(bmf);
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
    if (aria2Files.contains(file)) {
      var size = fileTool.getFileSize(path.join(bmf.download!, file));

      /// 每隔1秒刷新一次
      Future.delayed(Duration(seconds: 5), () async {
        await freshFiles(bmf);
      });
      return [
        SizedBox(width: double.infinity, child: ProgressBar(value: null)),
        SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('下载中：${filesize(size)}'),
        ]),
      ];
    }
    // todo 优化内置播放样式
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

  /// buildRssCards
  List<Widget> buildRssCards() {
    var res = <Widget>[];
    for (var item in rssItems) {
      res.add(MikanRssCard(item));
    }
    return res;
  }

  /// buildContent
  List<Widget> buildContent(BuildContext context) {
    var res = <Widget>[];
    var dirTitle = Row(
      children: [
        Button(
            child: Text('刷新'),
            onPressed: () async {
              if (bmf.download == null || bmf.download!.isEmpty) {
                await BtInfobar.error(context, '请先设置下载目录');
                return;
              }
              await freshFiles(bmf);
              await BtInfobar.success(context, '刷新文件成功');
            }),
        SizedBox(width: 12.w),
        Text('下载目录: ${bmf.download}', style: TextStyle(fontSize: 24.sp)),
      ],
    );
    res.add(dirTitle);
    res.add(SizedBox(height: 12.h));
    if (files.isEmpty) {
      res.add(Text('没有找到任何文件'));
    } else {
      res.add(
        Wrap(spacing: 8, runSpacing: 8, children: buildFileCards(context)),
      );
    }
    res.add(SizedBox(height: 12.h));
    var rssTitle = Row(
      children: [
        Button(
          child: Text('刷新'),
          onPressed: () async {
            if (bmf.rss == null || bmf.rss!.isEmpty) {
              await BtInfobar.error(context, '请先设置 RSS');
              return;
            }
            await freshRss(bmf);
            await BtInfobar.success(context, '刷新 RSS 成功');
          },
        ),
        SizedBox(width: 12.w),
        Text('Mikan RSS: ${bmf.rss}', style: TextStyle(fontSize: 24.sp)),
      ],
    );
    res.add(rssTitle);
    res.add(SizedBox(height: 12.h));
    if (rssItems.isEmpty) {
      res.add(Text('没有找到任何 RSS 信息'));
    } else {
      res.add(
        Wrap(
          spacing: 12.w,
          runSpacing: 12.h,
          children: rssItems
              .map(
                (e) => MikanRssCard(e, dir: bmf.download),
              )
              .toList(),
        ),
      );
    }
    return res;
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

  /// build
  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (bmf.id == -1) {
      return Container(
        margin: EdgeInsets.only(right: 12.w),
        child: ListTile(
          leading: Icon(FluentIcons.error_badge),
          title: Text('没有找到对应的 BMF 配置信息'),
          trailing: buildHeaderAction(context),
        ),
      );
    }
    var title = 'BMF Config';
    if (widget.isConfig) {
      title = bmf.subject.toString();
    }
    return Container(
      margin: EdgeInsets.only(right: 12.w),
      child: Expander(
        leading: widget.isConfig
            ? IconButton(
                icon: Icon(FluentIcons.settings),
                onPressed: toSubjectDetail,
              )
            : IconButton(
                icon: Icon(FluentIcons.settings),
                onPressed: () {
                  ref.read(navStoreProvider).goIndex(3);
                },
              ),
        header: Text(title, style: TextStyle(fontSize: 24.sp)),
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
