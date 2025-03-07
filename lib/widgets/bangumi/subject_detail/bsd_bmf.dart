// Dart imports:
import 'dart:async';

// Package imports:
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../../controller/app/progress_controller.dart';
import '../../../database/app/app_bmf.dart';
import '../../../database/app/app_rss.dart';
import '../../../models/bangumi/bangumi_model.dart';
import '../../../models/database/app_bmf_model.dart';
import '../../../request/bangumi/bangumi_api.dart';
import '../../../store/nav_store.dart';
import '../../../tools/file_tool.dart';
import '../../../ui/bt_dialog.dart';
import '../../../ui/bt_icon.dart';
import '../../../ui/bt_infobar.dart';
import 'bsd_bmf_file.dart';
import 'bsd_bmf_rss.dart';

/// Bangumi Subject Detail 的 Bangumi-Mikan-File Widget
/// 用于管理该 Subject 对应的 MikanRSS 及下载目录
class BsdBmfWidget extends StatefulWidget {
  /// subjectId
  final int subjectId;

  /// title
  final String title;

  /// 模式-是用于详情页还是用于配置页
  final bool isConfig;

  /// 构造函数
  const BsdBmfWidget(
    this.subjectId,
    this.title, {
    super.key,
    this.isConfig = false,
  });

  @override
  State<BsdBmfWidget> createState() => _BsdBmfWidgetState();
}

