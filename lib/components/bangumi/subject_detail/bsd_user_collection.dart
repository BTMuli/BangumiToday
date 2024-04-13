import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../models/bangumi/bangumi_enum.dart';
import '../../../models/bangumi/bangumi_enum_extension.dart';
import '../../../models/bangumi/bangumi_model.dart';
import '../../../request/bangumi/bangumi_api.dart';
import '../../../utils/tool_func.dart';
import '../../app/app_dialog.dart';
import '../../app/app_dialog_resp.dart';
import '../../app/app_infobar.dart';

/// SubjectDetail的收藏模块，负责整个Subject的收藏信息
class BsdUserCollection extends StatefulWidget {
  /// subjectInfo
  final BangumiSubject subject;

  /// user
  final BangumiUser? user;

  /// 构造函数
  const BsdUserCollection(this.subject, {super.key, this.user});

  @override
  State<BsdUserCollection> createState() => _BsdUserCollectionState();
}

/// State
class _BsdUserCollectionState extends State<BsdUserCollection> {
  /// subjectInfo
  BangumiSubject get subject => widget.subject;

  /// user
  BangumiUser? get user => widget.user;

  /// 客户端
  final BtrBangumiApi api = BtrBangumiApi();

  /// flyout controller
  final FlyoutController controller = FlyoutController();

  /// 用户收藏信息
  BangumiUserSubjectCollection? userCollection;

  /// 用户收藏状态
  late BangumiCollectionType collectionType = BangumiCollectionType.unknown;

