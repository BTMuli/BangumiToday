// Flutter imports:
import 'package:flutter/foundation.dart';

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

  /// 当前播放的source
  late String curSource = hive.curSource;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    hive.addListener(listenHive);
  }

  @override
  void dispose() {
    hive.removeListener(listenHive);
    super.dispose();
  }

  /// 监听hive，判断curModel的subjectId是否改变
  void listenHive() {
    var curModel = hive.curModel;
    var subject = curModel?.subjectId;
    if (subject != null && curSubject != subject) {
      curSubject = subject;
      setState(() {});
    }
    if (curSource != hive.curSource) {
      curSource = hive.curSource;
      setState(() {});
    }
  }

  /// 构建subjectBox
  Widget buildSubjectBox() {
    var list = hive.getPlayable().map((e) => e.subjectId).toList();
    return ComboBox<int>(
      value: curSubject,
      items: List.generate(
        list.length,
        (index) => ComboBoxItem<int>(
          value: list[index],
          child: Tooltip(
            message: hive.getSubjectName(list[index]),
            child: Text('${list[index]}'),
          ),
        ),
      ),
      onChanged: (value) async {
        if (value == null) return;
        if (value == curSubject) {
          if (mounted) await BtInfobar.warn(context, '已经选中该条目！');
          return;
        }
        await ref.read(playControllerProvider.notifier).switchSubject(value);
        setState(() {});
      },
    );
  }

  /// 构建sourceBox
  Widget buildSourceBox() {
    var model = hive.curModel;
    if (model == null) return const SizedBox();
    var sources = model.sources;
    return ComboBox<String>(
      value: curSource,
      items: List.generate(
        sources.length,
        (index) => ComboBoxItem<String>(
          value: sources[index].source,
          child: Tooltip(
            message: sources[index].source,
            child: Text(sources[index].source),
          ),
        ),
      ),
      onChanged: (value) async {
        if (value == null) return;
        if (value == hive.curSource) {
          if (mounted) await BtInfobar.warn(context, '已经选中该资源！');
          return;
        }
        ref.read(playControllerProvider.notifier).switchSource(value);
        curSource = value;
        setState(() {});
      },
    );
  }

  /// 构建头部
  Widget buildHeader() {
    return Row(children: [
      const SizedBox(width: 8),
      Text('当前播放：${hive.curModel?.subjectName}'),
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
      if (kDebugMode) ...[const SizedBox(width: 8), buildSourceBox()],
      const Spacer(),
      const SizedBox(width: 8),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(
      header: buildHeader(),
      padding: EdgeInsets.zero,
      content: PlayVodPage(subject: curSubject!),
    );
  }
}
