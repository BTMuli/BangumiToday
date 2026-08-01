import 'dart:async';

import '../../../models/rss/rss.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

import '../../../core/services/bmf_rss_service.dart';
import '../../../core/theme/bt_theme.dart';
import '../../../database/app/app_config.dart';
import '../../../database/app/app_rss.dart';
import '../../../models/database/app_bmf_model.dart';
import '../../../models/database/app_rss_model.dart';
import '../../../store/app_store.dart';
import '../../../store/dtt_store.dart';
import '../../../tools/download_tool.dart';
import '../../../tools/file_tool.dart';
import '../../../tools/notifier_tool.dart';
import '../../../ui/bt_dialog.dart';
import '../../../ui/bt_icon.dart';
import '../../../ui/bt_infobar.dart';
import '../../../utils/tool_func.dart';

class BmfFileExpander extends ConsumerStatefulWidget {
  final String downloadDir;
  final int subject;
  final double maxHeight;
  final Future<void> Function()? onDelete;
  final bool contentScrollable;
  final bool expandable;
  final ScrollController? contentScrollController;

  const BmfFileExpander({
    super.key,
    required this.downloadDir,
    required this.subject,
    required this.maxHeight,
    this.onDelete,
    this.contentScrollable = true,
    this.expandable = true,
    this.contentScrollController,
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
  int _refreshGeneration = 0;

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
      _refreshGeneration++;
      files.clear();
      aria2Files.clear();
      Future.microtask(refreshFiles);
    }
  }

