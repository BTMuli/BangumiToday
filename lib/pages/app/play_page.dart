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

  /// 获取播放列表
  List<Media> get playList => hive.allMedia;

  /// 保持状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.microtask(() async => await refresh());
    hive.addListener(() async => await refresh());
  }

  /// 刷新播放列表
  Future<void> refresh() async {
    var list = hive.allMedia;
    var listGet = player.state.playlist.medias;
    if (listGet == list) {
      var indexGet = player.state.playlist.index;
      if (indexGet != hive.index) {
        var progress = player.state.position.inMilliseconds;
        await hive.updateProgress(progress, file: listGet[indexGet].uri);
        await player.jump(hive.index);
      }
      return;
    }
    BTLogTool.info('refresh list');
    await player.open(Playlist(list, index: hive.index));
    if (hive.current.progress != 0) {
      await player.seek(Duration(milliseconds: hive.current.progress));
    }
  }

  /// dispose
  @override
  void dispose() {
    Future.microtask(() async {
      await player.dispose();
    });
    hive.removeListener(() async => await refresh());
    super.dispose();
  }

  /// 构建顶部栏
  Widget buildHeader() {
    var name = '无';
    if (hive.all.isNotEmpty) {
      name = Uri.parse(hive.current.file).pathSegments.last;
    }
    return PageHeader(
      leading: IconButton(
        icon: const Icon(FluentIcons.back),
        onPressed: () async {
          if (hive.all.isNotEmpty) {
            await player.pause();
            var progress = player.state.position.inMilliseconds;
            await hive.updateProgress(progress);
          }
          ref.read(navStoreProvider).removeNavItem('内置播放');
        },
      ),
      title: const Text('内置播放'),
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
            await player.pause();
            var progress = player.state.position.inMilliseconds;
            await hive.updateProgress(progress);
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
            if (item == hive.current) {
              await BtInfobar.warn(context, '所选视频已经在播放中！');
              return;
            }
            await player.pause();
            var progress = player.state.position.inMilliseconds;
            await hive.updateProgress(progress);
            hive.jump(item);
            setState(() {});
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
