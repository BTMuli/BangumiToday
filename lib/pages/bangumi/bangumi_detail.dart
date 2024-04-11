import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../components/bangumi/detail_card.dart';
import '../../models/app/err.dart';
import '../../models/bangumi/common_model.dart';
import '../../models/bangumi/get_subject.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../store/nav_store.dart';

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

  @override
  bool get wantKeepAlive => true;

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
  }

  /// future
  Future<String> init() async {
    if (data != null) return 'success';
    final api = BangumiAPI();
    try {
      data = await api.getDetail(widget.id);
      setState(() {});
      return 'success';
    } on BTError catch (e) {
      return '[${e.type}] ${e.message}';
    }
  }

  /// 获取封面
  String getCover(BangumiImage images) {
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
      title: Text(
        '番剧详情：$title',
        overflow: TextOverflow.ellipsis,
      ),
      leading: IconButton(
        icon: Icon(FluentIcons.back),
        onPressed: () {
          ref.read(navStoreProvider).removeNavItem('番剧详情');
        },
      ),
    );
  }

  /// 构建加载中
  Widget buildLoading() {
    return ScaffoldPage(
      header: buildHeader(),
      content: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProgressRing(),
            SizedBox(height: 12.h),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }

  /// 构建错误
  Widget buildError(String message) {
    return ScaffoldPage(
      header: buildHeader(),
      content: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.error),
            SizedBox(height: 12.h),
            Text('Error: $message'),
          ],
        ),
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
        content: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary, style: TextStyle(fontSize: 20.sp)),
          ],
        ),
      ),
    );
  }

  /// 构建其他信息
  Widget buildOtherInfo(List<BangumiSubjectInfoBox> infobox) {
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
            .join(gap);
        res.add(
          Text('${item.key}:$gap$value', style: TextStyle(fontSize: 20.sp)),
        );
      } else {
        value = item.value;
        res.add(Text('${item.key}: $value', style: TextStyle(fontSize: 20.sp)));
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

  /// 构建内容
  Widget buildContent(BangumiSubject bangumi) {
    return ScaffoldPage(
      header: buildHeader(),
      content: ListView(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        children: [
          BangumiDetailCard(bangumi),
          SizedBox(height: 12.h),
          buildSummary(bangumi.summary),
          SizedBox(height: 12.h),
          // 章节
          // buildEpisodes(),
          buildOtherInfo(bangumi.infobox),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<String>(
      future: init(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return buildLoading();
        }
        if (snapshot.hasError) {
          return buildError(snapshot.error.toString());
        }
        if (snapshot.hasData) {
          if (snapshot.data == 'success' && data != null) {
            return buildContent(data!);
          }
          return buildError(snapshot.data ?? 'Unknown');
        }
        return buildLoading();
      },
    );
  }
}
