// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../components/app/app_dialog.dart';
import '../../components/app/app_infobar.dart';
import '../../components/base/base_theme_icon.dart';
import '../../database/bangumi/bangumi_collection.dart';
import '../../models/hive/play_model.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../store/play_store.dart';

/// 播放历史记录
class PlayHistoryPage extends StatefulWidget {
  /// 构造
  const PlayHistoryPage({super.key});

  @override
  State<PlayHistoryPage> createState() => _PlayHistoryPageState();
}

/// 状态
class _PlayHistoryPageState extends State<PlayHistoryPage> {
  /// Hive
  final PlayHive hive = PlayHive();

  /// api
  final BtrBangumiApi api = BtrBangumiApi();

  /// sqlite
  final BtsBangumiCollection sqlite = BtsBangumiCollection();

  /// 进度转换
  String progressToString(int milliseconds) {
    var progress = milliseconds ~/ 1000;
    var hours = progress ~/ 3600;
    var minutes = (progress % 3600) ~/ 60;
    var seconds = (progress % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      var minStr = minutes.toString().padLeft(2, '0');
      return '$hours:$minStr:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  /// 显示源对话框
  void showSourceDialog(
    BuildContext context,
    PlayHiveSource source,
    int subjectId,
  ) {
    source.items.sort((a, b) => a.index.compareTo(b.index));
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return ContentDialog(
          title: Text('播放源：${source.source}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var item in source.items)
                Row(children: [
                  Expanded(
                    child: Text('第${item.index}集：${item.link}'),
                  )
                ]),
            ],
          ),
          actions: [
            Button(
              onPressed: () async {
                if (source.source == "BMF") {
                  if (context.mounted) {
                    await BtInfobar.warn(context, 'BMF资源不支持删除');
                  }
                  return;
                }
                var confirm = await showConfirmDialog(
                  context,
                  title: '删除播放源',
                  content: '是否删除该播放源？',
                );
                if (!confirm) return;
                await hive.deleteSource(subjectId, source: source.source);
                if (context.mounted) Navigator.of(context).pop();
                setState(() {});
              },
              child: const Text('删除'),
            ),
            Button(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  /// 获取条目名称
  Future<String> getSubjectName(int subjectId) async {
    var check1 = await sqlite.isCollected(subjectId);
    if (!check1) {
      var res = await api.getSubjectDetail2(subjectId.toString());
      if (res == null) {
        if (mounted) await BtInfobar.error(context, '获取条目信息失败');
        return '';
      }
      var name = res.nameCn.isEmpty ? res.name : res.nameCn;
      return name;
    }
    var subject = (await sqlite.read(subjectId))?.subject;
    if (subject == null) {
      if (mounted) await BtInfobar.error(context, '获取条目信息失败');
      return '';
    }
    return subject.nameCn.isEmpty ? subject.name : subject.nameCn;
  }

  /// 更新条目标题
  Future<void> updateTitle(PlayHiveModel item, {bool force = false}) async {
    var nameGet = item.subjectName;
    if (nameGet.isEmpty || force) {
      nameGet = await getSubjectName(item.subjectId);
    }
    if (!mounted) return;
    var input = await showInputDialog(
      context,
      title: '修改条目',
      content: '请输入条目名称',
      value: nameGet,
    );
    if (input == null || input.isEmpty) {
      if (mounted) await BtInfobar.error(context, '请输入有效名称');
      return;
    }
    if (!mounted) return;
    var text = '是否设置条目名称为 $input?';
    if (item.subjectName.isNotEmpty) {
      text = '是否修改条目名称\n${item.subjectName}→$input?';
    }
    var confirm = await showConfirmDialog(
      context,
      title: '修改条目名称',
      content: text,
    );
    if (!confirm) return;
    await hive.updateTitle(item.subjectId, input);
    setState(() {});
  }

  /// buildProgress
  Widget buildProgress(PlayHiveModel item) {
    item.items.sort((a, b) => a.episode.compareTo(b.episode));
    var list = item.items;
    return Wrap(
      spacing: 8,
      children: [
        for (var i = 0; i < list.length; i++)
          Tooltip(
            message: '进度：${progressToString(list[i].progress)}',
            child: Text(
              '第${list[i].episode}集'
              '(${progressToString(list[i].progress)})',
            ),
          )
      ],
    );
  }

  /// buildSource
  Widget buildSource(PlayHiveModel item) {
    return Wrap(
      spacing: 8,
      children: [
        for (var i = 0; i < item.sources.length; i++)
          FilledButton(
            child: Text(item.sources[i].source),
            onPressed: () {
              showSourceDialog(context, item.sources[i], item.subjectId);
            },
          ),
      ],
    );
  }

  /// buildDelHistoryButton
  Widget buildDelHistoryButton(PlayHiveModel item) {
    return IconButton(
      icon: const BaseThemeIcon(FluentIcons.history),
      onPressed: () async {
        if (item.items.isEmpty) {
          if (mounted) await BtInfobar.warn(context, '该条目没有播放历史');
          return;
        }
        var confirm = await showConfirmDialog(
          context,
          title: '移除播放历史',
          content: '是否移除条目 ${item.subjectId} 的播放历史？',
        );
        if (!confirm) return;
        await hive.deleteProgress(item.subjectId);
        setState(() {});
      },
    );
  }

  /// buildEditButton
  Widget buildEditButton(PlayHiveModel item) {
    return IconButton(
      icon: const BaseThemeIcon(FluentIcons.edit),
      onPressed: () async => await updateTitle(item),
      onLongPress: () async => await updateTitle(item, force: true),
    );
  }

  /// buildHistoryItem
  Widget buildHistoryItem(PlayHiveModel item) {
    return Expander(
      leading: const Icon(FluentIcons.info),
      header: Text('${item.subjectName}(${item.subjectId})'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [buildDelHistoryButton(item), buildEditButton(item)],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.items.isEmpty)
            const Text('播放历史：无')
          else ...[
            const Text('播放历史：'),
            const SizedBox(height: 8),
            buildProgress(item)
          ],
          const SizedBox(height: 8),
          if (item.sources.isEmpty)
            const Text('播放源：无')
          else ...[
            const Text('播放源：'),
            const SizedBox(height: 8),
            buildSource(item)
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (hive.values.isEmpty) {
      return const ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Center(
          child: Text('暂无播放历史'),
        ),
      );
    }
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: hive.values.length,
        itemBuilder: (context, index) => buildHistoryItem(hive.values[index]),
        separatorBuilder: (context, index) => const SizedBox(height: 8),
      ),
    );
  }
}
