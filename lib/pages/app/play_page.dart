// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// Project imports:
import '../../store/nav_store.dart';
import '../../store/play_store.dart';

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

  /// 播放列表
  List<Media> get list => ref.watch(playStoreProvider).list;

  /// 保持状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await init();
    });
  }

  /// dispose
  @override
  void dispose() {
    Future.microtask(() async {
      await player.dispose();
    });
    super.dispose();
  }

  /// init
  Future<void> init() async {
    var playlist = Playlist(list, index: list.length - 1);
    await player.open(playlist);
  }

  /// 构建顶部栏
  Widget buildHeader() {
    return PageHeader(
      leading: IconButton(
        icon: const Icon(FluentIcons.back),
        onPressed: () {
          ref.read(navStoreProvider).removeNavItem('内置播放');
        },
      ),
      title: const Text('内置播放'),
    );
  }

  /// 构建播放列表
  Widget buildItemAct(Media item, int index) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(FluentIcons.play),
          onPressed: () async {
            await player.jump(index);
          },
        ),
        IconButton(
          icon: const Icon(FluentIcons.delete),
          onPressed: () async {
            ref.read(playStoreProvider.notifier).removeTask(item);
            await player.remove(index);
          },
        ),
      ],
    );
  }

  /// 构建播放列表
  Widget buildList() {
    return SizedBox(
      width: 200,
      height: MediaQuery.of(context).size.height,
      child: Card(
        child: ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            var item = list[index];
            var name = Uri.parse(item.uri).pathSegments.last;
            return ListTile(
              title: Tooltip(
                message: name,
                child: Text(
                  name,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              trailing: buildItemAct(item, index),
            );
          },
        ),
      ),
    );
  }

  /// 构建
  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (list.isEmpty) {
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
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Video(controller: controller)),
            const SizedBox(width: 8),
            buildList(),
          ],
        ),
      ),
    );
  }
}
