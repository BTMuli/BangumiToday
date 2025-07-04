// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:jiffy/jiffy.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../../database/bangumi/bangumi_collection.dart';
import '../../../models/bangumi/bangumi_enum.dart';
import '../../../models/bangumi/bangumi_model.dart';
import '../../../pages/bangumi/bangumi_detail.dart';
import '../../../request/bangumi/bangumi_api.dart';
import '../../../ui/bt_dialog.dart';
import '../../../ui/bt_infobar.dart';
import '../../../utils/bangumi_utils.dart';

/// SubjectDetail的收藏模块，负责整个Subject的收藏信息
class BsdUserCollection extends StatefulWidget {
  /// subjectInfo
  final BangumiSubject subject;

  /// user
  final BangumiUser user;

  /// provider
  final BangumiDetailProvider provider;

  /// 构造函数
  const BsdUserCollection(this.subject, this.user, this.provider, {super.key});

  @override
  State<BsdUserCollection> createState() => _BsdUserCollectionState();
}

/// State
class _BsdUserCollectionState extends State<BsdUserCollection>
    with AutomaticKeepAliveClientMixin {
  /// subjectInfo
  BangumiSubject get subject => widget.subject;

  /// user
  BangumiUser get user => widget.user;

  /// 客户端
  final BtrBangumiApi api = BtrBangumiApi();

  /// 用户收藏数据库
  final BtsBangumiCollection sqlite = BtsBangumiCollection();

  /// flyout controller
  final FlyoutController controller = FlyoutController();

  /// 用户收藏信息
  BangumiUserSubjectCollection? userCollection;

  /// 用户收藏状态
  late BangumiCollectionType collectionType = BangumiCollectionType.unknown;

  /// 用户评分
  late int rating = 0;

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
    controller.dispose();
    super.dispose();
  }

  /// 初始化
  Future<void> init() async {
    var resp = await api.getCollectionSubject(user.id.toString(), subject.id);
    if (resp.code == 404) {
      collectionType = BangumiCollectionType.unknown;
      await sqlite.delete(subject.id);
      setState(() {});
    } else if (resp.code != 0 || resp.data == null) {
      if (mounted) await showRespErr(resp, context);
    } else {
      userCollection = resp.data;
      await sqlite.write(userCollection!);
      collectionType = userCollection!.type;
      rating = userCollection?.rate ?? 0;
      setState(() {});
    }
  }

  /// 更新条目收藏状态
  Future<void> updateType(BangumiCollectionType type) async {
    var resp = await api.updateCollectionSubject(subject.id, type: type);
    if (resp.code != 0) {
      if (mounted) await showRespErr(resp, context);
    } else {
      collectionType = type;
      if (mounted) {
        await BtInfobar.success(
          context,
          '条目 ${subject.id} 状态更新为 ${type.label}',
        );
      }
      setState(() {});
      await init();
    }
  }

  /// 获取背景颜色
  Color getBgColor() {
    if (userCollection == null) return Colors.transparent;
    var base = FluentTheme.of(context).accentColor;
    var userType = userCollection!.type;
    return userType.color(base);
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

  /// 构建Flyout-修改章节收藏状态
  MenuFlyoutItemBase buildSubjStat(
    BuildContext context,
    BangumiCollectionType type,
  ) {
    var trailing = collectionType == type
        ? Icon(
            FluentIcons.check_mark,
            color: FluentTheme.of(context).accentColor,
          )
        : null;
    return MenuFlyoutItem(
      leading: Icon(type.icon, color: FluentTheme.of(context).accentColor),
      text: Text(type.label),
      selected: collectionType == type,
      onPressed: () async {
        if (collectionType == type) {
          await BtInfobar.warn(context, '条目 ${subject.id} 状态与当前状态相同');
          return;
        }
        await updateType(type);
      },
      trailing: trailing,
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
      date = Jiffy.parse(
        userCollection!.updatedAt,
        pattern: 'yyyy-MM-ddTHH:mm:ssZ',
      ).format(pattern: 'yyyy-MM-dd HH:mm:ss');
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

  /// 删除收藏
  /// todo 目前官方API不支持删除收藏，暂时不实现
  MenuFlyoutItem buildFlyoutDelete(BuildContext context) {
    return MenuFlyoutItem(
      leading: const Icon(FluentIcons.delete),
      text: const Text('删除收藏'),
      onPressed: () async {
        await BtInfobar.error(context, '暂不支持删除收藏');
      },
    );
  }

  MenuFlyoutItem buildFlyoutItemDetail(BuildContext context) {
    var color = FluentTheme.of(context).accentColor;
    return MenuFlyoutItem(
      leading: const Icon(FluentIcons.info),
      text: const Text('查看详情'),
      onPressed: () async {
        if (userCollection == null) {
          await BtInfobar.error(context, '未获取到收藏信息');
          return;
        }
        await showDialog(
          barrierDismissible: true,
          context: context,
          builder: (_) => ContentDialog(
            title: const Text('收藏详情'),
            content: buildCollectionDetail(context),
            actions: [
              IconButton(
                onPressed: () async {
                  await launchUrlString('https://bgm.tv/subject/${subject.id}');
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: Icon(FluentIcons.edge_logo, color: color),
              ),
              Button(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建Flyout-通用
  Widget buildFlyoutCommon(BuildContext context) {
    return MenuFlyout(
      items: [
        buildSubjStat(context, userCollection!.type),
        MenuFlyoutSubItem(
          leading: Icon(
            FluentIcons.edit,
            color: FluentTheme.of(context).accentColor,
          ),
          text: const Text('修改收藏状态'),
          items: (context) => [
            buildSubjStat(context, BangumiCollectionType.wish),
            buildSubjStat(context, BangumiCollectionType.collect),
            buildSubjStat(context, BangumiCollectionType.doing),
            buildSubjStat(context, BangumiCollectionType.onHold),
            buildSubjStat(context, BangumiCollectionType.dropped),
          ],
        ),
        buildFlyoutDelete(context),
        buildFlyoutItemDetail(context),
      ],
    );
  }

  /// 添加到收藏列表
  Future<void> addToCollection(BuildContext context) async {
    var resp = await api.addCollectionSubject(subject.id);
    if (!context.mounted) return;
    if (resp.code != 0) {
      await showRespErr(resp, context, title: '添加收藏失败');
      return;
    }
    await BtInfobar.success(context, '条目 ${subject.id} 添加到收藏列表成功');
    widget.provider.set(true);
    await init();
  }

  /// 未收藏
  Widget buildUnCollection(BuildContext context) {
    return Row(
      children: [
        FlyoutTarget(
          controller: controller,
          child: IconButton(
            icon: Icon(
              FluentIcons.warning,
              size: 20,
              color: FluentTheme.of(context).accentColor,
            ),
            onLongPress: () async => addToCollection(context),
            onPressed: () {
              controller.showFlyout(
                barrierDismissible: true,
                dismissOnPointerMoveAway: false,
                dismissWithEsc: true,
                builder: (context) => MenuFlyout(
                  items: [
                    buildFlyoutItemDetail(context),
                    MenuFlyoutItem(
                      leading: Icon(
                        FluentIcons.add_bookmark,
                        color: FluentTheme.of(context).accentColor,
                      ),
                      text: const Text('添加到收藏列表'),
                      onPressed: () async => await addToCollection(context),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SizedBox(width: 8),
        Text(
          '未收藏',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// buildRatingBar
  Widget buildRateBox() {
    return ComboBox<int>(
      placeholder: const Text('0  [未评分]'),
      value: rating,
      items: List.generate(
        10,
        (index) => ComboBoxItem<int>(
          value: index + 1,
          child: index == 9
              ? Text('10 [${getBangumiRateLabel(index + 1)}]')
              : Text('${index + 1}  [${getBangumiRateLabel(index + 1)}]'),
        ),
      ),
      onChanged: (val) async {
        if (val == rating) {
          await BtInfobar.warn(context, '条目 ${subject.id} 评分与当前评分相同');
          return;
        }
        var confirm = await showConfirm(
          context,
          title: '确认评分',
          content: '确认将条目 ${subject.id} 评分更新为 $val 分吗？',
        );
        if (!confirm) return;
        var resp = await api.updateCollectionSubject(
          subject.id,
          rate: val,
        );
        if (resp.code != 0 || resp.data == null) {
          if (mounted) await showRespErr(resp, context);
        } else {
          if (mounted) {
            await BtInfobar.success(
              context,
              '条目 ${subject.id} 评分更新为 $val 分',
            );
          }
          setState(() {});
          await init();
        }
      },
    );
  }

  /// buildCollection
  Widget buildCollection() {
    var color = getBgColor();
    return Row(
      children: [
        FlyoutTarget(
          controller: controller,
          child: Button(
            style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(color)),
            onPressed: buildFlyout,
            child: Row(
              children: [
                Icon(collectionType.icon, size: 20),
                SizedBox(width: 8),
                Text(collectionType.label),
              ],
            ),
          ),
        ),
        SizedBox(width: 8),
        buildRateBox(),
      ],
    );
  }

  /// 构建函数
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return collectionType == BangumiCollectionType.unknown
        ? buildUnCollection(context)
        : buildCollection();
  }
}
