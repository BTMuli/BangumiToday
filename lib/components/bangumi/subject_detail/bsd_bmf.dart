import 'package:dart_rss/domain/rss_item.dart';
import 'package:file_picker/file_picker.dart';
import 'package:filesize/filesize.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

import '../../../database/app/app_bmf.dart';
import '../../../models/database/app_bmf_model.dart';
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

  /// 构造函数
  const BsdBmf(this.subjectId, {super.key});

  @override
  ConsumerState<BsdBmf> createState() => _BsdBmfState();
}

/// BsdBmfState
class _BsdBmfState extends ConsumerState<BsdBmf> {
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

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      await init();
    });
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
    debugPrint('freshFiles');
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

  /// buildHeaderAction
  Widget buildHeaderAction(BuildContext context) {
    var rssText = '';
    var downloadText = '';
    if (bmf.rss == null || bmf.rss!.isEmpty) {
      rssText = '设置 RSS';
    } else {
      rssText = '修改 RSS';
    }
    if (bmf.download == null || bmf.download!.isEmpty) {
      downloadText = '设置下载目录';
    } else {
      downloadText = '修改下载目录';
    }
    return Row(
      children: [
        Button(
          child: Text(rssText),
          onPressed: () async {
            var input = await showInputDialog(
              context,
              title: '设置 MikanRSS',
              content: '建议精准到字幕组',
            );
            if (input == null) return;
            bmf.rss = input;
            await sqlite.write(bmf);
            await BtInfobar.success(context, '成功设置 MikanRSS');
            await freshRss(bmf);
          },
        ),
        SizedBox(width: 12.w),
        Button(
          child: Text(downloadText),
          onPressed: () async {
            var confirm = await showConfirmDialog(
              context,
              title: '设置下载目录',
              content: '将会结合RSS对照观看进度',
            );
            if (!confirm) return;
            var dir = await FilePicker.platform.getDirectoryPath();
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
        ),
      ],
    );
  }

  /// buildFileAct
  List<Widget> buildFileAct(BuildContext context, String file) {
    var potplayerBtn = Button(
      child: Row(
        children: [
          Icon(FluentIcons.play),
          SizedBox(width: 8.w),
          Text('调用PotPlayer打开'),
        ],
      ),
      onPressed: () async {
        var filePath = path.join(bmf.download!, file);
        filePath = filePath.replaceAll(r'\', '/');
        var url = 'potplayer://$filePath';
        debugPrint('url: $url');
        await launchUrlString(url);
      },
    );
    var innerPlayerBtn = Button(
      child: Row(
        children: [
          Icon(FluentIcons.box_play_solid),
          SizedBox(width: 8.w),
          Text('内置播放器打开'),
        ],
      ),
      onPressed: () async {
        var navStore = ref.read(navStoreProvider);
        var filePath = path.join(bmf.download!, file);
        var pane = PaneItem(
          icon: Icon(FluentIcons.play),
          title: Text('内置播放'),
          body: BangumiPlayPage(filePath),
        );
        navStore.addNavItem(pane, '内置播放');
      },
    );
    var deleteBtn = Button(
      child: Row(
        children: [
          Icon(FluentIcons.delete),
          SizedBox(width: 8.w),
          Text('删除文件'),
        ],
      ),
      onPressed: () async {
        var confirm = await showConfirmDialog(
          context,
          title: '删除文件',
          content: '确定删除文件 $file 吗？',
        );
        if (!confirm) return;
        var filePath = path.join(bmf.download!, file);
        await fileTool.deleteFile(filePath);
        await freshFiles(bmf);
      },
    );
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
        Expanded(
            child: SizedBox(
                width: double.infinity, child: ProgressBar(value: null))),
        SizedBox(height: 12.h),
        Text('下载中：${filesize(size)}'),
      ];
    }
    return [
      potplayerBtn,
      SizedBox(height: 12.h),
      innerPlayerBtn,
      SizedBox(height: 12.h),
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
          style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      );
      var card = SizedBox(
        width: 420.w,
        child: Card(
          padding: EdgeInsets.symmetric(vertical: 16.w, horizontal: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              SizedBox(height: 12.h),
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
      res.add(Wrap(
        spacing: 12.w,
        runSpacing: 12.h,
        children: buildFileCards(context),
      ));
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

  /// build
  @override
  Widget build(BuildContext context) {
    if (bmf.id == -1) {
      return ListTile(
        leading: Icon(FluentIcons.error_badge),
        title: Text('没有找到对应的 RSS 信息'),
        trailing: buildHeaderAction(context),
      );
    }
    return Container(
      margin: EdgeInsets.only(right: 12.w),
      child: Expander(
        leading: Icon(FluentIcons.settings),
        header: Text('BMF Config', style: TextStyle(fontSize: 24.sp)),
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
