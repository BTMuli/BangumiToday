// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../controller/app/progress_controller.dart';
import '../../database/app/app_bmf.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/database/app_bmf_model.dart';
import '../../models/hive/nav_model.dart';
import '../../plugins/mikan/mikan_api.dart';
import '../../plugins/mikan/models/mikan_model.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../store/bgm_user_hive.dart';
import '../../store/nav_store.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../utils/tool_func.dart';
import '../../widgets/bangumi/subject_detail/bsd_bmf.dart';
import '../../widgets/bangumi/subject_detail/bsd_overview.dart';
import '../../widgets/bangumi/subject_detail/bsd_relation.dart';
import '../../widgets/bangumi/subject_detail/bsd_user_collection.dart';
import '../../widgets/bangumi/subject_detail/bsd_user_episodes.dart';

/// 数据监听Provider，用于监听收藏状态变更
class BangumiDetailProvider extends StateNotifier<bool> {
  /// 构造函数
  BangumiDetailProvider() : super(false);

  /// set
  void set(bool value) => state = value;
}

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

  /// mikanApi
  final BtrMikanApi mikanApi = BtrMikanApi();

  /// bmf数据库
  final BtsAppBmf sqliteBmf = BtsAppBmf();

  /// provider
  final BangumiDetailProvider provider = BangumiDetailProvider();

  /// progress
  late ProgressController progress = ProgressController();

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
      Future.microtask(init);
    }
  }

  /// 构建函数
  @override
  void initState() {
    super.initState();
    Future.microtask(init);
  }

  Future<void> init() async {
    if (showError) setState(() => showError = false);
    setState(() => data = null);
    var api = BtrBangumiApi();
    var detailGet = await api.getSubjectDetail(widget.id);
    if (detailGet.code != 0 || detailGet.data == null) {
      if (mounted) await showRespErr(detailGet, context);
      showError = true;
      return;
    }
    setState(() => data = detailGet.data);
  }

  Future<void> searchBangumi() async {
    if (data == null) {
      await BtInfobar.error(context, '数据为空');
      return;
    }
    var name = data?.nameCn == '' ? data?.name : data?.nameCn;
    if (name == null) {
      await BtInfobar.error(context, '数据为空');
      return;
    }
    var nameCheck = await showInput(
      context,
      title: '搜索番剧',
      content: '请输入番剧名称',
      value: name,
    );
    if (nameCheck == null) return;
    if (mounted) {
      progress = ProgressWidget.show(
        context,
        title: '搜索中',
        text: '正在搜索番剧: $nameCheck',
        progress: null,
      );
    }
    var resp = await mikanApi.searchBgm(nameCheck);
    progress.end();
    if (resp.code != 0) {
      if (mounted) await showRespErr(resp, context);
      return;
    }
    var items = resp.data as List<MikanSearchItemModel>;
    if (items.isEmpty) {
      if (mounted) await BtInfobar.error(context, '没有找到相关条目，请尝试更换搜索词');
      return;
    }
    if (mounted) await showSearchResult(context, items);
  }

  /// 显示搜索结果
  Future<void> showSearchResult(
    BuildContext context,
    List<MikanSearchItemModel> items,
  ) async {
    var result = await showDialog(
      context: context,
      barrierDismissible: true,
      dismissWithEsc: true,
      builder: (context) {
        return ContentDialog(
          title: const Text('搜索结果'),
          content: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              var item = items[index];
              return ListTile(
                title: Text(item.title),
                subtitle: Text(item.link),
                onPressed: () async {
                  var confirm = await showConfirm(
                    context,
                    title: '确认匹配？',
                    content: '将该结果设为BMF的RSS',
                  );
                  if (!confirm) return;
                  // 转成 int
                  var bmf = await sqliteBmf.read(int.parse(widget.id));
                  if (bmf == null) {
                    bmf = AppBmfModel(
                      subject: int.parse(widget.id),
                      title: data!.nameCn.isEmpty ? data!.name : data!.nameCn,
                      rss: item.rss,
                    );
                  } else {
                    bmf.rss = item.rss;
                  }
                  await sqliteBmf.write(bmf);
                  if (context.mounted) {
                    await BtInfobar.success(context, '成功设置RSS');
                    setState(() {});
                  }
                  if (context.mounted) Navigator.of(context).pop();
                  await init();
                },
              );
            },
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
    if (result == null) return;
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
            icon: const Icon(FluentIcons.refresh),
            onPressed: init,
          ),
          IconButton(
            icon: const Icon(FluentIcons.search),
            onPressed: searchBangumi,
          )
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
        title: Text('没有简介', style: TextStyle(fontSize: 20)),
      );
    }
    return Container(
      margin: EdgeInsets.only(right: 12.w),
      child: Expander(
          initiallyExpanded: true,
          leading: const Icon(FluentIcons.info),
          header: Text('简介', style: TextStyle(fontSize: 20)),
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
        header: Text('其他信息', style: TextStyle(fontSize: 20)),
        content: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: res,
        ),
      ),
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
          BsdUserCollection(data!, hiveUser.user!, provider),
          SizedBox(height: 12.h)
        ],
        BsdUserEpisodes(data!, hiveUser.user, provider),
        SizedBox(height: 12.h),
        BsdBmfWidget(
          data!.id,
          data!.nameCn.isEmpty ? data!.name : data!.nameCn,
        ),
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
