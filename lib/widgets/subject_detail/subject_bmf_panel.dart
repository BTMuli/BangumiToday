// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../controller/progress_controller.dart';
import '../../core/services/download_directory.dart';
import '../../core/services/file_service.dart';
import '../../core/theme/bt_theme.dart';
import '../../models/database/app_bmf_model.dart';
import '../../pages/subject_detail/subject_stat_providers.dart';
import '../../providers/app_providers.dart';
import '../../tools/log_tool.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_icon.dart';
import '../../ui/bt_infobar.dart';
import '../bmf/bmf_expander.dart';

/// 下载与订阅面板，也供每日放送页的抽屉复用。
class SubjectBmfPanel extends ConsumerStatefulWidget {
  final int subjectId;
  final String title;
  final String? airDate;
  final Future<void> Function() onSearchRss;
  final SubjectRssStatProvider? rssProvider;
  final bool embedded;

  const SubjectBmfPanel({
    super.key,
    required this.subjectId,
    required this.title,
    required this.airDate,
    required this.onSearchRss,
    this.rssProvider,
    this.embedded = false,
  });

  @override
  ConsumerState<SubjectBmfPanel> createState() => _SubjectBmfPanelState();
}

class _SubjectBmfPanelState extends ConsumerState<SubjectBmfPanel> {
  late ProgressController progress = ProgressController();
  final BTFileTool fileTool = BTFileTool();

  late AppBmfModel bmf = AppBmfModel(
    subject: widget.subjectId,
    title: widget.title,
    airDate: widget.airDate,
  );

