import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../components/app/app_dialog_resp.dart';
import '../../components/app/app_infobar.dart';
import '../../components/bangumi/subject_detail/bsd_bmf.dart';
import '../../components/bangumi/subject_detail/bsd_overview.dart';
import '../../components/bangumi/subject_detail/bsd_relation.dart';
import '../../components/bangumi/subject_detail/bsd_user_collection.dart';
import '../../components/bangumi/subject_detail/bsd_user_episodes.dart';
import '../../database/bangumi/bangumi_user.dart';
import '../../models/bangumi/bangumi_enum_extension.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../request/bangumi/bangumi_api.dart';
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

  /// 用户
  BangumiUser? user;

  /// 用户数据库
  final BtsBangumiUser sqlite = BtsBangumiUser();

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
    user = await sqlite.readUser();
    data = null;
    setState(() {});
    final api = BtrBangumiApi();
    var detailGet = await api.getSubjectDetail(widget.id);
    if (detailGet.code != 0 || detailGet.data == null) {
      await showRespErr(detailGet, context);
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

  /// 构建顶部栏
  Widget buildHeader() {
    var title;
    if (data == null) {
      title = 'ID: ${widget.id}';
    } else {
      title = data?.nameCn == '' ? data?.name : data?.nameCn;
    }
    return PageHeader(
      leading: IconButton(
        icon: Icon(FluentIcons.back),
        onPressed: () {
          if (data == null) {
            BtInfobar.error(context, '数据为空');
            return;
          }
          ref.read(navStoreProvider).removeNavItem(
                '${data!.type.label}详情 ${widget.id}',
              );
        },
      ),
      title: Tooltip(
        message: title,
        child: Text(
          '${data?.type.label ?? '条目'}详情：$title',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      commandBar: IconButton(
        icon: Icon(FluentIcons.refresh),
        onPressed: () async {
          await init();
        },
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
            Icon(FluentIcons.error),
            SizedBox(height: 12.h),
            Text('Error: 加载失败'),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ProgressRing(),
          SizedBox(height: 12.h),
          Text('Loading...'),
        ],
      ),
    );
  }

  /// 构建简介
  Widget buildSummary(String summary) {
    if (summary == '') {
      return ListTile(
        leading: Icon(FluentIcons.error_badge),
        title: Text('没有简介', style: TextStyle(fontSize: 24.sp)),
      );
    }
    return Container(
      margin: EdgeInsets.only(right: 12.w),
      child: Expander(
          initiallyExpanded: true,
          leading: Icon(FluentIcons.info),
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
      var value;
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
        leading: Icon(FluentIcons.info),
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
        BsdUserCollection(data!, user: user),
        SizedBox(height: 12.h),
        BsdUserEpisodes(data!, user: user),
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
