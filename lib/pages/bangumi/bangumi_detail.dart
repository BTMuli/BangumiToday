import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

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
  Subject? data;

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
      title = data?.name;
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

  /// 构建封面&基本信息
  Widget buildBasicInfo(Subject bangumi) {
    // 封面
    var cover = getCover(bangumi.images);
    return Row(
      children: [
        // 封面
        Container(
          width: 200.w,
          height: 300.h,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(cover),
              fit: BoxFit.cover,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        // 基本信息
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 名称
              Text(
                bangumi.name,
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12.h),
              // 基本信息
              Text(
                'ID: ${bangumi.id}',
                style: TextStyle(
                  fontSize: 16.sp,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                '评分: ${bangumi.rating.score}',
                style: TextStyle(
                  fontSize: 16.sp,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                '评分人数: ${bangumi.rating.total}',
                style: TextStyle(
                  fontSize: 16.sp,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建内容
  Widget buildContent(Subject bangumi) {
    return ScaffoldPage(
      header: buildHeader(),
      padding: EdgeInsets.only(
        top: 12.h,
        left: 12.w,
        right: 12.w,
        bottom: 12.h,
      ),
      content: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面&基本信息
          buildBasicInfo(bangumi),
          // 简介
          // buildSummary(),
          // 章节
          // buildEpisodes(),
          // 其他信息
          // buildOtherInfo(),
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
