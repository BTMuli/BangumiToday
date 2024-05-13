// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../../store/danmaku_hive.dart';
import '../../../store/play_store.dart';
import '../../../tools/file_tool.dart';
import '../../../tools/notifier_tool.dart';
import '../../../utils/tool_func.dart';
import '../../app/app_dialog.dart';
import '../../app/app_infobar.dart';

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
    if (!file.endsWith('.mp4') && !file.endsWith('.mkv')) {
      return [deleteBtn];
    }
    return [
      potplayerBtn,
      const SizedBox(height: 6),
      BsdBmfFileInnerPlayerBtn(file, widget.bmfFile, widget.subject),
      const SizedBox(height: 6),
      deleteBtn,
    ];
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
          onLongPress: () async {
            Pasteboard.writeText(widget.bmfFile);
            if (mounted) await BtInfobar.success(context, '已复制下载目录');
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
          Icon(FluentIcons.open_file,
              color: FluentTheme.of(context).accentColor),
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

/// 调用内置播放
class BsdBmfFileInnerPlayerBtn extends ConsumerStatefulWidget {
  /// 文件
  final String file;

  /// 目录
  final String download;

  /// subject
  final int subject;

  /// 构造
  const BsdBmfFileInnerPlayerBtn(
    this.file,
    this.download,
    this.subject, {
    super.key,
  });

  @override
  ConsumerState<BsdBmfFileInnerPlayerBtn> createState() =>
      _BsdBmfFileInnerPlayerBtnState();
}

class _BsdBmfFileInnerPlayerBtnState
    extends ConsumerState<BsdBmfFileInnerPlayerBtn> {
  /// 播放Hive
  final PlayHive hivePlay = PlayHive();

  /// 弹幕Hive
  /// todo 待使用
  final DanmakuHive hiveDanmaku = DanmakuHive();

  /// 获取集数
  Future<int?> getEpisode() async {
    var filePath = path.join(widget.download, widget.file);
    var episode = hivePlay.getBmfEpisode(widget.subject, filePath);
    if (episode == null) {
      var input = await showInputDialog(
        context,
        title: '请输入集数',
        content: '集数',
      );
      if (input == null || input.isEmpty) {
        if (mounted) await BtInfobar.error(context, '请输入集数');
        return null;
      }
      episode = int.tryParse(input);
      if (episode == null) {
        if (mounted) await BtInfobar.error(context, '请输入正确的集数');
        return null;
      }
    }
    return episode;
  }

  @override
  Widget build(BuildContext context) {
    var filePath = path.join(widget.download, widget.file);
    return Button(
      child: Row(
        children: [
          Icon(FluentIcons.play, color: FluentTheme.of(context).accentColor),
          SizedBox(width: 8.w),
          const Text('调用内置播放器打开'),
        ],
      ),
      onPressed: () async {
        var episode = await getEpisode();
        if (episode == null) return;
        await hivePlay.addBmf(filePath, widget.subject, episode);
        if (context.mounted) context.go('/play/${widget.subject}');
      },
      onLongPress: () async {
        var episode = await getEpisode();
        if (episode == null) return;
        await hivePlay.addBmf(filePath, widget.subject, episode, play: false);
        if (context.mounted) {
          await BtInfobar.success(context, '成功添加到播放列表');
        }
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
        if (context.mounted) {
          var check = await fileTool.deleteFile(filePath, context: context);
          if (!check) return;
          if (context.mounted) {
            await BtInfobar.success(context, '成功删除文件 $file');
            await onDelete();
          }
        }
      },
    );
  }
}
