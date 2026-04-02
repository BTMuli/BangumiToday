import 'dart:async';

import 'package:dart_rss/domain/rss_feed.dart';
import 'package:dart_rss/domain/rss_item.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

import '../../../core/theme/bt_theme.dart';
import '../../../database/app/app_rss.dart';
import '../../../models/database/app_bmf_model.dart';
import '../../../models/database/app_rss_model.dart';
import '../../../plugins/mikan/mikan_api.dart';
import '../../../store/app_store.dart';
import '../../../tools/file_tool.dart';
import '../../../tools/log_tool.dart';
import '../../../tools/notifier_tool.dart';
import '../../../ui/bt_dialog.dart';
import '../../../ui/bt_icon.dart';
import '../../../ui/bt_infobar.dart';
import '../../../utils/tool_func.dart';
import '../../rss/rss_mk_card.dart';

class BmfFileExpander extends ConsumerStatefulWidget {
  final String downloadDir;
  final int subject;
  final double maxHeight;

  const BmfFileExpander({
    super.key,
    required this.downloadDir,
    required this.subject,
    required this.maxHeight,
  });

  @override
  ConsumerState<BmfFileExpander> createState() => _BmfFileExpanderState();
}

class _BmfFileExpanderState extends ConsumerState<BmfFileExpander> {
  final BTFileTool fileTool = BTFileTool();
  final BTNotifierTool notifierTool = BTNotifierTool();
  List<String> files = [];
  List<String> aria2Files = [];
  late Timer timerFiles;

  @override
  void initState() {
    super.initState();
    timerFiles = getTimerFiles();
    Future.microtask(refreshFiles);
  }

  @override
  void dispose() {
    timerFiles.cancel();
    super.dispose();
  }

  Timer getTimerFiles() {
    return Timer.periodic(
      const Duration(seconds: 5),
      (timer) async => await refreshFiles(),
    );
  }

  Future<void> refreshFiles() async {
    var filesGet = await fileTool.getFileNames(widget.downloadDir);
    var aria2FilesGet = filesGet
        .where((element) => element.endsWith('.aria2'))
        .map((e) => e.replaceAll('.aria2', ''))
        .toList();
    if (aria2FilesGet.isNotEmpty) {
      if (!timerFiles.isActive) timerFiles = getTimerFiles();
    } else {
      if (timerFiles.isActive) timerFiles.cancel();
    }
    files = filesGet.where((element) => !element.endsWith('.aria2')).toList();
    if (aria2Files.isNotEmpty && aria2FilesGet != aria2Files) {
      var diffFiles = aria2Files
          .where((element) => !aria2FilesGet.contains(element))
          .toList();
      if (diffFiles.isNotEmpty) {
        for (var file in diffFiles) {
          var exist = await fileTool.isFileExist(
            path.join(widget.downloadDir, file),
          );
          if (!exist) continue;
          await notifierTool.showVideo(
            subject: widget.subject,
            dir: widget.downloadDir,
            file: file,
            ref: ref,
          );
        }
      }
    }
    aria2Files = aria2FilesGet;
    setState(() {});
  }

