// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../components/app/app_infobar.dart';
import '../../components/base/base_theme_icon.dart';
import '../../store/play_store.dart';
import '../../tools/file_tool.dart';
import 'play_controller.dart';
import 'play_vod_page.dart';

/// 播放列表页面
class PlayListPage extends ConsumerStatefulWidget {
  /// 构造
  const PlayListPage({super.key});

  @override
  ConsumerState<PlayListPage> createState() => _PlayListPageState();
}

/// 状态
class _PlayListPageState extends ConsumerState<PlayListPage>
    with AutomaticKeepAliveClientMixin {
  /// hive
  final PlayHive hive = PlayHive();

  /// fileTool
  final BTFileTool fileTool = BTFileTool();

  /// 当前播放的subject
  late int? curSubject = hive.curModel?.subjectId;

  /// 是否有播放列表
  late bool isPlayable = false;

  @override
  bool get wantKeepAlive => true;

  /// 构建future
  Future<void> buildFuture() async {
    var curModel = hive.curModel;
    var subject = curModel?.subjectId;
    isPlayable = curModel != null && curModel.items.isNotEmpty;
    if (subject != null && curSubject != subject) {
      curSubject = subject;
      await hive.open(subject: subject);
    }
  }

  /// 构建subjectBox
  Widget buildSubjectBox() {
    var list = hive.values.map((e) => e.subjectId).toList();
    return ComboBox<int>(
      value: curSubject,
      items: List.generate(
        list.length,
        (index) => ComboBoxItem<int>(
          value: list[index],
          child: Text('${list[index]}'),
        ),
      ),
      onChanged: (value) async {
        if (value == null) return;
        if (value == curSubject) {
          if (mounted) await BtInfobar.warn(context, '已经选中该条目！');
          return;
        }
        await ref.read(playControllerProvider.notifier).saveProgress();
        hive.switchSubject(value);
        setState(() {
          curSubject = value;
        });
      },
    );
  }

  /// 构建头部
  Widget buildHeader() {
    return Row(children: [
      const SizedBox(width: 8),
      const Text('当前播放：'),
      const SizedBox(width: 8),
      buildSubjectBox(),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<void>(
      future: buildFuture(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return ScaffoldPage(
            header: buildHeader(),
            padding: EdgeInsets.zero,
            content: isPlayable
                ? PlayVodPage(subject: curSubject!)
                : const Center(child: Text('无播放资源')),
          );
        }
        return const Center(child: ProgressRing());
      },
    );
  }
}
