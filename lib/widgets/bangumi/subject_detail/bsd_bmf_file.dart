// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../../core/theme/bt_theme.dart';
import '../../../tools/file_tool.dart';
import '../../../tools/notifier_tool.dart';
import '../../../ui/bt_dialog.dart';
import '../../../ui/bt_icon.dart';
import '../../../ui/bt_infobar.dart';
import '../../../utils/tool_func.dart';

class BsdBmfFile extends ConsumerStatefulWidget {
  final String bmfFile;
  final int subject;

  const BsdBmfFile(this.bmfFile, this.subject, {super.key});

  @override
  ConsumerState<BsdBmfFile> createState() => _BsdBmfFileState();
}

class _BsdBmfFileState extends ConsumerState<BsdBmfFile> {
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
  void didUpdateWidget(BsdBmfFile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bmfFile != widget.bmfFile) {
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(
            width: double.infinity,
            child: ProgressBar(value: null),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [Text('下载中：${filesize(size)}')],
          ),
        ],
      );
    }
    if (!file.endsWith('.mp4') && !file.endsWith('.mkv')) return deleteBtn;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [potplayerBtn, const SizedBox(width: 6), deleteBtn],
    );
  }

  Widget buildFileCard(BuildContext context, String file) {
    return SizedBox(
      width: 275,
      height: 200,
      child: Card(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: file,
              child: Text(
                file,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            buildFileAct(context, file),
          ],
        ),
      ),
    );
  }

  Widget buildFilesList() {
    if (files.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Text('没有找到任何文件', style: BTTypography.body(context)),
      );
    }

    if (files.length <= 6) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: files.map((f) => buildFileCard(context, f)).toList(),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: files.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: buildFileCard(context, files[index]),
        );
      },
    );
  }

  Widget buildTitle() {
    return Row(
      children: [
        Expanded(
          child: Tooltip(
            message: widget.bmfFile,
            child: Text(
              '下载目录: ${widget.bmfFile}',
              style: BTTypography.subtitle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        SizedBox(width: 8.w),
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildTitle(),
          SizedBox(height: 12.h),
          buildFilesList(),
        ],
      ),
    );
  }
}

class BsdBmfFilePotPlayerBtn extends StatelessWidget {
  final String file;
  final String download;

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

class BsdBmfFileDelBtn extends StatelessWidget {
  final String file;
  final String dir;
  final Future<void> Function() onDelete;
  final BTFileTool fileTool = BTFileTool();

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
