import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../components/bangumi/detail_card.dart';
import '../../models/app/err.dart';
import '../../models/bangumi/common_model.dart';
import '../../models/bangumi/get_subject.dart';
import '../../request/bangumi/bangumi_api.dart';

/// 番剧详情
class BangumiDetail extends StatefulWidget {
  /// 番剧 id
  final String id;

  /// 构造函数
  const BangumiDetail({super.key, required this.id});

  @override
  State<BangumiDetail> createState() => _BangumiDetailState();
}

/// 番剧详情状态
class _BangumiDetailState extends State<BangumiDetail> {
  /// 番剧数据
  BangumiSubject? data;

  /// 是否加载中
  bool isLoading = true;

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
      title = data?.nameCn;
    }
    return PageHeader(
      title: Text('番剧详情：$title'),
      leading: IconButton(
        icon: Icon(FluentIcons.back),
        onPressed: () {
          if (GoRouter.of(context).canPop()) {
            GoRouter.of(context).pop();
          } else {
            GoRouter.of(context).go('/');
          }
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
    var text = '没有简介';
    if (summary != '') {
      text = summary;
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('简介',
            style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold)),
        SizedBox(height: 12.h),
        Text(text, style: TextStyle(fontSize: 20.sp)),
      ],
    );
  }

  /// 构建其他信息
  List<Widget> buildOtherInfo(List<BangumiSubjectInfoBox> infobox) {
    var res = <Widget>[];
    res.add(
      Text(
        '其他信息',
        style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
      ),
    );
    res.add(SizedBox(height: 12.h));
    // 换行加tab
    var gap = "\n    ";
    for (var item in infobox) {
      var value;
      if (item.value is List) {
        var list = item.value as List;
        value = list.map((e) => e['v']).toList().join(gap);
        res.add(
            Text('${item.key}:$gap$value', style: TextStyle(fontSize: 20.sp)));
      } else {
        value = item.value;
        res.add(Text('${item.key}: $value', style: TextStyle(fontSize: 20.sp)));
      }

      res.add(SizedBox(height: 12.h));
    }
    return res;
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
          ...buildOtherInfo(bangumi.infobox),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
