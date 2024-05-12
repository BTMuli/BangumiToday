// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../components/app/app_dialog.dart';
import '../../components/app/app_dialog_resp.dart';
import '../../components/app/app_infobar.dart';
import '../../components/bangumi/subject_detail/bsd_bmf.dart';
import '../../components/bangumi/subject_detail/bsd_overview.dart';
import '../../components/bangumi/subject_detail/bsd_relation.dart';
import '../../components/bangumi/subject_detail/bsd_user_collection.dart';
import '../../components/bangumi/subject_detail/bsd_user_episodes.dart';
import '../../components/danmaku/anime_overlay.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/hive/danmaku_model.dart';
import '../../models/hive/nav_model.dart';
import '../../models/source/request_danmaku.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../request/source/danmaku_api.dart';
import '../../store/bgm_user_hive.dart';
import '../../store/danmaku_hive.dart';
import '../../store/nav_store.dart';
import '../../utils/tool_func.dart';

/// 番剧详情
class BangumiDetail extends ConsumerStatefulWidget {
  /// 番剧 id
  final String id;

  /// 构造函数
  const BangumiDetail({super.key, required this.id});

  @override
  ConsumerState<BangumiDetail> createState() => _BangumiDetailState();
}

/// 番剧详情状态
class _BangumiDetailState extends ConsumerState<BangumiDetail>
    with AutomaticKeepAliveClientMixin {
  /// 番剧数据
  BangumiSubject? data;

  /// 用户Hive
  final BgmUserHive hiveUser = BgmUserHive();

  /// 弹幕Hive
  final DanmakuHive hiveDanmaku = DanmakuHive();

  @override
  bool get wantKeepAlive => true;

  /// 是否显示错误组件
  bool showError = false;

  /// 当id改变时, 重新加载数据
  @override
  void didUpdateWidget(BangumiDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      data = null;
      init();
    }
  }

  /// 构建函数
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await init();
    });
  }

  Future<void> init() async {
    if (showError) {
      showError = false;
      setState(() {});
    }
    data = null;
    setState(() {});
    var api = BtrBangumiApi();
    var detailGet = await api.getSubjectDetail(widget.id);
    if (detailGet.code != 0 || detailGet.data == null) {
      if (mounted) await showRespErr(detailGet, context);
      showError = true;
      return;
    }
    data = detailGet.data;
    setState(() {});
  }

  /// 获取封面
  String getCover(BangumiImages images) {
    return images.large;
  }

  /// 获取弹幕
  Future<void> fetchDanmaku(String id) async {
    var confirm = await showConfirmDialog(
      context,
      title: '确定匹配？',
      content: '未检测到与当前条目对应的弹幕，是否尝试匹配？',
    );
    if (!confirm) return;
    String? keyword = '';
    if (mounted) {
      keyword = await showInputDialog(
        context,
        title: '查询关键词',
        content: '请输入查询关键词',
        value: data!.name,
      );
    }
    if (keyword == null || keyword == '') {
      if (mounted) await BtInfobar.warn(context, '未输入关键词');
      return;
    }
    var api = BtrDanmakuAPI();
    var res = await api.searchAnime(keyword);
    if (res.code != 0 || res.data == null) {
      if (mounted) await showRespErr(res, context);
      return;
    }
    var danmaku = res.data as DanmakuSearchAnimeResponse;
    if (danmaku.list?.isEmpty ?? true) {
      if (mounted) await BtInfobar.warn(context, '未找到对应弹幕');
      return;
    }
    if (mounted) {
      var select = await selectAnime(context, danmaku.list!);
      if (select == null) return;
      var model = DanmakuHiveModel(
        subjectId: int.parse(id),
        animeId: select.animeId,
        animeTitle: select.animeTitle,
      );
      await hiveDanmaku.add(model);
      if (mounted) await BtInfobar.success(context, '成功匹配');
    }
  }

  /// 构建顶部栏
  Widget buildHeader() {
    String? title;
    if (data == null) {
      title = 'ID: ${widget.id}';
    } else {
      title = data?.nameCn == '' ? data?.name : data?.nameCn;
    }
    return PageHeader(
      leading: IconButton(
        icon: const Icon(FluentIcons.back),
        onPressed: () {
          if (data == null) {
            BtInfobar.error(context, '数据为空');
            return;
          }
          ref.read(navStoreProvider).removeNavItem(
              '${data!.type.label}详情 ${widget.id}',
              type: BtmAppNavItemType.subject,
              param: 'subjectDetail_${widget.id}');
        },
      ),
      title: Tooltip(
        message: title,
        child: Text(
          '${data?.type.label ?? '条目'}详情：$title',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      commandBar: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(FluentIcons.library),
            onPressed: () async {
              var check = hiveDanmaku.findBySubject(int.parse(widget.id));
              if (check == null) {
                await fetchDanmaku(widget.id);
              } else {
                await hiveDanmaku.showInfo(context, check);
              }
            },
            onLongPress: () async {
              var check = hiveDanmaku.findBySubject(int.parse(widget.id));
              if (check == null) {
                await fetchDanmaku(widget.id);
                return;
              }
              var confirm = await showConfirmDialog(
                context,
                title: '重新匹配',
                content: '确定重新匹配吗？',
              );
              if (!confirm) return;
              await fetchDanmaku(widget.id);
            },
          ),
          IconButton(
            icon: const Icon(FluentIcons.refresh),
            onPressed: () async {
              await init();
            },
          ),
        ],
      ),
    );
  }

  /// 构建加载中
  Widget buildLoading() {
    if (showError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(FluentIcons.error),
            SizedBox(height: 12.h),
            const Text('Error: 加载失败'),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ProgressRing(),
          SizedBox(height: 12.h),
          const Text('Loading...'),
        ],
      ),
    );
  }

  /// 构建简介
  Widget buildSummary(String summary) {
    if (summary == '') {
      return ListTile(
        leading: const Icon(FluentIcons.error_badge),
        title: Text('没有简介', style: TextStyle(fontSize: 24.sp)),
      );
    }
    return Container(
      margin: EdgeInsets.only(right: 12.w),
      child: Expander(
          initiallyExpanded: true,
          leading: const Icon(FluentIcons.info),
          header: Text('简介', style: TextStyle(fontSize: 24.sp)),
          content: Text(summary)),
    );
  }

  /// 构建其他信息
  Widget buildOtherInfo(List<BangumiInfoBoxItem> infobox) {
    var res = <Widget>[];
    // 换行加tab
    var gap = "\n    ";
    for (var item in infobox) {
      String value;
      if (item.value is List) {
        var list = item.value as List;
        value = list
            .map((e) => e['k'] != null ? '${e['k']}:${e['v']}' : e['v'])
            .toList()
            .map((e) => replaceEscape(e as String))
            .join(gap);
        res.add(
          Text('${item.key}:$gap$value'),
        );
      } else {
        value = replaceEscape(item.value as String);
        res.add(Text('${item.key}: $value'));
      }
      res.add(SizedBox(height: 12.h));
    }
    return Container(
      margin: EdgeInsets.only(right: 12.w),
      child: Expander(
        leading: const Icon(FluentIcons.info),
        header: Text('其他信息', style: TextStyle(fontSize: 24.sp)),
        content: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: res,
        ),
      ),
    );
  }

  /// 构建用户部分
  Widget buildUserPart() {
    return Column(
      children: [
        buildLoading(),
      ],
    );
  }

  /// 构建内容
  Widget buildContent() {
    if (data == null) return buildLoading();
    assert(data != null);
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      children: [
        BsdOverview(data!),
        SizedBox(height: 12.h),
        if (hiveUser.user != null) ...[
          BsdUserCollection(data!, hiveUser.user!),
          SizedBox(height: 12.h)
        ],
        BsdUserEpisodes(data!),
        SizedBox(height: 12.h),
        BsdBmf(data!.id),
        SizedBox(height: 12.h),
        BsdRelation(data!.id),
        SizedBox(height: 12.h),
        buildSummary(data!.summary),
        SizedBox(height: 12.h),
        buildOtherInfo(data!.infobox),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(header: buildHeader(), content: buildContent());
  }
}
