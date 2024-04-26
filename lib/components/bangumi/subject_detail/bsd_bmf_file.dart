import 'dart:async';
import 'package:bangumi_today/tools/log_tool.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart' as path;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../pages/bangumi/bangumi_play.dart';
import '../../../store/nav_store.dart';
import '../../../tools/file_tool.dart';
import '../../../tools/notifier_tool.dart';
import '../../app/app_dialog.dart';
import '../../app/app_infobar.dart';

/// bmf文件部分的组件
class BsdBmfFile extends StatefulWidget {
  /// bmf file
  final String bmfFile;

  /// 构造
  const BsdBmfFile(this.bmfFile, {super.key});

  @override
  State<BsdBmfFile> createState() => _BsdBmfFileState();
}

/// 状态
class _BsdBmfFileState extends State<BsdBmfFile> {
  /// fileTool
  BTFileTool fileTool = BTFileTool();

  /// 文件
  List<String> files = [];

  /// aria2文件，motrix缓存文件
  List<String> aria2Files = [];

  /// 刷新定时器
  late Timer timerFiles;

  /// initState
  @override
  void initState() {
    super.initState();
    timerFiles = getTimerFiles();
    Future.delayed(Duration.zero, () async {
      await refreshFiles();
    });
  }

  /// dispose
  @override
  void dispose() {
    timerFiles.cancel();
    super.dispose();
  }

  Timer getTimerFiles() {
    return Timer.periodic(const Duration(seconds: 5), (timer) async {
      await refreshFiles();
    });
  }

  /// showNotify
  Future<void> showNotify(String file) async {
    await BTNotifierTool.showMini(
      title: '下载完成',
      body: '下载完成：$file',
      onClick: () async {
        var filePath = path.join(widget.bmfFile, file);
        filePath = filePath.replaceAll(r'\', '/');
        await launchUrlString('potplayer://$filePath');
      },
    );
  }

  /// 刷新文件
  Future<void> refreshFiles() async {
    var filesGet = await fileTool.getFileNames(widget.bmfFile);
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
          await showNotify(file);
        }
      }
    }
    aria2Files = aria2FilesGet;
    setState(() {});
  }

  List<Widget> buildFileAct(BuildContext context, String file) {
    var potplayerBtn = BsdBmfFilePotPlayerBtn(file, widget.bmfFile);
    var deleteBtn = BsdBmfFileDelBtn(
      file: file,
      dir: widget.bmfFile,
      onDelete: refreshFiles,
    );
    if (file.endsWith(".torrent")) {
      return [deleteBtn];
    }
    if (aria2Files.contains(file)) {
      var size = fileTool.getFileSize(path.join(widget.bmfFile, file));
      return [
        const SizedBox(width: double.infinity, child: ProgressBar(value: null)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [Text('下载中：${filesize(size)}')],
        ),
      ];
    }
    if (kDebugMode) {
      return [
        potplayerBtn,
        const SizedBox(height: 6),
        BsdBmfFileInnerPlayerBtn(file, widget.bmfFile),
        const SizedBox(height: 6),
        deleteBtn,
      ];
    }
    if (!file.endsWith('.mp4') && !file.endsWith('.mkv')) {
      return [deleteBtn];
    }
    return [potplayerBtn, const SizedBox(height: 6), deleteBtn];
  }

  List<Widget> buildFileCards(BuildContext context) {
    var res = <Widget>[];
    for (var file in files) {
      var title = Tooltip(
        message: file,
        child: Text(
          file,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      );
      var card = SizedBox(
        width: 275,
        height: 200,
        child: Card(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const Spacer(),
              ...buildFileAct(context, file),
            ],
          ),
        ),
      );
      res.add(card);
    }
    return res;
  }

  /// 构建文件
  Widget buildFiles() {
    if (files.isEmpty) {
      return const Text('没有找到任何文件');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: buildFileCards(context),
    );
  }

  /// buildTitle
  /// buildDirTitle
  Widget buildTitle() {
    return Row(
      children: [
        Button(
          child: const Text('刷新'),
          onPressed: () async {
            if (widget.bmfFile.isEmpty) {
              await BtInfobar.error(context, '请先设置下载目录');
              return;
            }
            await refreshFiles();
            if (mounted) await BtInfobar.success(context, '刷新文件成功');
          },
        ),
        SizedBox(width: 12.w),
        Text('下载目录: ${widget.bmfFile}', style: TextStyle(fontSize: 24.sp)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildTitle(),
        SizedBox(height: 12.h),
        buildFiles(),
      ],
    );
  }
}

