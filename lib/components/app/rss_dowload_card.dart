// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart' as material;

// Package imports:
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

// Project imports:
import '../../store/dtt_store.dart';
import '../../tools/download_tool.dart';
import '../../tools/file_tool.dart';
import '../../tools/log_tool.dart';
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

  /// trackers
  final trackers = findPublicTrackers();

  /// 是否初始化
  late bool isInit = false;

  /// 开始时间
  late int startTime;

  /// 耗时，当暂停时记录
  late int time = 0;

  /// torrent 文件地址
  late String filePath = '';

  /// torrentModel
  late Torrent? model;

  /// torrentTask
  late TorrentTask? task;

  /// 下载进度
  double? progress = 0;

  /// 平均下载速度
  double ads = 0;

  /// 平均上传速度
  double aps = 0;

  /// 最近下载速度
  double ds = 0;

  /// 最近上传速度
  double ps = 0;

  /// utp的连接数
  int utpc = 0;

  /// 已连接的节点数
  int active = 0;

  /// 做种数
  int seeders = 0;

  /// 全部节点数
  int all = 0;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      await initWidget();
    });
  }

  @override
  void dispose() {
    try {
      task?.stop();
    } catch (e) {
      var errInfo = [
        'RssDownloadCard dispose error: $e',
        'RssItemTitle: ${item.title}',
        'TorrentLink: ${item.enclosure?.url}',
        'SaveDir: $dir',
      ];
      BTLogTool.error(errInfo);
    }
    super.dispose();
  }

  /// 初始化监听
  void initListener(TorrentTask task) {
    var listener = task.createListener();
    listener
      ..on<TaskFileCompleted>((event) async => await completedTask(task))
      ..on<StateFileUpdated>((event) async => await freshDownload(task));
  }

  /// 初始化
  Future<void> initWidget() async {
    if (filePath.isEmpty) {
      filePath = await downloadTool.downloadRssTorrent(
        item.enclosure!.url!,
        item.title!,
        context: context,
      );
    }
    if (filePath.isEmpty) {
      ref.read(dttStoreProvider.notifier).removeTask(item);
      return;
    }
    model = await Torrent.parse(filePath);
    task = TorrentTask.newTask(model!, dir);
    if (mounted) await BtInfobar.success(context, '成功解析种子文件');
    initListener(task!);
    await task!.start();
    trackers.listen((urls) {
      for (var url in urls) {
        task!.startAnnounceUrl(url, model!.infoHashBuffer);
      }
    });
    for (var node in model!.nodes) {
      task!.addDHTNode(node);
    }
    startTime = DateTime.now().millisecondsSinceEpoch;
    progress = null;
    isInit = true;
    if (mounted) await BtInfobar.success(context, '初始化成功');
    setState(() {});
  }

  /// 处理下载完成
  Future<void> completedTask(TorrentTask task) async {
    var endTime = DateTime.now().millisecondsSinceEpoch;
    time = time + endTime - startTime;
    var timeStr = (time / 1000).toStringAsFixed(2);
    await task.stop();
    await BTNotifierTool.showMini(
      title: '下载完成，耗时：$timeStr 秒',
      body: '下载完成：${item.title}',
      onClick: () async {
        var file = path.join(dir, model!.name);
        file = file.replaceAll(r'\', '/');
        await launchUrlString('potplayer://$file');
      },
    );
    await Future.delayed(const Duration(seconds: 5), () async {
      var stateFile = path.join(dir, '${model!.infoHash}.bt.state');
      try {
        await fileTool.deleteFile(stateFile);
        if (mounted) await BtInfobar.success(context, '任务已经删除');
      } catch (e) {
        var errInfo = ['删除文件失败 $stateFile', '错误信息：$e'];
        if (mounted) await BtInfobar.error(context, errInfo.join('\n'));
        BTLogTool.error(errInfo);
      }
      ref.read(dttStoreProvider.notifier).removeTask(item);
    });
  }

  /// 刷新下载进度
  Future<void> freshDownload(TorrentTask task) async {
    progress = task.progress * 100;
    ads = task.averageDownloadSpeed;
    aps = task.averageUploadSpeed;
    ds = task.currentDownloadSpeed;
    ps = task.uploadSpeed;
    utpc = task.utpPeerCount;
    active = task.connectedPeersNumber;
    seeders = task.seederNumber;
    all = task.allPeersNumber;
    setState(() {});
  }

  /// 开始下载
  Future<void> startDownload() async {
    if (task == null) {
      await BtInfobar.error(context, '任务初始化失败');
      return;
    }
    if (task!.state == TaskState.paused) {
      BTLogTool.info('Resume task.');
      await resumeDownload();
      return;
    }
    if (task!.state == TaskState.running) {
      await BtInfobar.error(context, '任务正在下载');
      return;
    }
    await task!.start();
  }

  /// 暂停下载
  Future<void> pauseDownload() async {
    if (task == null) {
      await BtInfobar.error(context, '任务初始化失败');
      return;
    }
    if (task!.state == TaskState.paused) {
      await BtInfobar.error(context, '任务已经暂停');
      return;
    }
    if (task!.state == TaskState.stopped) {
      await BtInfobar.error(context, '任务已经停止');
      return;
    }
    task!.pause();
    time = time + DateTime.now().millisecondsSinceEpoch - startTime;
    await BtInfobar.success(context, '任务已经暂停');
  }

  /// 重新下载
  Future<void> resumeDownload() async {
    if (task == null) {
      await BtInfobar.error(context, '任务初始化失败');
      return;
    }
    if (task?.state != TaskState.paused) {
      await BtInfobar.error(context, '任务未暂停');
      return;
    }
    task!.resume();
    startTime = DateTime.now().millisecondsSinceEpoch;
    await BtInfobar.success(context, '任务已经继续下载');
  }

  /// 停止下载
  Future<void> stopDownload() async {
    try {
      if (task == null) {
        await BtInfobar.error(context, '任务初始化失败');
        return;
      }
      if (task!.state == TaskState.stopped) {
        await BtInfobar.error(context, '任务已经停止');
        return;
      }
      await task!.stop();
      time = time + DateTime.now().millisecondsSinceEpoch - startTime;
      if (mounted) await BtInfobar.success(context, '任务已经停止');
    } catch (e) {
      if (mounted) await BtInfobar.error(context, e.toString());
    }
  }

  /// 重新下载
  Future<void> restartDownload() async {
    try {
      await task!.stop();
      await task!.start();
      trackers.listen((urls) {
        for (var url in urls) {
          task!.startAnnounceUrl(url, model!.infoHashBuffer);
        }
      });
      for (var node in model!.nodes) {
        task!.addDHTNode(node);
      }
      startTime = DateTime.now().millisecondsSinceEpoch;
      progress = null;
      if (mounted) await BtInfobar.success(context, '任务开始重新下载');
      setState(() {});
    } catch (e) {
      if (mounted) await BtInfobar.error(context, e.toString());
    }
  }

  /// 构建删除按钮
  Widget buildDelBtn() {
    return IconButton(
      icon: const Icon(FluentIcons.delete),
      onPressed: () async {
        var confirm = await showConfirmDialog(
          context,
          title: '删除任务？',
          content: '是否删除该任务？',
        );
        if (confirm) {
          await stopDownload();
          var stateFile = path.join(dir, '${model!.infoHash}.bt.state');
          try {
            await fileTool.deleteFile(stateFile);
          } catch (e) {
            var errInfo = ['删除文件失败 $stateFile', '错误信息：$e'];
            if (mounted) {
              await BtInfobar.error(context, errInfo.join('\n'));
            }
            BTLogTool.error(errInfo);
          }
          ref.read(dttStoreProvider.notifier).removeTask(item);
        }
      },
    );
  }

  /// 购买目录按钮
  Widget buildDirBtn() {
    return IconButton(
      icon: const Icon(material.Icons.folder_open),
      onPressed: () async {
        await fileTool.openDir(dir);
      },
    );
  }

  /// 构建组件trailing
  Widget buildCardTrail() {
    return Row(
      children: [
        buildDelBtn(),
        SizedBox(width: 8.w),
        buildDirBtn(),
      ],
    );
  }

  /// 构建组件
  Widget buildCard() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(item.title ?? ''),
            subtitle: Text('$dir\\${model?.name ?? ''}'),
            trailing: buildCardTrail(),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${filesize((ds * 1000).toInt())}'
                '(${filesize((ads * 1000).toInt())})',
              ),
              SizedBox(width: 8.w),
              Text('节点：$active/$seeders/$all'),
              SizedBox(width: 8.w),
              Text(
                  '上传：${filesize((aps * 1000).toInt())}/${filesize((ps * 1000).toInt())}'),
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
                icon: const Icon(FluentIcons.refresh),
                onPressed: () async {
                  var confirm = await showConfirmDialog(
                    context,
                    title: '重新下载？',
                    content: '是否重新下载该任务？',
                  );
                  if (confirm) {
                    // 清除下载时间
                    time = 0;
                    startTime = DateTime.now().millisecondsSinceEpoch;
                    await startDownload();
                  }
                },
              ),
              IconButton(
                icon: const Icon(FluentIcons.download),
                onPressed: () async {
                  await startDownload();
                },
              ),
              IconButton(
                icon: const Icon(FluentIcons.pause),
                onPressed: () async {
                  await pauseDownload();
                },
              ),
              IconButton(
                icon: const Icon(FluentIcons.stop),
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

  /// 只保留删除键跟进度条
  Widget buildEmptyCard() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(item.title ?? ''),
            subtitle: Text(dir),
            trailing: buildCardTrail(),
          ),
          SizedBox(height: 8.h),
          SizedBox(
            width: double.infinity,
            child: ProgressBar(value: null, strokeWidth: 16.h),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isInit) return buildEmptyCard();
    return buildCard();
  }
}
