// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../components/base/base_theme_icon.dart';
import '../../store/play_store.dart';
import '../../tools/file_tool.dart';
import 'play_vod_page.dart';

/// 播放列表页面
class PlayListPage extends StatefulWidget {
  /// 构造
  const PlayListPage({super.key});

  @override
  State<PlayListPage> createState() => _PlayListPageState();
}

/// 状态
class _PlayListPageState extends State<PlayListPage>
    with AutomaticKeepAliveClientMixin {
  /// hive
  final PlayHive hive = PlayHive();

  /// fileTool
  final BTFileTool fileTool = BTFileTool();

  /// 当前播放的subject
  int? get curSubject => hive.curModel?.subjectId;

  @override
  bool get wantKeepAlive => true;

  /// 构建头部
  Widget buildHeader() {
    return Row(children: [
      const SizedBox(width: 8),
      if (curSubject != null)
        Text('当前播放：$curSubject')
      else
        const Text('当前播放：无'),
      const SizedBox(width: 8),
      Tooltip(
        message: '打开截图目录',
        child: IconButton(
          icon: const BaseThemeIcon(FluentIcons.camera),
          onPressed: () async => await fileTool.openScreenshotDir(),
        ),
      ),
      const SizedBox(width: 4),
      Tooltip(
        message: '刷新',
        child: IconButton(
          icon: const BaseThemeIcon(FluentIcons.refresh),
          onPressed: () => setState(() {}),
        ),
      ),
      const Spacer(),
      const SizedBox(width: 8),
    ]);
  }

  /// 构建内容
  Widget buildContent() {
    if (hive.getPlayList().isEmpty) {
      return const Center(child: Text('无播放记录'));
    }
    return PlayVodPage(subject: hive.curModel!.subjectId);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(
      header: buildHeader(),
      padding: EdgeInsets.zero,
      content: buildContent(),
    );
  }
}