  bool _initialized = false;
  VoidCallback? _removeRssListener;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async => await init());
    if (widget.rssProvider != null) {
      _removeRssListener = widget.rssProvider!.listen(_onRssChanged);
    }
  }

  @override
  void didUpdateWidget(SubjectBmfPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.rssProvider, widget.rssProvider)) {
      _removeRssListener?.call();
      _removeRssListener = widget.rssProvider?.listen(_onRssChanged);
    }
  }

  @override
  void dispose() {
    _removeRssListener?.call();
    super.dispose();
  }

  void _onRssChanged() async {
    if (!_initialized) return;
    try {
      // 搜索回调已完成写入，只重新读取，避免用面板的旧源列表再次覆盖。
      await init();
    } catch (error, stackTrace) {
      BTLogTool.error(['刷新 RSS 订阅失败', error.toString(), stackTrace.toString()]);
    }
  }

  Future<void> init() async {
    var repo = ref.read(bmfRepositoryProvider);
    var bmfGet = await repo.read(widget.subjectId);
    if (!mounted) return;
    if (bmfGet == null) {
      setState(() {
        bmf = AppBmfModel(
          subject: widget.subjectId,
          title: widget.title,
          airDate: widget.airDate,
        );
        _initialized = true;
      });
      return;
    }
    AppBmfModel resolvedBmf = bmfGet;
    if (resolvedBmf.airDate == null || resolvedBmf.airDate!.isEmpty) {
      resolvedBmf = resolvedBmf.copyWith(airDate: widget.airDate);
    }
    if (!mounted) return;
    setState(() {
      bmf = resolvedBmf;
      _initialized = true;
    });
  }

  Future<String?> getTitle() async {
    if (mounted) {
      progress = ProgressWidget.show(context, title: '正在查找标题', text: '请稍后');
    }
    var resp = await ref
        .read(bangumiRepositoryProvider)
        .getSubjectDetail(widget.subjectId.toString());
    progress.end();
    if (resp.code != 0 || resp.data == null) {
      if (mounted) await showRespErr(resp, context);
      return null;
    }
    var data = resp.data!;
    if (data.nameCn.isEmpty) return data.name;
    return data.nameCn;
  }

  /// 补齐空标题。
  ///
  /// 只更新内存里的 [bmf]，由调用方随后的写库一起落盘，避免一次用户操作触发两次
  /// 写入与两次 RSS 调度。
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
      bmf.title = res;
      setState(() {});
      var repo = ref.read(bmfRepositoryProvider);
      await repo.write(bmf);
      var read = await repo.read(bmf.subject);
      if (read != null) {
        bmf = read;
        setState(() {});
      }
      if (mounted) {
        await BtInfobar.success(context, '[${bmf.subject}]已设置标题：${bmf.title}');
      }
    }
  }

  Future<void> searchRss() async {
    await widget.onSearchRss();
    if (mounted) await init();
  }

  Future<void> updateRss(String? newRss) async {
    if (newRss == null) return;
    if (bmf.subscriptions.any((s) => s.url == newRss)) {
      if (mounted) await BtInfobar.error(context, '未修改 RSS');
      return;
    }
    var repo = ref.read(bmfRepositoryProvider);
    bmf = bmf.copyWith(rss: newRss);
    await titleCheck();
    var scheduled = await repo.write(bmf);
    // 写入已按自动更新设置发起过一次拉取，只为关闭自动更新的订阅补一次。
    if (!scheduled) await repo.refreshRss(bmf);
    var read = await repo.read(bmf.subject);
    if (read != null) bmf = read;
    setState(() {});
    if (mounted) await BtInfobar.success(context, '成功设置 RSS');
  }

  Future<void> updateFolder() async {
    var dir = await pickDownloadDirectory(currentPath: bmf.download);
    if (dir == null) return;
    var repo = ref.read(bmfRepositoryProvider);
    var check = await repo.checkDir(dir, excludeSubject: bmf.subject);
    if (check) {
      if (mounted) await BtInfobar.error(context, '该目录已经被其他BMF使用');
      return;
    }
    bmf.download = dir;
    await titleCheck();
    await repo.write(bmf);
    var read = await repo.read(bmf.subject);
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
    var repo = ref.read(bmfRepositoryProvider);
    await repo.delete(bmf.subject);
    if (isDelDir) await fileTool.deleteDir(bmf.download!);
    if (mounted) await BtInfobar.success(context, '成功删除 BMF 信息');
    bmf = AppBmfModel(
      subject: widget.subjectId,
      title: widget.title,
      airDate: widget.airDate,
    );
    setState(() {});
  }

  Future<void> deleteRss(int subscriptionId) async {
    bmf = bmf.copyWith(
      subscriptions: bmf.subscriptions
          .where((s) => s.id != subscriptionId)
          .toList(),
    );
    var repo = ref.read(bmfRepositoryProvider);
    await repo.write(bmf);
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
    var oldDir = bmf.download;
    bmf = bmf.copyWith(download: null);
    var repo = ref.read(bmfRepositoryProvider);
    await repo.write(bmf);
    if (isDelDir && oldDir != null) {
      await fileTool.deleteDir(oldDir);
      if (mounted) await BtInfobar.success(context, '成功删除下载目录及记录');
    } else {
      if (mounted) await BtInfobar.success(context, '成功删除下载记录');
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: widget.embedded ? Clip.antiAlias : Clip.none,
      decoration: widget.embedded
          ? BoxDecoration(
              color: BTColors.surfacePrimary(context),
              borderRadius: BTRadius.mediumBR,
              border: Border.all(color: BTColors.divider(context)),
            )
          : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          var maxExpanderHeight = (constraints.maxHeight * 0.65).clamp(
            180.0,
            480.0,
          );
          var hasRss = bmf.rss?.isNotEmpty == true;
          var hasDirectory = bmf.download?.isNotEmpty == true;
          return Column(
            children: [
              _buildTitleBar(context),
              Expanded(
                child: SingleChildScrollView(
                  primary: false,
                  padding: const EdgeInsets.all(12),
                  child: !_initialized
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: ProgressRing()),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (hasRss)
                              BmfRssExpander(
                                bmf: bmf,
                                isConfig: false,
                                maxHeight: maxExpanderHeight,
                                onDelete: deleteRss,
                                contentScrollable: false,
                              )
                            else
                              _buildEmptyRss(context),
                            const SizedBox(height: 12),
                            if (hasDirectory)
                              BmfFileExpander(
                                downloadDir: bmf.download!,
                                subject: bmf.subject,
                                maxHeight: maxExpanderHeight,
                                onDelete: deleteFolder,
                              )
                            else
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    '下载目录',
                                    style: BTTypography.caption(context),
                                  ),
                                  Button(
                                    key: const ValueKey('bmf-empty-folder'),
                                    onPressed: updateFolder,
                                    child: const Text('选择目录'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyRss(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(MdiIcons.rss, size: 28, color: BTColors.textTertiary(context)),
          const SizedBox(height: 12),
          Text('暂无 RSS 订阅', style: BTTypography.body(context)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton(onPressed: searchRss, child: const Text('搜索订阅')),
              Button(
                key: const ValueKey('bmf-empty-rss'),
                onPressed: () async {
                  var input = await showInput(
                    context,
                    title: '设置 RSS',
                    content: '建议精准到字幕组',
                  );
                  await updateRss(input);
                },
                child: const Text('粘贴 RSS'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    var actions = <Widget>[
      _buildTitleBarButton(
        icon: MdiIcons.bookEdit,
        tooltip: '设置标题',
        onPressed: bmf.id != -1 ? updateTitle : null,
      ),
      _buildTitleBarButton(
        icon: MdiIcons.rss,
        tooltip: '设置 RSS',
        onPressed: searchRss,
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
    ];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: FluentTheme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: widget.embedded
          ? Wrap(alignment: WrapAlignment.end, children: actions)
          : Row(
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
                ...actions,
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
      child: IconButton(icon: BtIcon(icon, size: 16), onPressed: onPressed),
    );
  }
}
