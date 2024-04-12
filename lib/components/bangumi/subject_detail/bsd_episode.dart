import 'package:fluent_ui/fluent_ui.dart';
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
      showRespErr(resp, context, title: '获取章节信息失败');
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
      showRespErr(resp, context, title: '更新状态失败');
      return;
    }
    BtInfobar.success(context, '成功更新章节状态为 ${type.label}');
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
    return MenuFlyoutItem(
      leading: Icon(icon, color: FluentTheme.of(context).accentColor),
      text: Text(type.label),
      onPressed: () async {
        if (userEpisode == null) {
          BtInfobar.error(context, '未找到章节信息');
        } else if (userEpisode!.type != type) {
          await updateType(type);
        } else {
          BtInfobar.warn(context, '章节状态已经是 ${type.label}');
        }
      },
      selected: userEpisode?.type == type,
      trailing: userEpisode?.type == type
          ? Icon(
              FluentIcons.check_mark,
              color: FluentTheme.of(context).accentColor,
            )
          : null,
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
          leading: Icon(FluentIcons.edge_logo, color: color),
          text: Text('查看详情'),
          onPressed: () async {
            await launchUrlString('https://bgm.tv/ep/${episode.id}');
          },
        ),
      ],
    );
  }

  /// build
  @override
  Widget build(BuildContext context) {
    final bgColor = getBgColor();
    final text = getText();
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
