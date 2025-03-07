// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../../tools/file_tool.dart';
import '../../../tools/notifier_tool.dart';
import '../../../ui/bt_dialog.dart';
import '../../../ui/bt_icon.dart';
import '../../../ui/bt_infobar.dart';
import '../../../utils/tool_func.dart';

/// bmf文件部分的组件
class BsdBmfFile extends ConsumerStatefulWidget {
  /// bmf file
  final String bmfFile;

  /// bmf subject
  final int subject;

  /// 构造
  const BsdBmfFile(this.bmfFile, this.subject, {super.key});

  @override
  ConsumerState<BsdBmfFile> createState() => _BsdBmfFileState();
}

/// 状态
class _BsdBmfFileState extends ConsumerState<BsdBmfFile> {
  /// fileTool
  final BTFileTool fileTool = BTFileTool();

  /// notifyTool
  final BTNotifierTool notifierTool = BTNotifierTool();

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
    Future.delayed(Duration.zero, () async => await refreshFiles());
  }

  /// dispose
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
          // 判断file是否存在
          var exist = await fileTool.isFileExist(
            path.join(widget.bmfFile, file),
          );
          if (!exist) continue;
          await notifierTool.showVideo(
            subject: widget.subject,
            dir: widget.bmfFile,
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
    var potplayerBtn = BsdBmfFilePotPlayerBtn(file, widget.bmfFile);
    var deleteBtn = BsdBmfFileDelBtn(
      file: file,
      dir: widget.bmfFile,
      onDelete: refreshFiles,
    );
    if (file.endsWith(".torrent")) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [deleteBtn],
      );
    }
    if (aria2Files.contains(file)) {
      var size = fileTool.getFileSize(path.join(widget.bmfFile, file));
      return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const SizedBox(width: double.infinity, child: ProgressBar(value: null)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [Text('下载中：${filesize(size)}')],
        ),
      ]);
    }
    if (!file.endsWith('.mp4') && !file.endsWith('.mkv')) return deleteBtn;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [potplayerBtn, const SizedBox(width: 6), deleteBtn],
    );
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
              buildFileAct(context, file),
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
    if (files.isEmpty) return const Text('没有找到任何文件');
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: buildFileCards(context),
    );
  }

  /// buildTitle
  Widget buildTitle() {
    return Flex(
      direction: Axis.horizontal,
      children: [
        Flexible(
          child: Tooltip(
            message: widget.bmfFile,
            child: Text(
              '下载目录: ${widget.bmfFile}',
              style: TextStyle(fontSize: 20),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: '刷新文件',
          child: IconButton(
            icon: BtIcon(FluentIcons.refresh),
            onPressed: () async {
              if (widget.bmfFile.isEmpty) {
                await BtInfobar.error(context, '请先设置下载目录');
                return;
              }
              await refreshFiles();
              if (mounted) await BtInfobar.success(context, '刷新文件成功');
            },
          ),
        ),
        Tooltip(
          message: '打开目录',
          child: IconButton(
            icon: BtIcon(FluentIcons.folder),
            onPressed: () async {
              if (widget.bmfFile.isEmpty) {
                await BtInfobar.error(context, '请先设置下载目录');
                return;
              }
              await fileTool.openDir(widget.bmfFile);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildTitle(),
        const SizedBox(height: 12),
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

/// 删除按钮
class BsdBmfFileDelBtn extends StatelessWidget {
  /// 文件
  final String file;

  /// 目录
  final String dir;

  /// 删除回调
  final Future<void> Function() onDelete;

  final BTFileTool fileTool = BTFileTool();

  /// 构造
  BsdBmfFileDelBtn({
    required this.file,
    required this.dir,
    required this.onDelete,
    super.key,
  });

  Future<void> tryDeleteFile(String filePath, BuildContext context) async {
    var check = await fileTool.deleteFile(filePath);
    if (!check) {
      if (context.mounted) {
        await BtInfobar.error(context, '删除文件失败');
      }
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
      onLongPress: () async {
        await tryDeleteFile(path.join(dir, file), context);
      },
      onPressed: () async {
        var confirm = await showConfirm(
          context,
          title: '删除文件',
          content: '确定删除文件 $file 吗？',
        );
        if (!confirm) return;
        var filePath = path.join(dir, file);
        if (context.mounted) {
          await tryDeleteFile(filePath, context);
        }
      },
    );
  }
}
