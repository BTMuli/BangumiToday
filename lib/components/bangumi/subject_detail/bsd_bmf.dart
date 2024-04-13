import 'package:dart_rss/domain/rss_item.dart';
import 'package:file_picker/file_picker.dart';
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
  Future<void> freshFiles(AppBmfModel bmf) async {
    if (bmf.download == null || bmf.download!.isEmpty) return;
    files = await fileTool.getFileNames(bmf.download!);
    setState(() {});
  }

  /// showBmfInfo
  void showBmfInfo(BuildContext context) {
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (context) => ContentDialog(
        title: Text('当前配置'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('RSS链接: ${bmf.rss ?? '暂无'}'),
            SizedBox(height: 12.h),
            Text('下载目录: ${bmf.download ?? '暂无'}'),
            SizedBox(height: 20.h),
            Text('*应用会根据配置 RSS 获取下载链接及标题，同时对照下载目录的文件属性获取观看进度'),
          ],
        ),
      ),
    );
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
            await BtInfobar.success(context, '成功设置下载目录');
            await freshFiles(bmf);
          },
        ),
      ],
    );
  }

  /// buildFileAct
  Widget buildFileAct(BuildContext context, String file) {
    return Row(
      children: [
        Button(
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
        ),
        SizedBox(width: 12.w),
        Button(
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
        ),
      ],
    );
  }

  /// buildFileCards
  List<Widget> buildFileCards(BuildContext context) {
    var res = <Widget>[];
    for (var file in files) {
      var card = Card(
        padding: EdgeInsets.symmetric(vertical: 16.w, horizontal: 16.h),
        margin: EdgeInsets.symmetric(vertical: 8.w, horizontal: 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              file,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text('文件路径: $file'),
            SizedBox(height: 8.h),
            buildFileAct(context, file),
          ],
        ),
      );
      res.add(card);
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
              await freshFiles(bmf);
            }),
        SizedBox(width: 12.w),
        Text('下载目录: ${bmf.download}', style: TextStyle(fontSize: 24.sp)),
      ],
    );
    res.add(dirTitle);
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
            await freshRss(bmf);
          },
        ),
        SizedBox(width: 12.w),
        Text('Mikan RSS: ${bmf.rss}', style: TextStyle(fontSize: 24.sp)),
      ],
    );
    res.add(rssTitle);
    var rssCards = rssItems
        .map(
          (e) => MikanRssCard(e, dir: bmf.download),
        )
        .toList();
    res.addAll(rssCards);
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
        leading: IconButton(
          icon: Icon(FluentIcons.info),
          onPressed: () {
            showBmfInfo(context);
          },
        ),
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