  Widget buildFileAct(BuildContext context, String file) {
    var potplayerBtn = _FileOpenBtn(file, widget.downloadDir);
    var deleteBtn = _FileDeleteBtn(
      file: file,
      dir: widget.downloadDir,
      onDelete: refreshFiles,
    );
    if (file.endsWith(".torrent")) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [deleteBtn],
      );
    }
    if (aria2Files.contains(file)) {
      var size = fileTool.getFileSize(path.join(widget.downloadDir, file));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(
            width: double.infinity,
            child: ProgressBar(value: null),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [Text('下载中：${filesize(size)}')],
          ),
        ],
      );
    }
    if (!file.endsWith('.mp4') && !file.endsWith('.mkv')) return deleteBtn;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [potplayerBtn, const SizedBox(width: 6), deleteBtn],
    );
  }

  Widget buildFileCard(BuildContext context, String file) {
    return SizedBox(
      width: 275,
      height: 200,
      child: Card(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: file,
              child: Text(
                file,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            buildFileAct(context, file),
          ],
        ),
      ),
    );
  }

  Widget buildContent() {
    if (files.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Text('没有找到任何文件', style: BTTypography.body(context)),
      );
    }

    if (files.length <= 6) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: files.map((f) => buildFileCard(context, f)).toList(),
      );
    }

    return SizedBox(
      height: widget.maxHeight,
      child: ListView.builder(
        itemCount: files.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: buildFileCard(context, files[index]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;
    return Expander(
      leading: Icon(FluentIcons.folder_open, size: 18.sp, color: accentColor),
      header: Row(
        children: [
          Text('下载文件', style: BTTypography.subtitle(context)),
          const Spacer(),
          Tooltip(
            message: '刷新文件',
            child: IconButton(
              icon: BtIcon(FluentIcons.refresh, size: 14.sp),
              onPressed: () async {
                if (widget.downloadDir.isEmpty) {
                  await BtInfobar.error(context, '请先设置下载目录');
                  return;
                }
                await refreshFiles();
                if (context.mounted) await BtInfobar.success(context, '刷新文件成功');
              },
            ),
          ),
          Tooltip(
            message: '打开目录',
            child: IconButton(
              icon: BtIcon(FluentIcons.folder, size: 14.sp),
              onPressed: () async {
                if (widget.downloadDir.isEmpty) {
                  await BtInfobar.error(context, '请先设置下载目录');
                  return;
                }
                await fileTool.openDir(widget.downloadDir);
              },
            ),
          ),
        ],
      ),
      content: buildContent(),
    );
  }
}

class _FileOpenBtn extends StatelessWidget {
  final String file;
  final String download;

  const _FileOpenBtn(this.file, this.download);

  @override
  Widget build(BuildContext context) {
    return Button(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BtIcon(FluentIcons.open_file),
          SizedBox(width: 8.w),
          const Text('打开'),
        ],
      ),
      onPressed: () async {
        var filePath = path.join(download, file);
        await launchUrlString('file://$filePath');
      },
    );
  }
}

class _FileDeleteBtn extends StatelessWidget {
  final String file;
  final String dir;
  final Future<void> Function() onDelete;
  final BTFileTool fileTool = BTFileTool();

  _FileDeleteBtn({
    required this.file,
    required this.dir,
    required this.onDelete,
  });

  Future<void> tryDeleteFile(String filePath, BuildContext context) async {
    var check = await fileTool.deleteFile(filePath);
    if (!check) {
      if (context.mounted) await BtInfobar.error(context, '删除文件失败');
      return;
    }
    await onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return Button(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.delete, color: FluentTheme.of(context).accentColor),
          SizedBox(width: 8.w),
          const Text('删除'),
        ],
      ),
      onLongPress: () async =>
          await tryDeleteFile(path.join(dir, file), context),
      onPressed: () async {
        var confirm = await showConfirm(
          context,
          title: '删除文件',
          content: '确定删除文件 $file 吗？',
        );
        if (!confirm) return;
        var filePath = path.join(dir, file);
        if (context.mounted) await tryDeleteFile(filePath, context);
      },
    );
  }
}

class BmfRssExpander extends ConsumerStatefulWidget {
  final AppBmfModel bmf;
  final bool isConfig;
  final double maxHeight;

  const BmfRssExpander({
    super.key,
    required this.bmf,
    required this.isConfig,
    required this.maxHeight,
  });

  @override
  ConsumerState<BmfRssExpander> createState() => _BmfRssExpanderState();
}

