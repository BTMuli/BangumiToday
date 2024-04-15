import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../models/bangumi/bangumi_enum.dart';
import '../../../models/bangumi/bangumi_enum_extension.dart';
import '../../../models/bangumi/bangumi_model.dart';
import '../../../request/bangumi/bangumi_api.dart';
import '../../app/app_dialog_resp.dart';
import '../../app/app_infobar.dart';

/// Subject的单个Episode组件
class BsdEpisode extends StatefulWidget {
  /// 章节信息
  final BangumiEpisode episode;

  /// 用户章节信息
  final BangumiUserEpisodeCollection? user;

  /// 构造函数
  const BsdEpisode(this.episode, {this.user, super.key});

  @override
  State<BsdEpisode> createState() => _BsdEpisodeState();
}

/// State
class _BsdEpisodeState extends State<BsdEpisode> {
  /// 章节信息
  BangumiEpisode get episode => widget.episode;

  /// 用户章节信息
  late BangumiUserEpisodeCollection? userEpisode = widget.user;

  /// 客户端
  final BtrBangumiApi api = BtrBangumiApi();

  /// flyout controller
  final FlyoutController controller = FlyoutController();

  /// 章节text
  late String text = getText();

  /// 获取背景颜色
  Color getBgColor() {
    if (userEpisode == null) {
      return Colors.transparent;
    }
    var base = FluentTheme.of(context).accentColor;
    var userType = userEpisode!.type;
    switch (userType) {
      case BangumiEpisodeCollectionType.none:
        return Colors.transparent;
      case BangumiEpisodeCollectionType.wish:
        return base.lighter;
      case BangumiEpisodeCollectionType.done:
        return base;
      case BangumiEpisodeCollectionType.dropped:
        return base.darker;
    }
  }

  /// 获取文字
  String getText() {
    var text = episode.sort.toStringAsFixed(0);
    if (episode.sort.toInt() != episode.sort) {
      text = episode.sort.toStringAsFixed(1);
    }
    return text;
  }

  /// 获取Tooltip
  String getTooltip() {
    if (episode.nameCn.isEmpty) {
      return episode.name;
    }
    return episode.nameCn;
  }

  /// 构建Flyout
  void buildFlyout() {
    controller.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      dismissWithEsc: true,
      builder: buildFlyoutCommon,
    );
  }

  /// 刷新用户章节信息
  Future<void> freshUserEpisodes() async {
    var resp = await api.getCollectionEpisode(episode.id);
    if (resp.code != 0) {
      showRespErr(resp, context, title: '获取 $text 章节信息失败');
      return;
    }
    userEpisode = resp.data;
    setState(() {});
  }

  /// 更新章节收藏状态
  Future<void> updateType(BangumiEpisodeCollectionType type) async {
    var resp = await api.updateCollectionEpisode(
      type: type,
      episode: episode.id,
    );
    if (resp.code != 0) {
      showRespErr(resp, context, title: '更新章节 $text 状态失败');
      return;
    }
    BtInfobar.success(context, '成功更新章节 $text 状态为 ${type.label}');
    await freshUserEpisodes();
  }

  /// 获取当前状态对应的图标
  IconData getIcon(BangumiEpisodeCollectionType? type) {
    if (type == null) {
      return FluentIcons.error;
    }
    switch (type) {
      case BangumiEpisodeCollectionType.none:
        return FluentIcons.cocktails;
      case BangumiEpisodeCollectionType.wish:
        return FluentIcons.add_bookmark;
      case BangumiEpisodeCollectionType.done:
        return FluentIcons.archive;
      case BangumiEpisodeCollectionType.dropped:
        return FluentIcons.calories;
    }
  }

  /// 构建Flyout-修改章节收藏状态
  MenuFlyoutItem buildEpStat(
    BuildContext context,
    BangumiEpisodeCollectionType type,
  ) {
    final icon = getIcon(type);
    var selected = false;
    if (userEpisode == null && type == BangumiEpisodeCollectionType.none) {
      selected = true;
    } else if (userEpisode?.type == type) {
      selected = true;
    }
    return MenuFlyoutItem(
      leading: Icon(icon, color: FluentTheme.of(context).accentColor),
      text: Text(type.label),
      onPressed: () async {
        if (userEpisode == null) {
          await BtInfobar.error(context, '未找到章节 $text 的章节信息');
        } else if (userEpisode!.type != type) {
          await updateType(type);
        } else {
          await BtInfobar.warn(context, '章节 $text 状态已经是 ${type.label}');
        }
      },
      selected: selected,
      trailing: selected
          ? Icon(
              FluentIcons.check_mark,
              color: FluentTheme.of(context).accentColor,
            )
          : null,
    );
  }

  /// 构建章节详情
  Widget buildEpisodeDetail(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('标题: ${episode.name}'),
        Text('标题(中文): ${episode.nameCn}'),
        Text('章节ID: ${episode.id}'),
        Text('类型: ${episode.type.label}'),
        Text('放送时间: ${episode.airDate}'),
        Text('时长: ${episode.duration}'),
        Text('收藏状态: ${userEpisode?.type.label ?? '未知'}'),
        Text('简介：'),
        SizedBox(height: 8.h),
        if (episode.desc.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 200.h),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(episode.desc),
              ),
            ),
          ),
        if (episode.desc.isEmpty)
          Row(
            children: [
              Icon(
                FluentIcons.error,
                color: FluentTheme.of(context).accentColor,
              ),
              SizedBox(width: 8.w),
              Text('暂无简介'),
            ],
          ),
      ],
    );
  }

  /// 构建Flyout-通用
  Widget buildFlyoutCommon(BuildContext context) {
    var color = FluentTheme.of(context).accentColor;
    return MenuFlyout(
      items: [
        buildEpStat(context, BangumiEpisodeCollectionType.none),
        buildEpStat(context, BangumiEpisodeCollectionType.wish),
        buildEpStat(context, BangumiEpisodeCollectionType.done),
        buildEpStat(context, BangumiEpisodeCollectionType.dropped),
        MenuFlyoutItem(
          leading: Icon(FluentIcons.info, color: color),
          text: Text('查看详情'),
          onPressed: () async {
            await showDialog(
              barrierDismissible: true,
              context: context,
              builder: (_) => ContentDialog(
                title: Text('章节详情'),
                content: buildEpisodeDetail(context),
                actions: [
                  IconButton(
                    onPressed: () async {
                      await launchUrlString('https://bgm.tv/ep/${episode.id}');
                      Navigator.of(context).pop();
                    },
                    icon: Icon(FluentIcons.edge_logo, color: color),
                  ),
                  Button(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('关闭'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// build
  @override
  Widget build(BuildContext context) {
    final bgColor = getBgColor();
    final tooltip = getTooltip();
    return FlyoutTarget(
      controller: controller,
      child: Button(
        style: ButtonStyle(
          backgroundColor: ButtonState.all(bgColor),
        ),
        child: Tooltip(
          message: tooltip,
          child: Text('$text'),
        ),
        onPressed: buildFlyout,
      ),
    );
  }
}
