import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../controller/app/progress_controller.dart';
import '../../../core/theme/bt_theme.dart';
import '../../../database/app/app_bmf.dart';
import '../../../database/app/app_rss.dart';
import '../../../models/bangumi/bangumi_model.dart';
import '../../../models/database/app_bmf_model.dart';
import '../../../pages/subject-detail/subject_detail_page.dart';
import '../../../request/bangumi/bangumi_api.dart';
import '../../../tools/file_tool.dart';
import '../../../ui/bt_dialog.dart';
import '../../../ui/bt_icon.dart';
import '../../../ui/bt_infobar.dart';
import 'bmf_expander.dart';

class BsdBmfDrawer extends ConsumerStatefulWidget {
  final int subjectId;
  final String title;
  final SubjectRssStatProvider? rssProvider;

  const BsdBmfDrawer({
    super.key,
    required this.subjectId,
    required this.title,
    this.rssProvider,
  });

  @override
  ConsumerState<BsdBmfDrawer> createState() => _BsdBmfDrawerState();
}

class _BsdBmfDrawerState extends ConsumerState<BsdBmfDrawer> {
  final BtsAppBmf sqliteBmf = BtsAppBmf();
  final BtsAppRss sqliteRss = BtsAppRss();
  final BtrBangumiApi apiBgm = BtrBangumiApi();
  late ProgressController progress = ProgressController();
  final BTFileTool fileTool = BTFileTool();

