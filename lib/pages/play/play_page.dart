// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ns_danmaku/ns_danmaku.dart';

// Project imports:
import '../../../store/nav_store.dart';
import '../../../store/play_store.dart';
import '../../../tools/file_tool.dart';
import '../../../tools/log_tool.dart';
import '../../components/app/app_infobar.dart';
import 'play_controller.dart';
import 'play_video.dart';

/// 播放页面
class PlayPage extends ConsumerStatefulWidget {
  /// subject
  final int subject;

  /// 构造函数
  const PlayPage({super.key, required this.subject});

  @override
  ConsumerState<PlayPage> createState() => _PlayPageState();
}

/// PlayPageState
class _PlayPageState extends ConsumerState<PlayPage> {
  /// player
  // BtPlayer player = BtPlayer();
  BtPlayer get player => ref.watch(playControllerProvider).player;

  /// controller
  // late VideoController controller = VideoController(player);
  VideoController get controller => ref.watch(playControllerProvider).video;

  /// hive
  final PlayHive hive = PlayHive();

  /// playList
  List<Media> get hiveList => hive.getPlayList(subject: widget.subject);

  /// fileTool
  final BTFileTool fileTool = BTFileTool();

  /// 获取playList
  List<Media> get playList => player.state.playlist.medias;

  /// 获取index
  int get index => player.state.playlist.index;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.microtask(() async => await init());
    hive.addListener(listenHive);
  }

  /// 初始化
  Future<void> init() async {
    await checkSubject();
    await player.open(Playlist(hiveList, index: 0));
  }

  /// 检测subject
  Future<void> checkSubject() async {
    var subject = widget.subject;
    if (subject == 0) {
      await BtInfobar.warn(context, '未找到播放资源');
      if (mounted) context.go('/');
      return;
    }
    await hive.open(subject: subject);
  }

  /// 监听hive
  void listenHive() {
    Future.microtask(() async => await refresh());
  }

  /// 处理播放列表变化
  Future<void> handleChange() async {
    await saveProgress();
    var playList = hive.getPlayList();
    if (playList.isEmpty) {
      BTLogTool.info('未检测到播放列表');
      await player.stop();
      return;
    }
    var index = playList.indexWhere((e) => e.extras?['episode'] == hive.curEp);
    if (index == -1) index = 0;
    await player.open(Playlist(playList, index: index));
    // 需要等待进度条加载完成，见 https://github.com/media-kit/media-kit/issues/804
    await player.stream.buffer.first;
    var progress = await hive.getProgress(hive.curEp);
    if (progress != 0) {
      BTLogTool.info('跳转到上次播放进度: $progress');
      await player.seek(Duration(milliseconds: progress));
    }
    setState(() {});
  }

  /// 跳转
  Future<void> jump(int index) async {
    BTLogTool.info('跳转到: $index');
    await player.jump(index);
    // 需要等待进度条加载完成，见 https://github.com/media-kit/media-kit/issues/804
    await player.stream.buffer.first;
    var progress = await hive.getProgress(index);
    if (progress != 0) {
      BTLogTool.info('跳转到上次播放进度: $progress');
      await player.seek(Duration(milliseconds: progress));
    }
  }

  /// 刷新播放列表
  Future<void> refresh() async {
    BTLogTool.info('刷新播放列表');
    if (hiveList.length != playList.length) {
      await handleChange();
      return;
    }
    var curMedia = playList[index];
    if (hive.curEp != curMedia.extras?['episode']) {
      await jump(index);
    }
  }

  /// 保存当前进度
  Future<void> saveProgress() async {
    if (playList.isEmpty) return;
    var progress = player.state.position.inMilliseconds;
    await hive.updateProgress(progress);
  }

  /// dispose
  @override
  void dispose() {
    hive.removeListener(listenHive);
    // player.dispose();
    super.dispose();
  }

  /// 构建顶部栏
  Widget buildHeader() {
    return PageHeader(
      title: Row(children: [
        IconButton(
          icon: const Icon(FluentIcons.back),
          onPressed: () async {
            await saveProgress();
            await player.stop();
            // 路由跳转到前一项，采用go_router
            if (mounted) context.go('/');
          },
        ),
        const Text('内置播放'),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(FluentIcons.camera),
          onPressed: () async => await fileTool.openScreenshotDir(),
        ),
      ]),
    );
  }

  /// 构建播放列表
  Widget buildItemAct(Media media) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(FluentIcons.info),
          onPressed: () async {
            await saveProgress();
            await player.pause();
            var subject = hive.curModel.subjectId;
            if (mounted) Navigator.pop(context);
            ref.read(navStoreProvider).addNavItemB(
                  type: '动画',
                  subject: subject,
                );
          },
        ),
        IconButton(
          icon: const Icon(FluentIcons.play),
          onPressed: () async {
            if (media.uri ==
                player.state.playlist.medias[player.state.playlist.index].uri) {
              await BtInfobar.warn(context, '所选视频已经在播放中！');
              return;
            }
            await saveProgress();
            hive.jump(media.extras?['episode']);
          },
        ),
        IconButton(
          icon: const Icon(FluentIcons.delete),
          onPressed: () async {
            // var confirm = await showConfirmDialog(
            //   context,
            //   title: '移除播放',
            //   content: '是否移除该播放任务？',
            // );
            // if (!confirm) return;
            // await hive.delete(item);
            // setState(() {});
            // if (mounted) await BtInfobar.success(context, '移除成功');
          },
          onLongPress: () async {
            // await hive.delete(item);
            // setState(() {});
          },
        ),
      ],
    );
  }

  /// 构建播放卡片
  Widget buildCard(int index) {
    var media = player.state.playlist.medias[index];
    return Card(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            media.extras?['episode'].toString() ?? media.uri,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [buildItemAct(media)],
          ),
        ],
      ),
    );
  }

  /// 构建播放列表
  Widget buildList() {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: ListView.separated(
        itemCount: player.state.playlist.medias.length,
        itemBuilder: (context, index) => buildCard(index),
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: 12, child: Center(child: Divider())),
      ),
    );
  }

  /// 构建弹幕
  Widget buildDanmaku() {
    return DanmakuView(
      createdController: (controller) {
        ref.read(playControllerProvider.notifier).setDanmaku(controller);
      },
      option: DanmakuOption(),
    );
  }

  /// 构建
  @override
  Widget build(BuildContext context) {
    if (hive.getPlayList().isEmpty) {
      return ScaffoldPage(
        header: buildHeader(),
        content: const Center(child: Text('没有找到任何播放任务')),
      );
    }
    return ScaffoldPage(
      header: buildHeader(),
      content: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(children: [
                  const PlayVideoWidget(),
                  buildDanmaku(),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 200, child: buildList())
          ],
        ),
      ),
    );
  }
}
