import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/theme/bt_theme.dart';
import '../../../database/app/app_rss.dart';
import '../../../models/database/app_bmf_model.dart';
import '../../../providers/app_providers.dart';
import '../../../tools/file_tool.dart';
import '../../../ui/bt_dialog.dart';
import '../../../ui/bt_icon.dart';
import '../../../ui/bt_infobar.dart';
import '../../../utils/tool_func.dart';
import 'bmf_expander.dart';

enum BmfFilterType { all, hasRss, hasDownload, hasNew }

class BmfCard extends ConsumerStatefulWidget {
  final AppBmfModel bmf;
  final VoidCallback? onDelete;

  const BmfCard({super.key, required this.bmf, this.onDelete});

  @override
  ConsumerState<BmfCard> createState() => _BmfCardState();
}

class _BmfCardState extends ConsumerState<BmfCard>
    with AutomaticKeepAliveClientMixin {
  final BTFileTool fileTool = BTFileTool();
  final BtsAppRss sqliteRss = BtsAppRss();

  int fileCount = 0;
  String totalSize = '0 B';
  int rssNewCount = 0;
  bool isLoading = true;

  AppBmfModel get bmf => widget.bmf;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.microtask(loadData);
  }

  @override
  void didUpdateWidget(BmfCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bmf.rss != widget.bmf.rss ||
        oldWidget.bmf.download != widget.bmf.download) {
      Future.microtask(loadData);
    }
  }

  Future<void> loadData() async {
    setState(() => isLoading = true);

    var fileStats = await _loadFileStats();
    var rssStats = await _loadRssStats();

    fileCount = fileStats['count'] as int;
    totalSize = fileStats['size'] as String;
    rssNewCount = rssStats;

    setState(() => isLoading = false);
  }

  Future<Map<String, dynamic>> _loadFileStats() async {
    if (bmf.download == null || bmf.download!.isEmpty) {
      return {'count': 0, 'size': '0 B'};
    }
    var files = await fileTool.getFileNames(bmf.download!);
    files = files.where((f) => !f.endsWith('.aria2')).toList();
    var totalBytes = await fileTool.getDirSize(bmf.download!);

    return {'count': files.length, 'size': filesize(totalBytes)};
  }

  Future<int> _loadRssStats() async {
    if (bmf.rss == null || bmf.rss!.isEmpty) return 0;

    var appRssModel = bmf.mkBgmId != null && bmf.mkBgmId!.isNotEmpty
        ? await sqliteRss.readByMkId(bmf.mkBgmId!)
        : await sqliteRss.read(bmf.rss!);
    if (appRssModel == null || appRssModel.data.isEmpty) return 0;
    return 0;
  }

  void _navigateToDetail() {
    ref
        .read(navStoreProvider.notifier)
        .addNavItemB(subject: bmf.subject, paneTitle: bmf.title, type: '动画');
  }

  void _showDetailDialog() {
    showDialog(
      context: context,
      builder: (context) => _BmfDetailDialog(
        bmf: bmf,
        fileCount: fileCount,
        totalSize: totalSize,
        onDelete: widget.onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var accentColor = FluentTheme.of(context).accentColor;

    return BTAcrylic.acrylicContainer(
      context: context,
      blurAmount: BTAcrylic.cardBlurAmount,
      opacity: FluentTheme.of(context).brightness == Brightness.dark
          ? 0.6
          : 0.8,
      borderRadius: BTRadius.largeBR,
      padding: EdgeInsets.all(12.w),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _showDetailDialog,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, accentColor),
              SizedBox(height: 12.h),
              _buildStats(context),
              SizedBox(height: 12.h),
              _buildActions(context, accentColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color accentColor) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BTRadius.smallBR,
          ),
          child: Icon(FluentIcons.media, size: 16.sp, color: accentColor),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: bmf.title ?? '未命名',
                child: Text(
                  bmf.title ?? '未命名',
                  style: BTTypography.subtitle(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'ID: ${bmf.subject}',
                style: BTTypography.caption(
                  context,
                ).copyWith(color: BTColors.textTertiary(context)),
              ),
            ],
          ),
        ),
        if (rssNewCount > 0)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BTRadius.roundBR,
            ),
            child: Text(
              '$rssNewCount',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStats(BuildContext context) {
    if (isLoading) {
      return Center(
        child: SizedBox(
          width: 16.w,
          height: 16.w,
          child: ProgressRing(strokeWidth: 2),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatRow(
          context,
          icon: MdiIcons.rss,
          label: 'RSS',
          value: bmf.rss != null && bmf.rss!.isNotEmpty ? '已配置' : '未配置',
          isActive: bmf.rss != null && bmf.rss!.isNotEmpty,
        ),
        SizedBox(height: 6.h),
        _buildStatRow(
          context,
          icon: FluentIcons.folder,
          label: '文件',
          value: '$fileCount 个 ($totalSize)',
          isActive: fileCount > 0,
        ),
      ],
    );
  }

  Widget _buildStatRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required bool isActive,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 12.sp,
          color: isActive
              ? FluentTheme.of(context).accentColor
              : BTColors.textTertiary(context),
        ),
        SizedBox(width: 6.w),
        Text('$label: ', style: BTTypography.caption(context)),
        Expanded(
          child: Text(
            value,
            style: BTTypography.caption(context).copyWith(
              color: isActive
                  ? BTColors.textPrimary(context)
                  : BTColors.textTertiary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, Color accentColor) {
    return Row(
      children: [
        Tooltip(
          message: '查看详情',
          child: IconButton(
            icon: BtIcon(FluentIcons.view, size: 14.sp),
            onPressed: _showDetailDialog,
          ),
        ),
        Tooltip(
          message: '跳转到详情页',
          child: IconButton(
            icon: BtIcon(FluentIcons.open_in_new_tab, size: 14.sp),
            onPressed: _navigateToDetail,
          ),
        ),
        const Spacer(),
        _buildMoreButton(context, accentColor),
      ],
    );
  }

  Widget _buildMoreButton(BuildContext context, Color accentColor) {
    var flyoutController = FlyoutController();

    return FlyoutTarget(
      controller: flyoutController,
      child: Tooltip(
        message: '更多操作',
        child: IconButton(
          icon: BtIcon(FluentIcons.more, size: 14.sp),
          onPressed: () {
            flyoutController.showFlyout(
              barrierDismissible: true,
              dismissOnPointerMoveAway: false,
              dismissWithEsc: true,
              builder: (context) => _buildMenuFlyout(context, accentColor),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuFlyout(BuildContext context, Color accentColor) {
    return MenuFlyout(
      items: [
        MenuFlyoutItem(
          leading: BtIcon(MdiIcons.bookEdit, size: 14.sp),
          text: const Text('设置标题'),
          onPressed: () => _handleSetTitle(context),
        ),
        MenuFlyoutItem(
          leading: BtIcon(MdiIcons.rss, size: 14.sp),
          text: const Text('设置 RSS'),
          onPressed: () => _handleSetRss(context),
        ),
        MenuFlyoutItem(
          leading: BtIcon(MdiIcons.folder, size: 14.sp),
          text: const Text('设置下载目录'),
          onPressed: () => _handleSetDownloadDir(context),
        ),
        const MenuFlyoutSeparator(),
        MenuFlyoutItem(
          leading: Icon(FluentIcons.delete, size: 14.sp, color: accentColor),
          text: Text('删除', style: TextStyle(color: accentColor)),
          onPressed: () => _handleDelete(context),
        ),
      ],
    );
  }

  Future<void> _handleSetTitle(BuildContext context) async {
    var res = await showInput(
      context,
      title: '设置标题',
      content: '',
      value: bmf.title ?? '',
    );
    if (res != null && mounted) {
      var repo = ref.read(bmfRepositoryProvider);
      bmf.title = res;
      await repo.write(bmf);
    }
  }

  Future<void> _handleSetRss(BuildContext context) async {
    var res = await showInput(
      context,
      title: '设置 MikanRSS',
      content: '建议精准到字幕组',
    );
    if (res != null && mounted) {
      var repo = ref.read(bmfRepositoryProvider);
      var check = await repo.checkRss(res, excludeSubject: bmf.subject);
      if (check && context.mounted) {
        await BtInfobar.error(context, '该RSS已经被其他BMF使用');
        return;
      }
      bmf.rss = res;
      await repo.write(bmf);
    }
  }

  Future<void> _handleSetDownloadDir(BuildContext context) async {
    var dir = await getDirectoryPath();
    if (dir != null && mounted) {
      var repo = ref.read(bmfRepositoryProvider);
      var check = await repo.checkDir(dir, excludeSubject: bmf.subject);
      if (check && context.mounted) {
        await BtInfobar.error(context, '该目录已经被其他BMF使用');
        return;
      }
      bmf.download = dir;
      await repo.write(bmf);
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    var confirm = await showConfirm(
      context,
      title: '删除 BMF',
      content: '确定删除 ${bmf.title ?? bmf.subject} 吗？',
    );
    if (confirm) {
      widget.onDelete?.call();
    }
  }
}

class _BmfDetailDialog extends ConsumerStatefulWidget {
  final AppBmfModel bmf;
  final int fileCount;
  final String totalSize;
  final VoidCallback? onDelete;

  const _BmfDetailDialog({
    required this.bmf,
    required this.fileCount,
    required this.totalSize,
    this.onDelete,
  });

  @override
  ConsumerState<_BmfDetailDialog> createState() => _BmfDetailDialogState();
}

class _BmfDetailDialogState extends ConsumerState<_BmfDetailDialog> {
  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Tooltip(
        message: '点击复制标题',
        child: GestureDetector(
          onTap: () async {
            await Clipboard.setData(
              ClipboardData(text: widget.bmf.title ?? ''),
            );
            if (context.mounted) {
              await BtInfobar.success(context, '已复制到剪贴板');
            }
          },
          child: Row(
            children: [
              Icon(FluentIcons.settings, size: 18.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  widget.bmf.title ?? 'BMF 配置',
                  style: BTTypography.subtitle(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      constraints: BoxConstraints(maxWidth: 960.w),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.bmf.download != null && widget.bmf.download!.isNotEmpty)
            BmfFileExpander(
              downloadDir: widget.bmf.download!,
              subject: widget.bmf.subject,
              maxHeight: 200.h,
            ),
          if (widget.bmf.download != null && widget.bmf.download!.isNotEmpty)
            SizedBox(height: 4.h),
          if (widget.bmf.rss != null && widget.bmf.rss!.isNotEmpty)
            BmfRssExpander(
              bmf: widget.bmf,
              isConfig: true,
              maxHeight: 200.h,
              onDelete: () async {
                var repo =
                    context.mounted ? ref.read(bmfRepositoryProvider) : null;
                if (repo == null) return;
                widget.bmf.rss = null;
                await repo.write(widget.bmf);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ),
      actions: [
        Button(
          child: const Text('关闭'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
