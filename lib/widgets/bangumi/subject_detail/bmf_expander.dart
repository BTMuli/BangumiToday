import 'dart:async';

import 'package:dart_rss/domain/rss_feed.dart';
import 'package:dart_rss/domain/rss_item.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

import '../../../core/theme/bt_theme.dart';
import '../../../database/app/app_config.dart';
import '../../../database/app/app_rss.dart';
import '../../../models/database/app_bmf_model.dart';
import '../../../models/database/app_rss_model.dart';
import '../../../plugins/mikan/mikan_api.dart';
import '../../../store/app_store.dart';
import '../../../store/dtt_store.dart';
import '../../../store/nav_store.dart';
import '../../../tools/download_tool.dart';
import '../../../tools/file_tool.dart';
import '../../../tools/log_tool.dart';
import '../../../tools/notifier_tool.dart';
import '../../../ui/bt_dialog.dart';
import '../../../ui/bt_icon.dart';
import '../../../ui/bt_infobar.dart';
import '../../../utils/tool_func.dart';

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
  void didUpdateWidget(BmfFileExpander oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.downloadDir != widget.downloadDir) {
      files.clear();
      aria2Files.clear();
      Future.microtask(refreshFiles);
    }
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

  Widget buildFileItem(BuildContext context, String file) {
    var isDownloading = aria2Files.contains(file);
    var isVideo = file.endsWith('.mp4') || file.endsWith('.mkv');
    var isTorrent = file.endsWith('.torrent');

    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.smallBR,
        border: Border.all(color: BTColors.divider(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isTorrent
                    ? FluentIcons.file_code
                    : isVideo
                    ? FluentIcons.video
                    : FluentIcons.document,
                size: 16.sp,
                color: isDownloading
                    ? FluentTheme.of(context).accentColor
                    : BTColors.textSecondary(context),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Tooltip(
                  message: file,
                  child: Text(
                    file,
                    style: BTTypography.body(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              if (isDownloading) ...[
                Expanded(child: ProgressBar(value: null, strokeWidth: 2)),
                SizedBox(width: 8.w),
                Text(
                  '下载中',
                  style: BTTypography.caption(
                    context,
                  ).copyWith(color: FluentTheme.of(context).accentColor),
                ),
                SizedBox(width: 8.w),
              ] else
                const Spacer(),
              _FileItemActions(
                file: file,
                dir: widget.downloadDir,
                isVideo: isVideo,
                isTorrent: isTorrent,
                isDownloading: isDownloading,
                onDelete: refreshFiles,
              ),
            ],
          ),
        ],
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

    return SizedBox(
      height: files.length <= 6 ? null : widget.maxHeight,
      child: files.length <= 6
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: files.map((f) => buildFileItem(context, f)).toList(),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: files.length,
              itemBuilder: (context, index) {
                return buildFileItem(context, files[index]);
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
          Text('下载目录', style: BTTypography.subtitle(context)),
          SizedBox(width: 8.w),
          Tooltip(
            message: widget.downloadDir.isEmpty
                ? '未设置下载目录'
                : widget.downloadDir,
            child: Icon(
              FluentIcons.info,
              size: 14.sp,
              color: BTColors.textTertiary(context),
            ),
          ),
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

class _FileItemActions extends StatelessWidget {
  final String file;
  final String dir;
  final bool isVideo;
  final bool isTorrent;
  final bool isDownloading;
  final Future<void> Function() onDelete;
  final BTFileTool fileTool = BTFileTool();

  _FileItemActions({
    required this.file,
    required this.dir,
    required this.isVideo,
    required this.isTorrent,
    required this.isDownloading,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isVideo && !isDownloading)
          Tooltip(
            message: '打开文件',
            child: IconButton(
              icon: BtIcon(FluentIcons.open_file, size: 14.sp),
              onPressed: () async {
                var filePath = path.join(dir, file);
                await launchUrlString('file://$filePath');
              },
            ),
          ),
        Tooltip(
          message: '删除 (长按直接删除)',
          child: IconButton(
            icon: BtIcon(
              FluentIcons.delete,
              size: 14.sp,
              color: FluentTheme.of(context).accentColor,
            ),
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
            onLongPress: () async {
              var filePath = path.join(dir, file);
              if (context.mounted) await tryDeleteFile(filePath, context);
            },
          ),
        ),
      ],
    );
  }
}

class BmfRssExpander extends ConsumerStatefulWidget {
  final AppBmfModel bmf;
  final bool isConfig;
  final double maxHeight;
  final Future<void> Function()? onDelete;

  const BmfRssExpander({
    super.key,
    required this.bmf,
    required this.isConfig,
    required this.maxHeight,
    this.onDelete,
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
  void didUpdateWidget(BmfRssExpander oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bmf.rss != widget.bmf.rss ||
        oldWidget.bmf.mkBgmId != widget.bmf.mkBgmId ||
        oldWidget.bmf.mkGroupId != widget.bmf.mkGroupId) {
      rssItems.clear();
      rssItemsKey.clear();
      Future.microtask(() async => await freshRss());
    }
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
      BTLogTool.info('发现新的 RSS 信息');
      appRssModel = AppRssModel(
        mkBgmId: bmf.mkBgmId,
        mkGroupId: bmf.mkGroupId,
        rss: url,
        data: rssGet.data as String,
        ttl: feed.ttl,
        updated: DateTime.now().millisecondsSinceEpoch,
      );
      await sqlite.write(appRssModel!);
      if (!widget.isConfig) await showNewRss(newList);
    }
    setState(() {});
  }

  Future<void> showNewRss(List<RssItem> newList) async {
    if (newList.length > 1) {
      await BTNotifierTool.showMini(
        title: 'RSS 订阅更新',
        body: bmf.title ?? '动画：${bmf.subject}',
        onClick: () => ref
            .read(navStoreProvider.notifier)
            .addNavItemB(
              subject: bmf.subject,
              type: '动画',
              paneTitle: bmf.title,
            ),
      );
    }
    if (newList.length == 1) {
      await BTNotifierTool.showMini(
        title: 'RSS 订阅更新',
        body: '${newList[0].title}',
        onClick: () => ref
            .read(navStoreProvider.notifier)
            .addNavItemB(
              subject: bmf.subject,
              type: '动画',
              paneTitle: bmf.title,
            ),
      );
    }
  }

  Widget buildRssItem(BuildContext context, RssItem item) {
    var fileSize = item.enclosure?.length != null
        ? filesize(item.enclosure!.length)
        : null;

    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.smallBR,
        border: Border.all(color: BTColors.divider(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                MdiIcons.download,
                size: 16.sp,
                color: BTColors.textSecondary(context),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Tooltip(
                  message: item.title ?? '',
                  child: Text(
                    item.title ?? '',
                    style: BTTypography.body(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              if (fileSize != null) ...[
                Icon(
                  FluentIcons.save,
                  size: 10.sp,
                  color: BTColors.textTertiary(context),
                ),
                SizedBox(width: 4.w),
                Text(fileSize, style: BTTypography.caption(context)),
                SizedBox(width: 12.w),
              ],
              if (item.pubDate != null) ...[
                Icon(
                  FluentIcons.clock,
                  size: 10.sp,
                  color: BTColors.textTertiary(context),
                ),
                SizedBox(width: 4.w),
                Text(
                  item.pubDate!.substring(0, 10),
                  style: BTTypography.caption(context),
                ),
              ],
              const Spacer(),
              _RssItemActions(
                item: item,
                dir: bmf.download,
                subject: bmf.subject,
                rssLink: bmf.rss!,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildContent() {
    if (rssItems.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Text('没有找到任何 RSS 信息', style: BTTypography.body(context)),
      );
    }

    return SizedBox(
      height: rssItems.length <= 6 ? null : widget.maxHeight,
      child: rssItems.length <= 6
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: rssItems
                  .map((item) => buildRssItem(context, item))
                  .toList(),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: rssItems.length,
              itemBuilder: (context, index) {
                return buildRssItem(context, rssItems[index]);
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
          Text('RSS 订阅', style: BTTypography.subtitle(context)),
          SizedBox(width: 8.w),
          Tooltip(
            message: rssLink,
            child: Icon(
              FluentIcons.info,
              size: 14.sp,
              color: BTColors.textTertiary(context),
            ),
          ),
          const Spacer(),
          if (widget.onDelete != null)
            Tooltip(
              message: '删除订阅',
              child: IconButton(
                icon: BtIcon(
                  FluentIcons.delete,
                  size: 14.sp,
                  color: FluentTheme.of(context).accentColor,
                ),
                onPressed: () async {
                  var confirm = await showConfirm(
                    context,
                    title: '删除 RSS 订阅',
                    content: '确定删除该 RSS 订阅配置吗？',
                  );
                  if (!confirm) return;
                  await widget.onDelete!();
                },
              ),
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

class _RssItemActions extends ConsumerWidget {
  final RssItem item;
  final String? dir;
  final int? subject;
  final String rssLink;

  const _RssItemActions({
    required this.item,
    required this.dir,
    required this.subject,
    required this.rssLink,
  });

  Future<String?> getSavePath(BuildContext context) async {
    if (item.enclosure?.url == null || item.title == null) return null;
    var sqliteConfig = BtsAppConfig();
    var mikanUrl = await sqliteConfig.readMikanUrl();
    var urlReal = item.enclosure!.url!;
    if (mikanUrl != null && mikanUrl.isNotEmpty) {
      var url = Uri.parse(item.enclosure!.url!);
      var urlDomain = '${url.scheme}://${url.host}';
      urlReal = item.enclosure!.url!.replaceFirst(urlDomain, mikanUrl);
    }
    var dtt = BTDownloadTool();
    var savePath = await dtt.downloadRssTorrent(urlReal, item.title!);
    return savePath.isEmpty ? null : savePath;
  }

  Future<void> downloadWithMotrix(BuildContext context) async {
    if (item.enclosure?.url == null || item.title == null) return;
    var saveDir = dir;
    if (saveDir == null || saveDir.isEmpty) {
      await BtInfobar.error(context, '未设置下载目录');
      return;
    }
    var savePath = await getSavePath(context);
    if (savePath == null) return;
    await launchUrlString('mo://new-task/?type=torrent&dir=$saveDir');
    await launchUrlString('file://$savePath');
  }

  Future<void> downloadInner(BuildContext context, WidgetRef ref) async {
    if (item.enclosure?.url == null || item.title == null) return;
    var saveDir = dir;
    if (saveDir == null || saveDir.isEmpty) {
      await BtInfobar.error(context, '未设置下载目录');
      return;
    }
    var check = await ref
        .read(dttStoreProvider.notifier)
        .addTask(item, saveDir);
    if (check) {
      if (context.mounted) await BtInfobar.success(context, '添加下载任务成功');
    } else {
      if (context.mounted) await BtInfobar.warn(context, '已经在下载列表中');
    }
  }

  Future<void> openLink(BuildContext context) async {
    if (item.link == null) return;
    var sqliteConfig = BtsAppConfig();
    var mikanUrl = await sqliteConfig.readMikanUrl();
    var linkReal = item.link!;
    if (mikanUrl != null && mikanUrl.isNotEmpty) {
      var url = Uri.parse(item.link!);
      var urlDomain = '${url.scheme}://${url.host}';
      linkReal = item.link!.replaceFirst(urlDomain, mikanUrl);
    }
    await launchUrlString(linkReal);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (kDebugMode)
          Tooltip(
            message: '内置下载',
            child: IconButton(
              icon: BtIcon(FluentIcons.link, size: 14.sp),
              onPressed: () async => await downloadInner(context, ref),
            ),
          ),
        Tooltip(
          message: 'Motrix 下载',
          child: IconButton(
            icon: Image.asset(
              'assets/images/platforms/motrix-logo.png',
              width: 14.sp,
              height: 14.sp,
            ),
            onPressed: () async => await downloadWithMotrix(context),
          ),
        ),
        Tooltip(
          message: '打开链接',
          child: IconButton(
            icon: BtIcon(FluentIcons.edge_logo, size: 14.sp),
            onPressed: () async => await openLink(context),
          ),
        ),
      ],
    );
  }
}
