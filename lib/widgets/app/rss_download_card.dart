// Dart imports:
import 'dart:async';

// Package imports:
import 'package:dtorrent_parser/dtorrent_parser.dart';
import 'package:dtorrent_task/dtorrent_task.dart';
import 'package:events_emitter2/events_emitter2.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../database/app/app_config.dart';
import '../../models/hive/dtt_model.dart';
import '../../store/dtt_store.dart';
import '../../store/tracker_hive.dart';
import '../../tools/download_tool.dart';
import '../../tools/file_tool.dart';
import '../../tools/log_tool.dart';
import '../../tools/notifier_tool.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../utils/tool_func.dart';

/// 控制 rss 下载的状态
class RssDownloadCard extends ConsumerStatefulWidget {
  /// rssItem
  final MiniRssItem item;

  /// 下载目录
  final String dir;

  /// 构造函数
  const RssDownloadCard(this.item, this.dir, {super.key});

  @override
  ConsumerState<RssDownloadCard> createState() => _RssDownloadCardState();
}

/// 控制 rss 下载的状态
class _RssDownloadCardState extends ConsumerState<RssDownloadCard>
    with AutomaticKeepAliveClientMixin {
  /// 获取item
  MiniRssItem get item => widget.item;

  /// 获取目录
  String get dir => widget.dir;

  final BtsAppConfig sqliteConfig = BtsAppConfig();

  /// hive
  final TrackerHive hive = TrackerHive();

  /// downloadTool
  final BTDownloadTool downloadTool = BTDownloadTool();

  /// fileTool
  final BTFileTool fileTool = BTFileTool();

  /// 监听
  late final EventsListener<TaskEvent> listener;

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
  late TorrentTask task;

  /// 下载进度
  double? progress = 0;

  /// 已下载
  int? downloaded = 0;

  /// 平均下载速度
  double ads = 0;

  /// 最近下载速度
  double ds = 0;

  /// utp的连接数
  int utpc = 0;

  /// 已连接的节点数
  int active = 0;

  /// 做种数
  int seeders = 0;

  /// 全部节点数
  int all = 0;

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await initWidget();
      if (mounted) await BtInfobar.success(context, '任务初始化成功');
    });
  }

  @override
  void dispose() {
    super.dispose();
    task.stop();
    listener.dispose();
  }

  /// 初始化监听
  Future<void> initListener(TorrentTask task) async {
    listener = task.createListener();
    listener
      ..on<StateFileUpdated>((event) => freshDownload(task))
      ..on<TaskCompleted>((event) async => await completedTask(task));
  }

  /// 添加tracker
  void addTracker(TorrentTask task) {
    var urls = hive.getTrackerList();
    for (var url in urls) {
      task.startAnnounceUrl(url, model!.infoHashBuffer);
    }
    for (var node in model!.nodes) {
      task.addDHTNode(node);
    }
  }

  /// 下载
  Future<String?> getSavePath(BuildContext context, String saveDir) async {
    // 获取mikan下载链接
    var mikanUrl = await sqliteConfig.readMikanUrl();
    var urlReal = item.link;
    if (mikanUrl != null && mikanUrl.isNotEmpty) {
      var url = Uri.parse(item.link);
      var urlDomain = '${url.scheme}://${url.host}';
      urlReal = item.link.replaceFirst(urlDomain, mikanUrl);
    }
    if (!context.mounted) return null;
    var savePath = await downloadTool.downloadRssTorrent(
      urlReal,
      item.title,
      context: context,
    );
    if (savePath.isEmpty) return null;
    return savePath;
  }

  /// 初始化
  Future<void> initWidget() async {
    if (filePath.isEmpty) {
      filePath = await getSavePath(context, dir) ?? '';
      BTLogTool.info('Download torrent file: $filePath');
    }
    BTLogTool.info('Parse torrent file: $filePath');
    if (filePath.isEmpty) {
      ref.read(dttStoreProvider.notifier).removeTask(item);
      return;
    }
    model = await Torrent.parse(filePath);
    task = TorrentTask.newTask(model!, dir);
    await initListener(task);
    await task.start();
    addTracker(task);
    startTime = DateTime.now().millisecondsSinceEpoch;
    progress = null;
    isInit = true;
    setState(() {});
  }

  /// 处理下载完成
  Future<void> completedTask(TorrentTask task) async {
    var endTime = DateTime.now().millisecondsSinceEpoch;
    time = time + endTime - startTime;
    var timeStr = (time / 1000).toStringAsFixed(2);
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
      await deleteStateFile();
      ref.read(dttStoreProvider.notifier).removeTask(item);
    });
  }

  /// 刷新下载进度
  void freshDownload(TorrentTask task) {
    progress = task.progress * 100;
    downloaded = task.downloaded;
    ads = task.averageDownloadSpeed;
    ds = task.currentDownloadSpeed;
    utpc = task.utpPeerCount;
    active = task.connectedPeersNumber;
    seeders = task.seederNumber;
    all = task.allPeersNumber;
    setState(() {});
  }

  /// 开始下载
  Future<void> startDownload() async {
    if (task.state == TaskState.paused) {
      BTLogTool.info('Resume task.');
      await resumeDownload();
      return;
    }
    if (task.state == TaskState.running) {
      await BtInfobar.error(context, '任务正在下载');
      return;
    }
    try {
      await task.start();
    } catch (e) {
      if (mounted) await BtInfobar.error(context, e.toString());
    }
  }

  /// 暂停下载
  Future<void> pauseDownload() async {
    if (task.state == TaskState.paused) {
      await BtInfobar.error(context, '任务已经暂停');
      return;
    }
    if (task.state == TaskState.stopped) {
      await BtInfobar.error(context, '任务已经停止');
      return;
    }
    task.pause();
    time = time + DateTime.now().millisecondsSinceEpoch - startTime;
    await BtInfobar.success(context, '任务已经暂停');
  }

  /// 重新下载
  Future<void> resumeDownload() async {
    if (task.state != TaskState.paused) {
      await BtInfobar.error(context, '任务未暂停');
      return;
    }
    task.resume();
    startTime = DateTime.now().millisecondsSinceEpoch;
    await BtInfobar.success(context, '任务已经继续下载');
  }

  /// 停止下载
  Future<void> stopDownload() async {
    try {
      if (task.state == TaskState.stopped) {
        await BtInfobar.error(context, '任务已经停止');
        return;
      }
      await task.stop();
      time = time + DateTime.now().millisecondsSinceEpoch - startTime;
      if (mounted) await BtInfobar.success(context, '任务已经停止');
    } catch (e) {
      if (mounted) await BtInfobar.error(context, e.toString());
    }
  }

  /// 重新下载
  Future<void> restartDownload() async {
    try {
      await task.stop();
      await task.start();
      var urls = hive.getTrackerList();
      for (var url in urls) {
        task.startAnnounceUrl(url, model!.infoHashBuffer);
      }
      for (var node in model!.nodes) {
        task.addDHTNode(node);
      }
      startTime = DateTime.now().millisecondsSinceEpoch;
      progress = null;
      if (mounted) await BtInfobar.success(context, '任务开始重新下载');
      setState(() {});
    } catch (e) {
      if (mounted) await BtInfobar.error(context, e.toString());
      rethrow;
    }
  }

  /// 删除state文件
  Future<void> deleteStateFile() async {
    var stateFile = path.join(dir, '${model!.infoHash}.bt.state');
    var check = await fileTool.deleteFile(stateFile, context: context);
    if (!check) return;
    if (mounted) await BtInfobar.success(context, '状态文件已经删除');
  }

  /// 构建删除按钮
  Widget buildDelBtn() {
    return IconButton(
      icon: const Icon(FluentIcons.delete),
      onPressed: () async {
        var confirmF = await showConfirm(
          context,
          title: '删除任务？',
          content: '是否删除该任务？',
        );
        if (!confirmF) return;
        if (isInit) {
          if (mounted) {
            var confirmS = await showConfirm(
              context,
              title: '删除状态文件？',
              content: '是否删除该任务的状态文件？',
            );
            if (confirmS) await deleteStateFile();
          }
          await stopDownload();
        }
        ref.read(dttStoreProvider.notifier).removeTask(item);
      },
    );
  }

  /// 购买目录按钮
  Widget buildDirBtn() {
    return IconButton(
      icon: const Icon(FluentIcons.folder_open),
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
            title: Text(item.title),
            subtitle: Text('$dir\\${model?.name ?? ''}'),
            trailing: buildCardTrail(),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${filesizeW((ds * 1000).toInt())}/s'
                  '(${filesizeW((ads * 1000).toInt())})'),
              SizedBox(width: 8.w),
              Text('节点：$active/$seeders/$all'),
            ],
          ),
          SizedBox(height: 8.h),
          SizedBox(
            width: double.infinity,
            child: ProgressBar(value: progress, strokeWidth: 16.h),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Text('已下载：${filesize(downloaded ?? 0)}'),
              SizedBox(width: 8.w),
              Text('进度：${progress?.toStringAsFixed(2)}%'),
              const Spacer(),
              IconButton(
                icon: const Icon(FluentIcons.refresh),
                onPressed: () async {
                  var confirm = await showConfirm(
                    context,
                    title: '重新下载？',
                    content: '是否重新下载该任务？',
                  );
                  if (confirm) await restartDownload();
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
            title: Text(item.title),
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
    super.build(context);
    if (!isInit) return buildEmptyCard();
    return buildCard();
  }
}