  @override
  void dispose() {
    _refreshGeneration++;
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
    var generation = ++_refreshGeneration;
    var downloadDir = widget.downloadDir;
    var subject = widget.subject;
    var filesGet = await fileTool.getFileNames(downloadDir);
    if (!mounted || generation != _refreshGeneration) return;
    var aria2FilesGet = filesGet
        .where((element) => element.endsWith('.aria2'))
        .map((e) => e.replaceAll('.aria2', ''))
        .toList();
    if (aria2FilesGet.isNotEmpty) {
      if (!timerFiles.isActive) timerFiles = getTimerFiles();
    } else {
      if (timerFiles.isActive) timerFiles.cancel();
    }
    if (aria2Files.isNotEmpty && aria2FilesGet != aria2Files) {
      var diffFiles = aria2Files
          .where((element) => !aria2FilesGet.contains(element))
          .toList();
      if (diffFiles.isNotEmpty) {
        for (var file in diffFiles) {
          var exist = await fileTool.isFileExist(path.join(downloadDir, file));
          if (!mounted || generation != _refreshGeneration) return;
          if (!exist) continue;
          await notifierTool.showVideo(
            subject: subject,
            dir: downloadDir,
            file: file,
          );
          if (!mounted || generation != _refreshGeneration) return;
        }
      }
    }
    if (!mounted || generation != _refreshGeneration) return;
    setState(() {
      files = filesGet.where((element) => !element.endsWith('.aria2')).toList();
      aria2Files = aria2FilesGet;
    });
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

    if (!widget.contentScrollable || files.length <= 6) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: files.map((f) => buildFileItem(context, f)).toList(),
      );
    }

    return SizedBox(
      height: widget.maxHeight,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: files.length,
        itemBuilder: (context, index) {
          return buildFileItem(context, files[index]);
        },
      ),
    );
  }

  Widget _buildCountBadge(BuildContext context, int count) {
    var accentColor = FluentTheme.of(context).accentColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: accentColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;
    var header = Row(
      children: [
        Text('下载目录', style: BTTypography.subtitle(context)),
        if (files.isNotEmpty) ...[
          SizedBox(width: 8.w),
          _buildCountBadge(context, files.length),
        ],
        SizedBox(width: 8.w),
        Tooltip(
          message: widget.downloadDir.isEmpty ? '未设置下载目录' : widget.downloadDir,
          child: Icon(
            FluentIcons.info,
            size: 14.sp,
            color: BTColors.textTertiary(context),
          ),
        ),
        const Spacer(),
        if (widget.onDelete != null)
          Tooltip(
            message: '删除目录',
            child: IconButton(
              icon: BtIcon(
                FluentIcons.delete,
                size: 14.sp,
                color: FluentTheme.of(context).accentColor,
              ),
              onPressed: () async {
                var confirm = await showConfirm(
                  context,
                  title: '删除下载目录',
                  content: '确定删除该下载目录配置吗？',
                );
                if (!confirm) return;
                await widget.onDelete!();
              },
            ),
          ),
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
    );

    if (!widget.expandable) {
      return _buildFixedResourcePanel(
        context,
        leading: Icon(FluentIcons.folder_open, size: 18.sp, color: accentColor),
        header: header,
        content: buildContent(),
        controller: widget.contentScrollController,
      );
    }

    return Expander(
      leading: Icon(FluentIcons.folder_open, size: 18.sp, color: accentColor),
      header: header,
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
  final bool initiallyExpanded;
  final bool contentScrollable;
  final bool expandable;
  final ScrollController? contentScrollController;

  const BmfRssExpander({
    super.key,
    required this.bmf,
    required this.isConfig,
    required this.maxHeight,
    this.onDelete,
    this.initiallyExpanded = true,
    this.contentScrollable = true,
    this.expandable = true,
    this.contentScrollController,
  });

  @override
  ConsumerState<BmfRssExpander> createState() => _BmfRssExpanderState();
}

class _BmfRssExpanderState extends ConsumerState<BmfRssExpander> {
  AppBmfModel get bmf => widget.bmf;
  final sqlite = BtsAppRss();

  String? get mikanRss => ref.watch(appStoreProvider).mikanRss;
  AppRssModel? appRssModel;
  Set<String> rssItemsKey = {};
  Set<String> pendingItemKeys = {};
  List<RssItem> rssItems = [];
  StreamSubscription<BmfRssUpdateEvent>? _updateSubscription;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _listenToUpdate();
    Future.microtask(_loadData);
  }

  Future<void> _loadData() async {
    if (!mounted || bmf.rss == null || bmf.rss!.isEmpty) return;
    var generation = ++_loadGeneration;
    var currentBmf = bmf;
    var rssUrl = getRss();
    var model = currentBmf.mkBgmId == null || currentBmf.mkBgmId!.isEmpty
        ? await sqlite.read(currentBmf.rss!)
        : await sqlite.readByMkId(currentBmf.mkBgmId!);
    if (!mounted || generation != _loadGeneration) return;

    if (model == null) {
      model = AppRssModel(
        rss: rssUrl,
        data: '',
        ttl: 0,
        updated: 0,
        mkBgmId: currentBmf.mkBgmId,
        mkGroupId: currentBmf.mkGroupId,
      );
      await sqlite.write(model);
      if (!mounted || generation != _loadGeneration) return;
    }

    var items = model.data.isEmpty
        ? <RssItem>[]
        : RssFeed.parse(model.data).items;
    var itemKeys = items
        .map((item) => '${item.title ?? ''}|${item.pubDate ?? ''}')
        .toSet();
    var pendingKeys = Set<String>.from(model.pendingItemKeys);
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      appRssModel = model;
      rssItems = items;
      rssItemsKey = itemKeys;
      pendingItemKeys = pendingKeys;
    });
  }

  void _listenToUpdate() {
    var key = bmf.mkBgmId != null && bmf.mkBgmId!.isNotEmpty
        ? bmf.mkBgmId
        : bmf.rss;
    if (key == null) return;

    _updateSubscription = BmfRssService.instance.updateStream
        .where((event) => event.key == key)
        .listen((event) {
          var currentKey = bmf.mkBgmId != null && bmf.mkBgmId!.isNotEmpty
              ? bmf.mkBgmId
              : bmf.rss;
          if (!mounted || currentKey != key) return;
          _loadGeneration++;
          var items = List<RssItem>.from(event.items);
          var itemKeys = items
              .map((e) => '${e.title ?? ''}|${e.pubDate ?? ''}')
              .toSet();
          var pendingKeys = Set<String>.from(event.pendingItemKeys);
          var model = AppRssModel(
            mkBgmId: bmf.mkBgmId,
            mkGroupId: bmf.mkGroupId,
            rss: getRss(),
            data: event.rssData,
            ttl: 0,
            updated: event.updated.millisecondsSinceEpoch,
          );
          model.setPendingItemKeys(pendingKeys);
          setState(() {
            rssItems = items;
            rssItemsKey = itemKeys;
            pendingItemKeys = pendingKeys;
            appRssModel = model;
          });
        });
  }

  @override
  void didUpdateWidget(BmfRssExpander oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bmf.rss != widget.bmf.rss ||
        oldWidget.bmf.mkBgmId != widget.bmf.mkBgmId ||
        oldWidget.bmf.mkGroupId != widget.bmf.mkGroupId) {
      _loadGeneration++;
      _updateSubscription?.cancel();
      rssItems.clear();
      rssItemsKey.clear();
      pendingItemKeys.clear();
      if (widget.bmf.rss == null || widget.bmf.rss!.isEmpty) {
        appRssModel = null;
        return;
      }
      _listenToUpdate();
      Future.microtask(_loadData);
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _updateSubscription?.cancel();
    super.dispose();
  }

  String getRss() {
    if (bmf.mkBgmId == null || bmf.mkBgmId!.isEmpty) return bmf.rss!;
    var url = '$mikanRss/RSS/Bangumi?bangumiId=${bmf.mkBgmId}';
    if (bmf.mkGroupId != null) url += '&subgroupid=${bmf.mkGroupId}';
    return url;
  }

  String _itemKey(RssItem item) {
    return '${item.title ?? ''}|${item.pubDate ?? ''}';
  }

  Future<void> _markItemHandled(RssItem item) async {
    if (appRssModel == null) return;
    var key = _itemKey(item);
    if (!pendingItemKeys.remove(key)) return;
    appRssModel!.setPendingItemKeys(pendingItemKeys);
    await sqlite.updatePendingItems(appRssModel!);
    BmfRssService.instance.notifyPendingStateChanged(
      bmf,
      pendingItemKeys.length,
    );
    if (mounted) setState(() {});
  }

  Future<void> _markAllHandled() async {
    if (appRssModel == null || pendingItemKeys.isEmpty) return;
    pendingItemKeys.clear();
    appRssModel!.setPendingItemKeys(pendingItemKeys);
    await sqlite.updatePendingItems(appRssModel!);
    BmfRssService.instance.notifyPendingStateChanged(bmf, 0);
    if (mounted) setState(() {});
  }

  Widget buildRssItem(BuildContext context, RssItem item) {
    var fileSize = item.enclosure?.length != null
        ? filesize(item.enclosure!.length)
        : null;
    var isPending = pendingItemKeys.contains(_itemKey(item));
    var accentColor = FluentTheme.of(context).accentColor;

    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isPending
            ? accentColor.withValues(alpha: 0.1)
            : BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.smallBR,
        border: Border.all(
          color: isPending ? accentColor : BTColors.divider(context),
          width: 1,
        ),
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
                color: isPending
                    ? accentColor
                    : BTColors.textSecondary(context),
              ),
              SizedBox(width: 8.w),
              if (isPending) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BTRadius.roundBR,
                  ),
                  child: Text(
                    '新',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 7.w),
              ],
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
                  item.pubDate!.length > 10
                      ? item.pubDate!.substring(0, 10)
                      : item.pubDate!,
                  style: BTTypography.caption(context),
                ),
              ],
              const Spacer(),
              if (isPending)
                Tooltip(
                  message: '标记为已处理',
                  child: IconButton(
                    icon: BtIcon(FluentIcons.check_mark, size: 14.sp),
                    onPressed: () => _markItemHandled(item),
                  ),
                ),
              _RssItemActions(
                item: item,
                dir: bmf.download,
                subject: bmf.subject,
                rssLink: bmf.rss!,
                onHandled: () => _markItemHandled(item),
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

    if (!widget.contentScrollable || rssItems.length <= 6) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: rssItems.map((item) => buildRssItem(context, item)).toList(),
      );
    }

    return SizedBox(
      height: widget.maxHeight,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: rssItems.length,
        itemBuilder: (context, index) {
          return buildRssItem(context, rssItems[index]);
        },
      ),
    );
  }

  Widget _buildCountBadge(BuildContext context, int count) {
    var accentColor = FluentTheme.of(context).accentColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: accentColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;
    var rssLink = getRss();

    var header = Row(
      children: [
        Text('RSS 订阅', style: BTTypography.subtitle(context)),
        if (rssItems.isNotEmpty) ...[
          SizedBox(width: 8.w),
          _buildCountBadge(context, rssItems.length),
        ],
        if (pendingItemKeys.isNotEmpty) ...[
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BTRadius.roundBR,
            ),
            child: Text(
              '${pendingItemKeys.length} 条更新',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
        if (pendingItemKeys.isNotEmpty)
          Tooltip(
            message: '全部标记为已处理',
            child: IconButton(
              icon: BtIcon(FluentIcons.clear_selection, size: 14.sp),
              onPressed: _markAllHandled,
            ),
          ),
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
            onPressed: () async {
              var result = await BmfRssService.instance.refreshBmf(bmf);
              if (!context.mounted) return;
              if (result) {
                await BtInfobar.success(context, 'RSS 刷新成功');
              } else {
                await BtInfobar.error(context, 'RSS 刷新失败');
              }
            },
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
    );

    if (!widget.expandable) {
      return _buildFixedResourcePanel(
        context,
        leading: Icon(MdiIcons.rss, size: 18.sp, color: accentColor),
        header: header,
        content: buildContent(),
        controller: widget.contentScrollController,
      );
    }

    return Expander(
      initiallyExpanded: widget.initiallyExpanded,
      leading: Icon(MdiIcons.rss, size: 18.sp, color: accentColor),
      header: header,
      content: buildContent(),
    );
  }
}

Widget _buildFixedResourcePanel(
  BuildContext context, {
  required Widget leading,
  required Widget header,
  required Widget content,
  ScrollController? controller,
}) {
  return Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: BTColors.surfacePrimary(context),
      borderRadius: BTRadius.largeBR,
      border: Border.all(color: BTColors.divider(context)),
    ),
    child: Column(
      children: [
        ColoredBox(
          color: BTColors.surfaceSecondary(context),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Row(
              children: [
                leading,
                SizedBox(width: 10.w),
                Expanded(child: header),
              ],
            ),
          ),
        ),
        Container(height: 1, color: BTColors.divider(context)),
        Expanded(
          child: Scrollbar(
            controller: controller,
            thumbVisibility: controller != null,
            child: SingleChildScrollView(
              controller: controller,
              padding: EdgeInsets.all(10.w),
              child: content,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RssItemActions extends ConsumerWidget {
  final RssItem item;
  final String? dir;
  final int? subject;
  final String rssLink;
  final Future<void> Function()? onHandled;

  const _RssItemActions({
    required this.item,
    required this.dir,
    required this.subject,
    required this.rssLink,
    this.onHandled,
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
    var motrixOpened = await launchUrlString(
      'mo://new-task/?type=torrent&dir=$saveDir',
    );
    var torrentOpened = await launchUrlString('file://$savePath');
    if (motrixOpened || torrentOpened) {
      await onHandled?.call();
    } else if (context.mounted) {
      await BtInfobar.error(context, '未能将任务交给 Motrix');
    }
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
      await onHandled?.call();
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
          message: '交给 Motrix',
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