class _BmfRssExpanderState extends ConsumerState<BmfRssExpander>
    with AutomaticKeepAliveClientMixin {
  AppBmfModel get bmf => widget.bmf;
  final api = BtrMikanApi();
  final sqlite = BtsAppRss();

  String? get mikanRss => ref.watch(appStoreProvider).mikanRss;
  AppRssModel? appRssModel;
  Set<String> rssItemsKey = {};
  List<RssItem> rssItems = [];
  late Timer timerRss;

  @override
  bool get wantKeepAlive => true;

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
      rssItemsKey = rssItems
          .map((e) => '${e.title ?? ''}|${e.pubDate ?? ''}')
          .toSet();
      setState(() {});
      await freshRss();
    });
  }

  @override
  void dispose() {
    timerRss.cancel();
    super.dispose();
  }

  Timer getTimerRss() {
    var minute = widget.isConfig ? 15 : 5;
    return Timer.periodic(Duration(minutes: minute), (timer) async {
      await freshRss();
      BTLogTool.info('BMF RSS 页面刷新 ${bmf.subject}');
    });
  }

  String getRss() {
    if (bmf.mkBgmId == null || bmf.mkBgmId!.isEmpty) return bmf.rss!;
    var url = '$mikanRss/RSS/Bangumi?bangumiId=${bmf.mkBgmId}';
    if (bmf.mkGroupId != null) url += '&subgroupid=${bmf.mkGroupId}';
    return url;
  }

  Future<void> freshRss() async {
    if (bmf.rss == null || bmf.rss!.isEmpty) return;
    var url = getRss();
    var rssGet = await api.getCustomRSS(url);
    var tryTimes = 0;
    while (rssGet.code != 0 && tryTimes < 3) {
      BTLogTool.warn([
        "【BmfRssExpander】【freshRss】Fail to load custom RSS,try $tryTimes times",
        "RSS Link: ${bmf.rss}",
      ]);
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
      rssItemsKey = rssItems
          .map((e) => '${e.title ?? ''}|${e.pubDate ?? ''}')
          .toSet();
      appRssModel = AppRssModel(
        mkBgmId: bmf.mkBgmId,
        mkGroupId: bmf.mkGroupId,
        rss: url,
        data: rssGet.data,
        ttl: feed.ttl,
        updated: DateTime.now().millisecondsSinceEpoch,
      );
      await sqlite.write(appRssModel!);
      setState(() {});
      return;
    }
    var newList = <RssItem>[];
    for (var item in feed.items) {
      var key = '${item.title ?? ''}|${item.pubDate ?? ''}';
      if (!rssItemsKey.contains(key)) newList.add(item);
    }
    rssItems = feed.items;
    rssItemsKey = rssItems
        .map((e) => '${e.title ?? ''}|${e.pubDate ?? ''}')
        .toSet();
    if (newList.isNotEmpty) {
      appRssModel = AppRssModel(
        mkBgmId: bmf.mkBgmId,
        mkGroupId: bmf.mkGroupId,
        rss: url,
        data: rssGet.data as String,
        ttl: feed.ttl,
        updated: DateTime.now().millisecondsSinceEpoch,
      );
      await sqlite.write(appRssModel!);
    }
    setState(() {});
  }

  Widget buildContent() {
    if (rssItems.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Text('没有找到任何 RSS 信息', style: BTTypography.body(context)),
      );
    }

    if (rssItems.length <= 6) {
      return Wrap(
        spacing: 12.w,
        runSpacing: 12.h,
        children: rssItems
            .map(
              (item) => RssMikanCard(
                bmf.rss!,
                item,
                dir: bmf.download,
                subject: bmf.subject,
              ),
            )
            .toList(),
      );
    }

    return SizedBox(
      height: widget.maxHeight,
      child: ListView.builder(
        itemCount: rssItems.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: RssMikanCard(
              bmf.rss!,
              rssItems[index],
              dir: bmf.download,
              subject: bmf.subject,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var accentColor = FluentTheme.of(context).accentColor;
    var rssLink = getRss();

    return Expander(
      leading: Icon(MdiIcons.rss, size: 18.sp, color: accentColor),
      header: Row(
        children: [
          Expanded(
            child: Text('RSS 订阅', style: BTTypography.subtitle(context)),
          ),
          Tooltip(
            message: '刷新 RSS',
            child: IconButton(
              icon: BtIcon(FluentIcons.refresh, size: 14.sp),
              onPressed: freshRss,
            ),
          ),
          Tooltip(
            message: '打开 RSS',
            child: IconButton(
              icon: BtIcon(FluentIcons.edge_logo, size: 14.sp),
              onPressed: () async => await launchUrlString(rssLink),
            ),
          ),
        ],
      ),
      content: buildContent(),
    );
  }
}