  late AppBmfModel bmf = AppBmfModel(
    subject: widget.subjectId,
    title: widget.title,
  );

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async => await init());
    if (widget.rssProvider != null) {
      widget.rssProvider!.addListener(_onRssChanged);
    }
  }

  void _onRssChanged(String? val) async {
    if (!_initialized) return;
    await updateRss(val);
  }

  Future<void> init() async {
    var bmfGet = await sqliteBmf.read(widget.subjectId);
    if (bmfGet == null) {
      _initialized = true;
      return;
    }
    setState(() {
      bmf = bmfGet;
      _initialized = true;
    });
  }

  Future<String?> getTitle() async {
    if (mounted) {
      progress = ProgressWidget.show(context, title: '正在查找标题', text: '请稍后');
    }
    var resp = await apiBgm.getSubjectDetail(widget.subjectId.toString());
    progress.end();
    if (resp.code != 0 || resp.data == null) {
      if (mounted) await showRespErr(resp, context);
      return null;
    }
    var data = resp.data as BangumiSubject;
    if (data.nameCn.isEmpty) return data.name;
    return data.nameCn;
  }

  Future<void> titleCheck() async {
    if (bmf.title != null && bmf.title!.isNotEmpty) return;
    if (bmf.id != -1) {
      var confirm = await showConfirm(
        context,
        title: '尝试获取标题?',
        content: '检测到标题为空',
      );
      if (!confirm) return;
    }
    var title = await getTitle();
    if (title != null) bmf.title = title;
    setState(() {});
    await sqliteBmf.write(bmf);
    if (mounted && bmf.id != -1) {
      await BtInfobar.success(context, '[${bmf.subject}]已设置标题：${bmf.title}');
    }
  }

  Future<void> updateTitle() async {
    var hasTitle = bmf.title != null && bmf.title!.isNotEmpty;
    var title = bmf.title;
    if (!hasTitle) title = await getTitle();
    title ??= "";
    if (mounted) {
      var res = await showInput(
        context,
        title: hasTitle ? '修改标题' : '设置标题',
        value: title,
        content: '',
      );
      if (res == null) return;
      bmf.title = title;
      setState(() {});
      await sqliteBmf.write(bmf);
      var read = await sqliteBmf.read(bmf.subject);
      if (read != null) {
        bmf = read;
        setState(() {});
      }
      if (mounted) {
        await BtInfobar.success(context, '[${bmf.subject}]已设置标题：${bmf.title}');
      }
    }
  }

  Future<void> updateRss(String? newRss) async {
    if (newRss == null) return;
    if (newRss == bmf.rss) {
      if (mounted) await BtInfobar.error(context, '未修改 MikanRSS');
      return;
    }
    var check = await sqliteBmf.checkRss(newRss, excludeSubject: bmf.subject);
    if (check) {
      if (mounted) await BtInfobar.error(context, '该RSS已经被其他BMF使用');
      return;
    }
    if (bmf.rss != null && bmf.rss!.isNotEmpty) {
      await sqliteRss.delete(bmf.rss!);
      if (mounted) await BtInfobar.success(context, '成功删除旧 RSS 数据');
    }
    bmf = bmf.copyWith(rss: newRss);
    await titleCheck();
    await sqliteBmf.write(bmf);
    var read = (await sqliteBmf.read(bmf.subject));
    if (read != null) bmf = read;
    setState(() {});
    if (mounted) await BtInfobar.success(context, '成功设置 MikanRSS');
  }

  Future<void> updateFolder() async {
    var dir = await getDirectoryPath();
    if (dir == null) return;
    var check = await sqliteBmf.checkDir(dir, excludeSubject: bmf.subject);
    if (check) {
      if (mounted) await BtInfobar.error(context, '该目录已经被其他BMF使用');
      return;
    }
    bmf.download = dir;
    await titleCheck();
    await sqliteBmf.write(bmf);
    var read = await sqliteBmf.read(bmf.subject);
    if (read != null) {
      bmf = read;
      setState(() {});
    }
    if (mounted) await BtInfobar.success(context, '成功设置下载目录');
  }

  Future<void> deleteBmf() async {
    var isDelBmf = await showConfirm(
      context,
      title: '删除 BMF',
      content: '确定删除 BMF 信息吗？',
    );
    if (!isDelBmf || !mounted) return;
    var isDelDir = false;
    if (bmf.download != null && bmf.download!.isNotEmpty) {
      isDelDir = await showConfirm(
        context,
        title: '删除下载目录',
        content: '是否删除下载目录？',
      );
    }
    await sqliteBmf.delete(bmf.subject);
    if (bmf.rss != null && bmf.rss!.isNotEmpty) {
      await sqliteRss.delete(bmf.rss!);
    }
    if (isDelDir) await fileTool.deleteDir(bmf.download!);
    if (mounted) await BtInfobar.success(context, '成功删除 BMF 信息');
    bmf = AppBmfModel(subject: widget.subjectId);
    setState(() {});
  }

  Future<void> deleteRss() async {
    if (bmf.rss == null || bmf.rss!.isEmpty) return;
    await sqliteRss.delete(bmf.rss!);
    bmf = bmf.copyWith(rss: null);
    await sqliteBmf.write(bmf);
    if (mounted) await BtInfobar.success(context, '成功删除 RSS 订阅');
    setState(() {});
  }

  Future<void> deleteFolder() async {
    if (bmf.download == null || bmf.download!.isEmpty) return;
    var isDelDir = await showConfirm(
      context,
      title: '删除下载目录',
      content: '是否删除实际下载目录？\n取消则仅删除记录',
    );
    if (!mounted) return;
    bmf = bmf.copyWith(download: null);
    await sqliteBmf.write(bmf);
    if (isDelDir) {
      await fileTool.deleteDir(bmf.download!);
      if (mounted) await BtInfobar.success(context, '成功删除下载目录及记录');
    } else {
      if (mounted) await BtInfobar.success(context, '成功删除下载记录');
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var screenHeight = MediaQuery.of(context).size.height;
    var titleBarHeight = 48.h;
    var paddingHeight = 24.h;
    var maxExpanderHeight =
        (screenHeight - titleBarHeight - paddingHeight) * 0.35;

    return Column(
      children: [
        _buildTitleBar(context),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(12.w),
            child: Column(
              children: [
                if (bmf.download != null && bmf.download!.isNotEmpty)
                  BmfFileExpander(
                    downloadDir: bmf.download!,
                    subject: bmf.subject,
                    maxHeight: maxExpanderHeight,
                    onDelete: deleteFolder,
                  ),
                if (bmf.download != null && bmf.download!.isNotEmpty)
                  SizedBox(height: 8.h),
                if (bmf.rss != null && bmf.rss!.isNotEmpty)
                  BmfRssExpander(
                    bmf: bmf,
                    isConfig: false,
                    maxHeight: maxExpanderHeight,
                    onDelete: deleteRss,
                  ),
                if (bmf.id == -1)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    child: Column(
                      children: [
                        Icon(
                          FluentIcons.info,
                          size: 32.sp,
                          color: BTColors.textTertiary(context),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          '暂无 BMF 配置',
                          style: BTTypography.body(
                            context,
                          ).copyWith(color: BTColors.textSecondary(context)),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          '请设置 RSS 或下载目录',
                          style: BTTypography.caption(context),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: FluentTheme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: '点击复制标题',
              child: GestureDetector(
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(text: bmf.title ?? widget.title),
                  );
                  if (context.mounted) {
                    await BtInfobar.success(context, '已复制到剪贴板');
                  }
                },
                child: Text(
                  bmf.title ?? widget.title,
                  style: BTTypography.subtitle(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          _buildTitleBarButton(
            icon: MdiIcons.bookEdit,
            tooltip: '设置标题',
            onPressed: bmf.id != -1 ? updateTitle : null,
          ),
          _buildTitleBarButton(
            icon: MdiIcons.rss,
            tooltip: '设置 RSS',
            onPressed: () async {
              var input = await showInput(
                context,
                title: '设置 MikanRSS',
                content: '建议精准到字幕组',
              );
              await updateRss(input);
            },
          ),
          _buildTitleBarButton(
            icon: MdiIcons.folder,
            tooltip: '设置下载目录',
            onPressed: updateFolder,
          ),
          if (bmf.id != -1)
            _buildTitleBarButton(
              icon: MdiIcons.delete,
              tooltip: '删除 BMF',
              onPressed: deleteBmf,
            ),
        ],
      ),
    );
  }

  Widget _buildTitleBarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: BtIcon(icon, size: 16.sp),
        onPressed: onPressed,
      ),
    );
  }
}