  /// 用户评分
  late int rating = 0;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await init();
    });
  }

  /// 初始化
  Future<void> init() async {
    if (user == null) return;
    var resp = await api.getCollectionSubject(
      user!.id.toString(),
      subject.id,
    );
    if (resp.code == 404) {
      collectionType = BangumiCollectionType.unknown;
      setState(() {});
    } else if (resp.code != 0 || resp.data == null) {
      await showRespErr(resp, context);
    } else {
      userCollection = resp.data;
      collectionType = userCollection!.type;
      rating = userCollection?.rate ?? 0;
      setState(() {});
    }
  }

  /// 更新条目收藏状态
  Future<void> updateType(BangumiCollectionType type) async {
    var resp = await api.updateCollectionSubject(subject.id, type: type);
    if (resp.code != 0) {
      await showRespErr(resp, context);
    } else {
      collectionType = type;
      await BtInfobar.success(context, '条目 ${subject.id} 状态更新为 ${type.label}');
      setState(() {});
      await init();
    }
  }

  /// 获取背景颜色
  Color getBgColor() {
    if (userCollection == null) {
      return Colors.transparent;
    }
    var base = FluentTheme.of(context).accentColor;
    var userType = userCollection!.type;
    switch (userType) {
      case BangumiCollectionType.unknown:
        return Colors.transparent;
      case BangumiCollectionType.wish:
        return base.lighter;
      case BangumiCollectionType.collect:
        return base.darker;
      case BangumiCollectionType.doing:
        return base;
      case BangumiCollectionType.onHold:
        return Colors.transparent;
      case BangumiCollectionType.dropped:
        return base.darkest;
    }
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

  /// 获取当前状态对应的图标
  IconData getIcon(BangumiCollectionType type) {
    switch (type) {
      case BangumiCollectionType.wish:
        return FluentIcons.add_bookmark;
      case BangumiCollectionType.collect:
        return FluentIcons.heart;
      case BangumiCollectionType.doing:
        return FluentIcons.play;
      case BangumiCollectionType.onHold:
        return FluentIcons.archive;
      case BangumiCollectionType.dropped:
        return FluentIcons.cancel;
      default:
        return FluentIcons.warning;
    }
  }

  /// 构建Flyout-修改章节收藏状态
  MenuFlyoutItem buildSubjStat(
    BuildContext context,
    BangumiCollectionType type,
  ) {
    final icon = getIcon(type);
    return MenuFlyoutItem(
      leading: Icon(icon, color: FluentTheme.of(context).accentColor),
      text: Text(type.label),
      selected: collectionType == type,
      onPressed: () async {
        if (user == null) {
          await BtInfobar.error(context, '未获取到用户信息，请登录后重试');
          return;
        } else if (collectionType == type) {
          await BtInfobar.warn(context, '条目 ${subject.id} 状态与当前状态相同');
          return;
        } else {
          await updateType(type);
        }
      },
      trailing: collectionType == type
          ? Icon(
              FluentIcons.check_mark,
              color: FluentTheme.of(context).accentColor,
            )
          : null,
    );
  }

  /// 构建收藏详情
  Widget buildCollectionDetail(BuildContext context) {
    assert(userCollection != null);
    var empty = '缺失数据';
    var date = empty;
    var comment = empty;
    var tags = empty;
    if (userCollection?.updatedAt != null &&
        userCollection!.updatedAt.isNotEmpty) {
      date = dateTransLocal(userCollection!.updatedAt);
    }
    if (userCollection?.comment != null &&
        userCollection!.comment!.isNotEmpty) {
      comment = userCollection!.comment!;
    }
    if (userCollection?.tags != null && userCollection!.tags.isNotEmpty) {
      tags = userCollection!.tags.join(', ');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('条目ID: ${subject.id}'),
        Text('条目名称: ${subject.name}'),
        Text('条目名称(中文): ${subject.nameCn}'),
        Text('条目状态: ${collectionType.label}'),
        Text('评分: $rating'),
        Text('评论: $comment'),
        Text('标签: $tags'),
        Text('更新时间: $date'),
      ],
    );
  }

  /// 构建Flyout-通用
  Widget buildFlyoutCommon(BuildContext context) {
    var color = FluentTheme.of(context).accentColor;
    return MenuFlyout(
      items: [
        buildSubjStat(context, BangumiCollectionType.wish),
        buildSubjStat(context, BangumiCollectionType.collect),
        buildSubjStat(context, BangumiCollectionType.doing),
        buildSubjStat(context, BangumiCollectionType.onHold),
        buildSubjStat(context, BangumiCollectionType.dropped),
        MenuFlyoutItem(
          leading: Icon(FluentIcons.info),
          text: Text('查看详情'),
          onPressed: () async {
            if (userCollection == null) {
              await BtInfobar.error(context, '未获取到收藏信息');
              return;
            }
            await showDialog(
              barrierDismissible: true,
              context: context,
              builder: (_) => ContentDialog(
                title: Text('收藏详情'),
                content: buildCollectionDetail(context),
                actions: [
                  IconButton(
                    onPressed: () async {
                      await launchUrlString(
                          'https://bgm.tv/subject/${subject.id}');
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

  /// 未收藏
  Widget buildUnCollection() {
    return Row(
      children: [
        FlyoutTarget(
          controller: controller,
          child: IconButton(
            icon: Icon(
              FluentIcons.warning,
              size: 20.spMax,
              color: FluentTheme.of(context).accentColor,
            ),
            onPressed: () {
              controller.showFlyout(
                barrierDismissible: true,
                dismissOnPointerMoveAway: false,
                dismissWithEsc: true,
                builder: buildFlyoutCommon,
              );
            },
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          '未收藏',
          style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(width: 10.w),
        Button(
          child: Text('刷新状态'),
          onPressed: () async {
            if (user == null) {
              await BtInfobar.error(context, '未获取到用户信息，请登录后重试');
              return;
            } else {
              await init();
              await BtInfobar.success(context, '条目 ${subject.id} 状态刷新成功');
            }
          },
        ),
      ],
    );
  }

  /// buildCollection
  Widget buildCollection() {
    var icon = getIcon(collectionType);
    var color = getBgColor();
    return Row(
      children: [
        FlyoutTarget(
          controller: controller,
          child: Button(
            style: ButtonStyle(backgroundColor: ButtonState.all(color)),
            child: Row(
              children: [
                Icon(icon, size: 20.spMax),
                SizedBox(width: 8.w),
                Text(collectionType.label),
              ],
            ),
            onPressed: buildFlyout,
          ),
        ),
        SizedBox(width: 8.w),
        RatingBar(
          rating: rating.toDouble(),
          amount: 10,
          starSpacing: 2.w,
          onChanged: (val) async {
            if (user == null) {
              await BtInfobar.error(context, '未获取到用户信息，请登录后重试');
              return;
            } else if (val.toInt() + 1 == rating) {
              await BtInfobar.warn(context, '条目 ${subject.id} 评分与当前评分相同');
              return;
            } else {
              var confirm = await showConfirmDialog(
                context,
                title: '确认评分',
                content: '确认将条目 ${subject.id} 评分更新为 ${val.toInt() + 1} 分吗？',
              );
              if (!confirm) return;
              var resp = await api.updateCollectionSubject(
                subject.id,
                rate: val.toInt() + 1,
              );
              if (resp.code != 0 || resp.data == null) {
                await showRespErr(resp, context);
              } else {
                userCollection = resp.data;
                rating = userCollection?.rate ?? val.toInt() + 1;
                await BtInfobar.success(
                  context,
                  '条目 ${subject.id} 评分更新为 $rating 分',
                );
                setState(() {});
                await init();
              }
            }
          },
        ),
        SizedBox(width: 8.w),
        Button(
          child: Text('刷新状态'),
          onPressed: () async {
            if (user == null) {
              await BtInfobar.error(context, '未获取到用户信息，请登录后重试');
              return;
            } else {
              await init();
              await BtInfobar.success(context, '条目 ${subject.id} 状态刷新成功');
            }
          },
        ),
      ],
    );
  }

  /// 构建函数
  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Row(
        children: [
          Icon(
            FluentIcons.warning,
            size: 20.spMax,
            color: FluentTheme.of(context).accentColor,
          ),
          SizedBox(width: 10.w),
          Text(
            '未获取到用户信息，请登录后重试',
            style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }
    if (collectionType == BangumiCollectionType.unknown) {
      return buildUnCollection();
    }
    return buildCollection();
  }
}
