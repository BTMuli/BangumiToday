// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ns_danmaku/ns_danmaku.dart';

// Project imports:
import '../../../store/nav_store.dart';
import '../../../store/play_store.dart';
import '../../../tools/file_tool.dart';
import '../../../tools/log_tool.dart';
import '../../components/app/app_dialog.dart';
import '../../components/app/app_infobar.dart';
import '../../source/source_load.dart';
import 'play_controller.dart';
import 'play_video.dart';

/// 播放页面
class PlayVodPage extends ConsumerStatefulWidget {
  /// subject
  final int subject;

  /// 构造函数
  const PlayVodPage({super.key, required this.subject});

  @override
  ConsumerState<PlayVodPage> createState() => _PlayVodPageState();
}

/// PlayPageState
class _PlayVodPageState extends ConsumerState<PlayVodPage>
    with AutomaticKeepAliveClientMixin {
  /// player
  // BtPlayer player = BtPlayer();
  BtPlayer get player => ref.watch(playControllerProvider).player;

  /// controller
  // late VideoController controller = VideoController(player);
  VideoController get controller => ref.watch(playControllerProvider).video;

  /// hive
  final PlayHive hive = PlayHive();

  /// fileTool
  final BTFileTool fileTool = BTFileTool();

  /// 获取playList
  late List<Media> playList = player.state.playlist.medias;

  /// 是否可播放
  late bool isPlayable = true;

  /// 获取index
  int get index => player.state.playlist.index;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    BTLogTool.info('init PlayVodPage');
    Future.microtask(() async {
      await freshList();
    });
    hive.addListener(listenHive);
  }

  /// 监听hive
  void listenHive() {
    playList = hive.getPlayList(subject: widget.subject);
    setState(() {});
  }

  @override
  void dispose() {
    hive.removeListener(listenHive);
    super.dispose();
  }

  /// 检测参数更新
  @override
  void didUpdateWidget(PlayVodPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subject == widget.subject) return;
    Future.microtask(() async {
      await saveProgress();
      await freshList();
    });
  }

  /// 刷新播放列表
  Future<void> freshList() async {
    playList = hive.getPlayList(subject: widget.subject);
    await player.open(Playlist(playList));
    if (playList.isEmpty) {
      if (mounted) await BtInfobar.warn(context, '播放列表为空！');
      isPlayable = false;
      setState(() {});
      return;
    }
    isPlayable = true;
    await player.stream.buffer.first;
    var progress = await hive.getProgress(playList[index].extras?['episode']);
    if (progress != 0) {
      await player.seek(Duration(milliseconds: progress));
    }
    setState(() {});
  }

  /// 保存当前进度
  Future<void> saveProgress() async {
    if (playList.isEmpty) return;
    var progress = player.state.position.inMilliseconds;
    var media = playList[index];
    var episode = media.extras?['episode'];
    await hive.updateProgress(progress, index: episode);
  }

  /// 处理非本地源的播放
  Future<void> handlePlay(Media media) async {
    var source = getSourceByName(hive.curSource);
    await source.play(media.uri, controller);
    debugPrint('play ${media.uri}');
  }

  /// 构建播放列表
  Widget buildItemAct(Media media) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(FluentIcons.info),
          onPressed: () async {
            await player.pause();
            await saveProgress();
            ref
                .read(navStoreProvider)
                .addNavItemB(type: '动画', subject: widget.subject);
            await player.pause();
          },
        ),
        IconButton(
          icon: const Icon(FluentIcons.play),
          onPressed: () async {
            if (hive.curSource != "BMF") {
              await handlePlay(media);
              return;
            }
            if (media.uri == playList[index].uri) {
              await BtInfobar.warn(context, '所选视频已经在播放中！');
              return;
            }
            await saveProgress();
            var mIdx = playList.indexWhere((e) => e.uri == media.uri);
            await ref
                .read(playControllerProvider.notifier)
                .jump(mIdx, media.extras?['episode']);
          },
        ),
        IconButton(
          icon: const Icon(FluentIcons.delete),
          onPressed: () async {
            if (hive.curSource != 'BMF') {
              if (mounted) await BtInfobar.error(context, '只能删除BMF播放源');
              return;
            }
            var confirm = await showConfirmDialog(
              context,
              title: '移除播放',
              content: '是否移除该播放任务？',
            );
            if (!confirm) return;
            await hive.deleteBMF(widget.subject, media.extras?['episode']);
            await freshList();
            if (mounted) await BtInfobar.success(context, '移除成功');
          },
          onLongPress: () async {
            if (hive.curSource != 'BMF') {
              if (mounted) await BtInfobar.error(context, '只能删除BMF播放源');
              return;
            }
            await hive.deleteBMF(widget.subject, media.extras?['episode']);
            await freshList();
          },
        ),
      ],
    );
  }

  /// 构建播放卡片
  Widget buildCard(int index, Media media) {
    return Card(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            media.extras?['episode'].toString() ?? media.uri,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(media.uri),
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
      width: 120,
      child: ListView.separated(
        itemCount: playList.length,
        itemBuilder: (context, index) => buildCard(index, playList[index]),
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
    super.build(context);
    if (!isPlayable) {
      return const ScaffoldPage(content: Center(child: Text('暂无播放列表')));
    }
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Flexible(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(children: [
                  PlayVideoWidget(),
                  // buildDanmaku(),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            buildList(),
          ],
        ),
      ),
    );
  }
}
