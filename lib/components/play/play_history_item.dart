// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../database/bangumi/bangumi_collection.dart';
import '../../models/hive/play_model.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../store/play_store.dart';
import '../app/app_dialog.dart';
import '../app/app_infobar.dart';
import '../base/base_theme_icon.dart';

/// 播放历史记录-单项
class PlayHistoryItemWidget extends ConsumerStatefulWidget {
  /// 数据
  final PlayHiveModel item;

  /// hive
  final PlayHive hive;

  /// 构造函数
  const PlayHistoryItemWidget(this.item, this.hive, {super.key});

  @override
  ConsumerState<PlayHistoryItemWidget> createState() =>
      _PlayHistoryItemWidgetState();
}

class _PlayHistoryItemWidgetState extends ConsumerState<PlayHistoryItemWidget> {
  /// 数据
  PlayHiveModel get item => widget.item;

  /// hive
  PlayHive get hive => widget.hive;

  /// api
  final BtrBangumiApi api = BtrBangumiApi();

  /// sqlite
  final BtsBangumiCollection sqlite = BtsBangumiCollection();

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

  /// 进度转换
  String progressToTime(int milliseconds) {
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

  /// 删除记录
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

  /// 编辑标题
  /// buildEditButton
  Widget buildEditButton(PlayHiveModel item) {
    return IconButton(
      icon: const BaseThemeIcon(FluentIcons.edit),
      onPressed: () async => await updateTitle(item),
      onLongPress: () async => await updateTitle(item, force: true),
    );
  }

  /// buildDelBMFButton
  Widget buildDelBMFButton(PlayHiveModel item) {
    return IconButton(
      icon: const BaseThemeIcon(FluentIcons.delete),
      onPressed: () async {
        var confirm = await showConfirmDialog(
          context,
          title: '删除播放记录',
          content: '是否删除条目 ${item.subjectId} 的播放记录？',
        );
        if (!confirm) return;
        await hive.deleteHistory(item.subjectId);
        setState(() {});
        if (mounted) await BtInfobar.success(context, '删除成功');
      },
    );
  }

  /// 构建头部右侧
  Widget buildHeaderTrailing() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildDelHistoryButton(item),
        buildEditButton(item),
        buildDelBMFButton(item),
      ],
    );
  }

  /// 构建条目
  Widget buildEpisodeItem(PlayHiveItem itemEp) {
    return ListTile(
      title: Text('第${itemEp.episode}话'),
      subtitle: Text(progressToTime(itemEp.progress)),
      trailing: IconButton(
        icon: const Icon(FluentIcons.delete),
        onPressed: () async {
          var confirm = await showConfirmDialog(
            context,
            title: '删除播放记录',
            content: '是否删除条目 ${itemEp.episode} 的播放记录？',
          );
          if (!confirm) return;
          await hive.deleteProgress(item.subjectId, episode: itemEp.episode);
          setState(() {});
          if (mounted) await BtInfobar.success(context, '删除成功');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expander(
      leading: const Icon(FluentIcons.info),
      header: Text('${item.subjectName}(${item.subjectId})'),
      trailing: buildHeaderTrailing(),
      content: item.items.isEmpty
          ? const Center(child: Text('没有播放历史'))
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 300.h),
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                scrollDirection: Axis.vertical,
                child: Column(
                  children: item.items.map(buildEpisodeItem).toList(),
                ),
              ),
            ),
    );
  }
}
