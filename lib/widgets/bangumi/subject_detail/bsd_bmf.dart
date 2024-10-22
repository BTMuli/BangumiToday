// Dart imports:
import 'dart:async';

// Package imports:
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../../database/app/app_bmf.dart';
import '../../../database/app/app_rss.dart';
import '../../../models/database/app_bmf_model.dart';
import '../../../store/nav_store.dart';
import '../../../tools/file_tool.dart';
import '../../../tools/notifier_tool.dart';
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

  /// 模式-是用于详情页还是用于配置页
  final bool isConfig;

  /// 构造函数
  const BsdBmfWidget(this.subjectId, {super.key, this.isConfig = false});

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

  /// file tool
  final BTFileTool fileTool = BTFileTool();

  /// bmf
  late AppBmfModel bmf = AppBmfModel(subject: widget.subjectId);

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
    bmf = bmfGet;
    setState(() {});
  }

  /// showNotify
  Future<void> showNotify(String file) async {
    await BTNotifierTool.showMini(
      title: '下载完成',
      body: '下载完成：$file',
      onClick: () async {
        var filePath = path.join(bmf.download!, file);
        filePath = filePath.replaceAll(r'\', '/');
        await launchUrlString('potplayer://$filePath');
      },
    );
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
    await sqliteBmf.write(bmf);
    var read = await sqliteBmf.read(bmf.subject);
    if (read != null) {
      bmf = read;
      setState(() {});
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
    await sqliteBmf.write(bmf);
    var read = await sqliteBmf.read(bmf.subject);
    if (read != null) {
      bmf = read;
      setState(() {});
    }
    if (mounted) await BtInfobar.success(context, '成功设置下载目录');
  }

  /// buildHeaderActRss
  Widget buildHeaderActRss(BuildContext context) {
    var hasRss = bmf.rss != null && bmf.rss!.isNotEmpty;
    return Tooltip(
      message: hasRss ? '修改 RSS' : '设置 RSS',
      child: IconButton(
        icon: BtIcon(hasRss ? MdiIcons.rssBox : MdiIcons.rss),
        onPressed: updateRss,
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
      ),
    );
  }

  /// buildHeaderDel
  Widget buildHeaderDel(BuildContext context) {
    return Button(
      child: const Text('删除'),
      onPressed: () async {
        var confirm = await showConfirm(
          context,
          title: '删除 BMF',
          content: '确定删除 BMF 信息吗？',
        );
        if (!confirm) return;
        await sqliteBmf.delete(bmf.subject);
        if (bmf.rss != null && bmf.rss!.isNotEmpty) {
          await sqliteRss.delete(bmf.rss!);
        }
        if (context.mounted) await BtInfobar.success(context, '成功删除 BMF 信息');
        bmf = AppBmfModel(subject: widget.subjectId);
        setState(() {});
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
    return Padding(
      padding: EdgeInsets.only(right: 12.w),
      child: Expander(
        leading: BsdBmfLeading(widget.isConfig, bmf),
        header: widget.isConfig
            ? Text(bmf.subject.toString(), style: TextStyle(fontSize: 24.sp))
            : Text('BMF Config', style: TextStyle(fontSize: 24.sp)),
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
  /// build
  @override
  Widget build(BuildContext context) {
    if (widget.isConfig) {
      return IconButton(
        icon: const Icon(FluentIcons.settings),
        onPressed: () => ref.read(navStoreProvider).addNavItemB(
              subject: widget.bmf.subject,
              paneTitle: widget.bmf.title,
            ),
      );
    }
    return IconButton(
      icon: const Icon(FluentIcons.settings),
      onPressed: () => ref.read(navStoreProvider).goIndex(2),
    );
  }
}
