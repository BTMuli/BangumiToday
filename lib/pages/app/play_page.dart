// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// Project imports:
import '../../components/app/app_infobar.dart';
import '../../controller/app/video_controller.dart';
import '../../models/hive/play_model.dart';
import '../../store/nav_store.dart';
import '../../store/play_store.dart';
import '../../tools/file_tool.dart';
import '../../tools/log_tool.dart';

/// 播放页面
class PlayPage extends ConsumerStatefulWidget {
  /// 构造函数
  const PlayPage({super.key});

  @override
  ConsumerState<PlayPage> createState() => _PlayPageState();
}

/// PlayPageState
class _PlayPageState extends ConsumerState<PlayPage>
    with AutomaticKeepAliveClientMixin {
  /// 播放器
  late final player = Player();

  /// 控制器
  late final VideoController controller = VideoController(player);

  /// hive
  final PlayHive hive = PlayHive();

  /// fileTool
  final BTFileTool fileTool = BTFileTool();

  /// 获取playList
  List<Media> get playList => player.state.playlist.medias;

  /// 获取index
  int get index => player.state.playlist.index;

  /// 保持状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.microtask(() async => await refresh());
    hive.addListener(listenHive);
  }

  /// 监听hive
  void listenHive() {
    Future.microtask(() async => await refresh());
  }

  /// 处理播放列表变化
  Future<void> handleChange() async {
    await saveProgress();
    if (hive.all.isEmpty) {
      await player.stop();
      return;
    }
    var play = hive.all[hive.index].autoPlay;
    await player.open(Playlist(hive.allMedia, index: hive.index), play: play);
    // 需要等待进度条加载完成，见 https://github.com/media-kit/media-kit/issues/804
    await player.stream.buffer.first;
    var progress = hive.getProgress(index);
    if (progress != 0) {
      BTLogTool.info('跳转到上次播放进度: $progress');
      await player.seek(Duration(milliseconds: progress));
    }
    if (!play) await player.pause();
  }

  /// 跳转
  Future<void> jump(int index) async {
    BTLogTool.info('跳转到: $index');
    await player.jump(index);
    // 需要等待进度条加载完成，见 https://github.com/media-kit/media-kit/issues/804
    await player.stream.buffer.first;
    var progress = hive.getProgress(index);
    if (progress != 0) {
      BTLogTool.info('跳转到上次播放进度: $progress');
      await player.seek(Duration(milliseconds: progress));
    }
  }

  /// 刷新播放列表
  Future<void> refresh() async {
    BTLogTool.info('刷新播放列表');
    if (hive.all.length != playList.length) {
      await handleChange();
      return;
    }
    if (hive.index != index) await jump(hive.index);
  }

  /// 保存当前进度
  Future<void> saveProgress() async {
    if (playList.isEmpty) return;
    var progress = player.state.position.inMilliseconds;
    await hive.updateProgress(progress, index);
  }

  /// dispose
  @override
  void dispose() {
    hive.removeListener(listenHive);
    player.dispose();
    super.dispose();
  }

  /// 构建顶部栏
  Widget buildHeader() {
    var name = '无';
    if (hive.all.isNotEmpty) {
      var cur = hive.all[hive.index].file;
      name = Uri.parse(cur).pathSegments.last;
    }
    return PageHeader(
      title: Row(children: [
        const Text('内置播放'),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(FluentIcons.camera),
          onPressed: () async => await fileTool.openScreenshotDir(),
        ),
      ]),
      commandBar: Text(
        '当前播放：$name',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// 构建播放列表
  Widget buildItemAct(PlayHiveModel item, int index) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(FluentIcons.info),
          onPressed: () async {
            await saveProgress();
            await player.pause();
            ref.read(navStoreProvider).addNavItemB(
                  type: '动画',
                  subject: item.subjectId,
                );
          },
        ),
        IconButton(
          icon: const Icon(FluentIcons.play),
          onPressed: () async {
            if (item == hive.all[hive.index]) {
              await BtInfobar.warn(context, '所选视频已经在播放中！');
              return;
            }
            await saveProgress();
            hive.jump(item);
          },
        ),
        IconButton(
          icon: const Icon(FluentIcons.delete),
          onPressed: () async {
            await hive.delete(item);
            setState(() {});
          },
        ),
      ],
    );
  }

  /// 构建播放卡片
  Widget buildCard(PlayHiveModel item, int index) {
    var name = Uri.parse(item.file).pathSegments.last;
    return Card(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: name,
            child: Text(
              name,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [buildItemAct(item, index)],
          ),
        ],
      ),
    );
  }

  /// 构建播放卡片
  List<Widget> buildCards() {
    var res = <Widget>[];
    for (var i = 0; i < hive.all.length; i++) {
      res.add(buildCard(hive.all[i], i));
      if (i != hive.all.length - 1) {
        res.add(const SizedBox(height: 8));
        res.add(const Divider());
        res.add(const SizedBox(height: 8));
      }
    }
    return res;
  }

  /// 构建播放列表
  Widget buildList() {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: SingleChildScrollView(
        child: Column(children: buildCards()),
      ),
    );
  }

  /// 构建
  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (hive.all.isEmpty) {
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
            AspectRatio(
              aspectRatio: 16 / 9,
              child: BtcVideo(controller),
            ),
            const SizedBox(width: 8),
            Expanded(child: buildList()),
          ],
        ),
      ),
    );
  }
}
