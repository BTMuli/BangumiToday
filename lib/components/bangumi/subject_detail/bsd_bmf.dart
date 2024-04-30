// Dart imports:
import 'dart:async';

// Package imports:
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../../database/app/app_bmf.dart';
import '../../../database/app/app_rss.dart';
import '../../../models/database/app_bmf_model.dart';
import '../../../store/nav_store.dart';
import '../../../tools/file_tool.dart';
import '../../../tools/notifier_tool.dart';
import '../../app/app_dialog.dart';
import '../../app/app_infobar.dart';
import 'bsd_bmf_file.dart';
import 'bsd_bmf_rss.dart';

/// Bangumi Subject Detail 的 Bangumi-Mikan-File Widget
/// 用于管理该 Subject 对应的 MikanRSS 及下载目录
class BsdBmf extends StatefulWidget {
  /// subjectId
  final int subjectId;

  /// 模式-是用于详情页还是用于配置页
  final bool isConfig;

  /// 构造函数
  const BsdBmf(this.subjectId, {super.key, this.isConfig = false});

  @override
  State<BsdBmf> createState() => _BsdBmfState();
}

/// BsdBmfState
class _BsdBmfState extends State<BsdBmf> with AutomaticKeepAliveClientMixin {
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
    Future.delayed(Duration.zero, () async {
      await init();
    });
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

  /// buildHeaderActRss
  Widget buildHeaderActRss(BuildContext context) {
    var text = '';
    if (bmf.rss == null || bmf.rss!.isEmpty) {
      text = '设置 RSS';
    } else {
      text = '修改 RSS';
    }
    return Button(
      child: Text(text),
      onPressed: () async {
        var input = await showInputDialog(
          context,
          title: '设置 MikanRSS',
          content: '建议精准到字幕组',
        );
        if (input == null) return;
        if (input == bmf.rss) {
          if (context.mounted) await BtInfobar.error(context, '未修改 MikanRSS');
          return;
        }
        var check = await sqliteBmf.checkRss(input);
        if (check) {
          if (context.mounted) await BtInfobar.error(context, '该RSS已经被其他BMF使用');
          return;
        }
        if (bmf.rss != null && bmf.rss!.isNotEmpty) {
          await sqliteRss.delete(bmf.rss!);
          if (context.mounted) {
            await BtInfobar.success(context, '成功删除旧 RSS 数据');
          }
        }
        bmf.rss = input;
        await sqliteBmf.write(bmf);
        var read = await sqliteBmf.read(bmf.subject);
        if (read != null) {
          bmf = read;
          setState(() {});
        }
        if (context.mounted) await BtInfobar.success(context, '成功设置 MikanRSS');
      },
    );
  }

  /// buildHeaderActFile
  Widget buildHeaderActFile(BuildContext context) {
    var text = '';
    if (bmf.download == null || bmf.download!.isEmpty) {
      text = '设置下载目录';
    } else {
      text = '修改下载目录';
    }
    return Button(
      child: Text(text),
      onPressed: () async {
        var dir = await getDirectoryPath();
        if (dir == null) return;
        var check = await sqliteBmf.checkDir(dir);
        if (check) {
          if (context.mounted) await BtInfobar.error(context, '该目录已经被其他BMF使用');
          return;
        }
        bmf.download = dir;
        await sqliteBmf.write(bmf);
        var read = await sqliteBmf.read(bmf.subject);
        if (read != null) {
          bmf = read;
          setState(() {});
        }
        if (context.mounted) await BtInfobar.success(context, '成功设置下载目录');
      },
      onLongPress: () async {
        if (bmf.download == null || bmf.download!.isEmpty) {
          await BtInfobar.error(context, '请先设置下载目录');
          return;
        }
        var res = await fileTool.openDir(bmf.download!);
        if (!res) {
          if (context.mounted) await BtInfobar.error(context, '打开目录失败：未检测到该目录');
        }
      },
    );
  }

  /// buildHeaderDel
  Widget buildHeaderDel(BuildContext context) {
    return Button(
      child: const Text('删除'),
      onPressed: () async {
        var confirm = await showConfirmDialog(
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
        BsdBmfFile(bmf.download!),
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
        leading: BsdBmfLeading(widget.subjectId, widget.isConfig),
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

  /// subjectId
  final int subjectId;

  /// 构造函数
  const BsdBmfLeading(this.subjectId, this.isConfig, {super.key});

  @override
  ConsumerState<BsdBmfLeading> createState() => _BsdBmfLeadingState();
}

/// BsdBmfLeadingState
class _BsdBmfLeadingState extends ConsumerState<BsdBmfLeading> {
  /// 数据库
  final BtsAppBmf sqliteBmf = BtsAppBmf();

  /// bmf
  late AppBmfModel bmf = AppBmfModel(subject: widget.subjectId);

  /// build
  @override
  Widget build(BuildContext context) {
    if (widget.isConfig) {
      return IconButton(
          icon: const Icon(FluentIcons.settings),
          onPressed: () =>
              ref.read(navStoreProvider).addNavItemB(subject: bmf.subject));
    }
    return IconButton(
      icon: const Icon(FluentIcons.settings),
      onPressed: () => ref.read(navStoreProvider).goIndex(2),
    );
  }
}
