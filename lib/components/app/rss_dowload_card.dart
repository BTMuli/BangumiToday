import 'dart:async';
import 'package:dart_rss/domain/rss_item.dart';
import 'package:dtorrent_common/dtorrent_common.dart';
import 'package:dtorrent_parser/dtorrent_parser.dart';
import 'package:dtorrent_task/dtorrent_task.dart';
import 'package:filesize/filesize.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

import '../../store/dtt_store.dart';
import '../../tools/download_tool.dart';
import '../../tools/file_tool.dart';
import '../../tools/notifier_tool.dart';
import 'app_dialog.dart';
import 'app_infobar.dart';

/// 控制 rss 下载的状态
class RssDownloadCard extends ConsumerStatefulWidget {
  /// rssItem
  final RssItem item;

  /// 下载目录
  final String dir;

  /// 构造函数
  const RssDownloadCard(this.item, this.dir, {super.key});

  @override
  ConsumerState<RssDownloadCard> createState() => _RssDownloadCardState();
}

/// 控制 rss 下载的状态
class _RssDownloadCardState extends ConsumerState<RssDownloadCard> {
  /// 获取item
  RssItem get item => widget.item;

  /// 获取目录
  String get dir => widget.dir;

  /// downloadTool
  final downloadTool = BTDownloadTool();

  /// fileTool
  final fileTool = BTFileTool();

  /// 开始时间
  late int startTime;

  /// torrent 文件地址
  late String filePath;

  /// torrentModel
  late Torrent model;

  /// torrentTask
  late TorrentTask? task;

  /// 监听定时器，初始化为 1 小时
  late Timer timer = Timer(Duration(hours: 1), () {});

  /// 下载进度
  double? progress = 0;

  /// downloaded
  int downloaded = 0;

  /// 下载速度
  double speed = 0;

  /// 已连接的节点数
  int connectedPeersNumber = 0;

  /// 种子数
  int seeds = 0;

  /// 节点数
  int nodes = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      await downloadTool.init();
      await initDownload();
      await startDownload();
    });
  }

  @override
  void dispose() {
    task?.stop();
    timer.cancel();
    super.dispose();
  }

  /// 处理下载完成
  Future<void> completedTask(int startTime) async {
    var endTime = DateTime.now().millisecondsSinceEpoch;
    var time = (endTime - startTime) / 1000;
    await task!.stop();
    await BTNotifierTool.showMini(
      title: '下载完成，耗时：$time s',
      body: '下载完成：${item.title}',
      onClick: () async {
        var file = path.join(dir, model.name);
        file = file.replaceAll(r'\', '/');
        await launchUrlString('potplayer://$file');
      },
    );
    await Future.delayed(Duration(seconds: 5), () async {
      var stateFile = path.join(dir, '${model.infoHash}.bt.state');
      await fileTool.deleteFile(stateFile);
      ref.read(dttStoreProvider.notifier).removeTask(item);
    });
  }

  /// 初始化下载
  Future<void> initDownload() async {
    filePath = await BTDownloadTool().downloadRssTorrent(
      item.enclosure!.url!,
      item.title!,
    );
    model = await Torrent.parse(filePath);
    task = TorrentTask.newTask(model, dir);
    startTime = DateTime.now().millisecondsSinceEpoch;
    progress = null;
    setState(() {});
  }

  /// 刷新下载进度
  Future<void> freshDownload() async {
    assert(task != null);
    setState(() {
      progress = task!.progress * 100;
      speed = task!.currentDownloadSpeed;
      connectedPeersNumber = task!.connectedPeersNumber;
      seeds = task!.seederNumber;
      nodes = task!.allPeersNumber;
      downloaded = task!.downloaded ?? 0;
    });
    if (task!.progress == 1.0) {
      timer.cancel();
      await completedTask(DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// 开始下载
  Future<void> startDownload() async {
    if (task == null) {
      BtInfobar.error(context, '任务初始化失败');
      return;
    }
    debugPrint('task state: ${task!.state}');
    if (task!.state == TaskState.paused) {
      await resumeDownload();
      return;
    }
    await task!.start();
    findPublicTrackers().listen((urls) {
      for (var url in urls) {
        task!.startAnnounceUrl(url, model.infoHashBuffer);
      }
    });
    for (var node in model.nodes) {
      task!.addDHTNode(node);
    }
    timer = Timer.periodic(Duration(seconds: 2), (timer) async {
      await freshDownload();
    });
  }

  /// 暂停下载
  Future<void> pauseDownload() async {
    if (task == null) {
      BtInfobar.error(context, '任务初始化失败');
      return;
    }
    if (task!.state == TaskState.paused) {
      BtInfobar.error(context, '任务已经暂停');
      return;
    }
    if (task!.state == TaskState.stopped) {
      BtInfobar.error(context, '任务已经停止');
      return;
    }
    task!.pause();
    // timer.cancel();
    BtInfobar.success(context, '任务已经暂停');
  }

  /// 重新下载
  Future<void> resumeDownload() async {
    if (task == null) {
      BtInfobar.error(context, '任务初始化失败');
      return;
    }
    if (task?.state != TaskState.paused) {
      BtInfobar.error(context, '任务未暂停');
      return;
    }
    task!.resume();
    timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      await freshDownload();
    });
    BtInfobar.success(context, '任务已经继续下载');
  }

  /// 停止下载
  Future<void> stopDownload() async {
    if (task == null) {
      BtInfobar.error(context, '任务初始化失败');
      return;
    }
    if (task!.state == TaskState.stopped) {
      BtInfobar.error(context, '任务已经停止');
      return;
    }
    await task!.stop();
    // timer.cancel();
    await BtInfobar.success(context, '任务已经停止');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(item.title ?? ''),
            subtitle: Text('$dir\\${model.name}'),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${filesize((speed * 1000).toInt())}/s'),
              SizedBox(width: 8.w),
              Text('已下载：${filesize(downloaded)}'),
              SizedBox(width: 8.w),
              Text('连接节点：$connectedPeersNumber'),
              SizedBox(width: 8.w),
              Text('种子数：$seeds'),
              SizedBox(width: 8.w),
              Text('进度：${progress?.toStringAsFixed(2)}%')
            ],
          ),
          SizedBox(height: 8.h),
          SizedBox(
            width: double.infinity,
            child: ProgressBar(value: progress, strokeWidth: 16.h),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(FluentIcons.refresh),
                onPressed: () async {
                  var confirm = await showConfirmDialog(
                    context,
                    title: '重新下载？',
                    content: '是否重新下载该任务？',
                  );
                  if (confirm) {
                    await stopDownload();
                    await initDownload();
                    await startDownload();
                    BtInfobar.success(context, '任务开始重新下载');
                  }
                },
              ),
              IconButton(
                icon: Icon(FluentIcons.download),
                onPressed: () async {
                  await startDownload();
                },
              ),
              IconButton(
                icon: Icon(FluentIcons.pause),
                onPressed: () async {
                  await pauseDownload();
                },
              ),
              IconButton(
                icon: Icon(FluentIcons.stop),
                onPressed: () async {
                  await stopDownload();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