/// 调用potplayer
class BsdBmfFilePotPlayerBtn extends StatelessWidget {
  /// 文件
  final String file;

  /// 下载目录
  final String download;

  /// 构造
  const BsdBmfFilePotPlayerBtn(this.file, this.download, {super.key});

  @override
  Widget build(BuildContext context) {
    return Button(
      child: Row(
        children: [
          Icon(FluentIcons.play, color: FluentTheme.of(context).accentColor),
          SizedBox(width: 8.w),
          const Text('调用PotPlayer打开'),
        ],
      ),
      onPressed: () async {
        var filePath = path.join(download, file);
        filePath = filePath.replaceAll(r'\', '/');
        var url = 'potplayer://$filePath';
        await launchUrlString(url);
      },
    );
  }
}

/// 调用内置播放
class BsdBmfFileInnerPlayerBtn extends ConsumerStatefulWidget {
  /// 文件
  final String file;

  /// 目录
  final String download;

  /// 构造
  const BsdBmfFileInnerPlayerBtn(this.file, this.download, {super.key});

  @override
  ConsumerState<BsdBmfFileInnerPlayerBtn> createState() =>
      _BsdBmfFileInnerPlayerBtnState();
}

class _BsdBmfFileInnerPlayerBtnState
    extends ConsumerState<BsdBmfFileInnerPlayerBtn> {
  @override
  Widget build(BuildContext context) {
    return Button(
      child: Row(
        children: [
          Icon(FluentIcons.play, color: FluentTheme.of(context).accentColor),
          SizedBox(width: 8.w),
          const Text('调用内置播放器打开'),
        ],
      ),
      onPressed: () async {
        var navStore = ref.read(navStoreProvider);
        var filePath = path.join(widget.download, widget.file);
        var pane = PaneItem(
          icon: const Icon(FluentIcons.play),
          title: const Text('内置播放'),
          body: BangumiPlayPage(filePath),
        );
        navStore.addNavItem(pane, '内置播放');
      },
    );
  }
}

/// 删除按钮
class BsdBmfFileDelBtn extends StatelessWidget {
  /// 文件
  final String file;

  /// 目录
  final String dir;

  /// 删除回调
  final Future<void> Function() onDelete;

  /// 构造
  const BsdBmfFileDelBtn({
    required this.file,
    required this.dir,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Button(
      child: Row(
        children: [
          Icon(FluentIcons.delete, color: FluentTheme.of(context).accentColor),
          SizedBox(width: 8.w),
          const Text('删除'),
        ],
      ),
      onPressed: () async {
        var confirm = await showConfirmDialog(
          context,
          title: '删除文件',
          content: '确定删除文件 $file 吗？',
        );
        if (!confirm) return;
        var fileTool = BTFileTool();
        var filePath = path.join(dir, file);
        try {
          await fileTool.deleteFile(filePath);
        } catch (e) {
          var errInfo = ['删除文件失败', '文件：$file', '错误：$e'];
          if (context.mounted) {
            await BtInfobar.error(context, errInfo.join('\n'));
          }
          BTLogTool.error(errInfo);
        }
        if (context.mounted) BtInfobar.success(context, '成功删除文件 $file');
        await onDelete();
      },
    );
  }
}