/// BsdBmfState
class _BsdBmfWidgetState extends State<BsdBmfWidget>
    with AutomaticKeepAliveClientMixin {
  /// 数据库
  final BtsAppBmf sqliteBmf = BtsAppBmf();

  /// rss 数据库
  final BtsAppRss sqliteRss = BtsAppRss();

  /// bgmApi
  final BtrBangumiApi apiBgm = BtrBangumiApi();

  /// progress
  late ProgressController progress = ProgressController();

  /// file tool
  final BTFileTool fileTool = BTFileTool();

  /// bmf
  late AppBmfModel bmf = AppBmfModel(
    subject: widget.subjectId,
    title: widget.title,
  );

  /// 是否保持状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.microtask(() async => await init());
  }

  /// 初始化
  Future<void> init() async {
    var bmfGet = await sqliteBmf.read(widget.subjectId);
    if (bmfGet == null) return;
    setState(() => bmf = bmfGet);
  }

  /// 获取title
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

  /// 标题检测
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

  /// 更新标题
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

  /// 更新Rss链接
  Future<void> updateRss() async {
    var input = await showInput(
      context,
      title: '设置 MikanRSS',
      content: '建议精准到字幕组',
    );
    if (input == null) return;
    if (input == bmf.rss) {
      if (mounted) await BtInfobar.error(context, '未修改 MikanRSS');
      return;
    }
    var check = await sqliteBmf.checkRss(input);
    if (check) {
      if (mounted) await BtInfobar.error(context, '该RSS已经被其他BMF使用');
      return;
    }
    if (bmf.rss != null && bmf.rss!.isNotEmpty) {
      await sqliteRss.delete(bmf.rss!);
      if (mounted) await BtInfobar.success(context, '成功删除旧 RSS 数据');
    }
    bmf.rss = input;
    await titleCheck();
    await sqliteBmf.write(bmf);
    var read = await sqliteBmf.read(bmf.subject);
    if (read != null) {
      setState(() => bmf = read);
    }
    if (mounted) await BtInfobar.success(context, '成功设置 MikanRSS');
  }

  /// 更新下载目录
  Future<void> updateFolder() async {
    var dir = await getDirectoryPath();
    if (dir == null) return;
    var check = await sqliteBmf.checkDir(dir);
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

  /// 删除BMF
  Future<void> deleteBmf() async {
    var confirm = await showConfirm(
      context,
      title: '删除 BMF',
      content: '确定删除 BMF 信息吗？',
    );
    if (!confirm || !mounted) return;
    var delDirCheck = await showConfirm(
      context,
      title: '删除下载目录',
      content: '是否删除下载目录？',
    );
    await sqliteBmf.delete(bmf.subject);
    if (bmf.rss != null && bmf.rss!.isNotEmpty) {
      await sqliteRss.delete(bmf.rss!);
    }
    if (delDirCheck && bmf.download != null && bmf.download!.isNotEmpty) {
      await fileTool.deleteDir(bmf.download!);
    }
    if (mounted) await BtInfobar.success(context, '成功删除 BMF 信息');
    bmf = AppBmfModel(subject: widget.subjectId);
    setState(() {});
  }

  /// buildHeaderActTitle
  Widget buildHeaderActTitle(BuildContext context) {
    var hasTitle = bmf.title != null && bmf.title!.isNotEmpty;
    return Tooltip(
      message: hasTitle ? '修改标题' : '设置标题',
      child: IconButton(
        icon: BtIcon(hasTitle ? MdiIcons.bookEdit : MdiIcons.bookEditOutline),
        onPressed: updateTitle,
      ),
    );
  }

  /// buildHeaderActRss
  Widget buildHeaderActRss(BuildContext context) {
    var hasRss = bmf.rss != null && bmf.rss!.isNotEmpty;
    return Tooltip(
      message: hasRss ? '修改 RSS' : '设置 RSS',
      child: IconButton(
        icon: BtIcon(hasRss ? MdiIcons.rssBox : MdiIcons.rss),
        onPressed: () async => await updateRss(),
        onLongPress:
            hasRss ? () async => await launchUrlString(bmf.rss!) : null,
      ),
    );
  }

  /// buildHeaderActFile
  Widget buildHeaderActFile(BuildContext context) {
    var hasFolder = bmf.download != null && bmf.download!.isNotEmpty;
    return Tooltip(
      message: hasFolder ? '修改下载目录' : '设置下载目录',
      child: IconButton(
        icon: BtIcon(hasFolder ? MdiIcons.folderOpen : MdiIcons.folder),
        onPressed: updateFolder,
        onLongPress: () async => await fileTool.openDir(bmf.download!),
      ),
    );
  }

  /// buildHeaderDel
  Widget buildHeaderDel(BuildContext context) {
    return Tooltip(
      message: '删除 BMF',
      child: IconButton(icon: BtIcon(MdiIcons.delete), onPressed: deleteBmf),
    );
  }

  /// buildHeaderAction
  Widget buildHeaderAction(BuildContext context) {
    return Row(children: [
      if (bmf.id != -1) buildHeaderActTitle(context),
      buildHeaderActRss(context),
      buildHeaderActFile(context),
      if (bmf.id != -1) buildHeaderDel(context),
    ]);
  }

  /// buildContent
  List<Widget> buildContent(BuildContext context) {
    return <Widget>[
      if (bmf.download != null && bmf.download!.isNotEmpty)
        BsdBmfFile(bmf.download!, bmf.subject),
      SizedBox(height: 12.h),
      if (bmf.rss != null && bmf.rss!.isNotEmpty)
        BsdBmfRss(bmf, widget.isConfig),
    ];
  }

  /// build
  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (bmf.id == -1) {
      return ListTile(
        leading: const Icon(FluentIcons.error_badge),
        title: const Text('没有找到对应的 BMF 配置信息'),
        trailing: buildHeaderAction(context),
      );
    }
    var title = '${bmf.title ?? ''}(${bmf.subject})';
    if (!widget.isConfig) title = 'BMF Config - $title';
    return Expander(
      leading: BsdBmfLeading(widget.isConfig, bmf),
      header: Tooltip(
        message: title,
        child: Text(
          title,
          style: TextStyle(fontSize: 20),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: buildContent(context),
      ),
      trailing: buildHeaderAction(context),
    );
  }
}

/// leading组件
class BsdBmfLeading extends ConsumerStatefulWidget {
  /// isConfig
  final bool isConfig;

  final AppBmfModel bmf;

  /// 构造函数
  const BsdBmfLeading(this.isConfig, this.bmf, {super.key});

  @override
  ConsumerState<BsdBmfLeading> createState() => _BsdBmfLeadingState();
}

/// BsdBmfLeadingState
class _BsdBmfLeadingState extends ConsumerState<BsdBmfLeading> {
  void onPressed() {
    if (!widget.isConfig) {
      ref.read(navStoreProvider).goIndex(2);
      return;
    }
    ref.read(navStoreProvider).addNavItemB(
          subject: widget.bmf.subject,
          paneTitle: widget.bmf.title,
          type: '动画',
        );
  }

  /// build
  @override
  Widget build(BuildContext context) {
    return IconButton(icon: BtIcon(FluentIcons.settings), onPressed: onPressed);
  }
}
