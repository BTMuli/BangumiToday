import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../components/app/app_infobar.dart';
import '../../components/app/rss_dowload_card.dart';
import '../../store/dtt_store.dart';

/// 下载管理
class DownloadPage extends ConsumerStatefulWidget {
  /// 构造函数
  const DownloadPage({super.key});

  @override
  ConsumerState<DownloadPage> createState() => _DownloadPageState();
}

/// 下载管理状态
class _DownloadPageState extends ConsumerState<DownloadPage>
    with AutomaticKeepAliveClientMixin {
  /// 下载列表
  List<DttItem> list = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  bool get wantKeepAlive => true;

  /// 构建头部
  Widget buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          Text('下载管理', style: FluentTheme.of(context).typography.title),
          SizedBox(width: 16.w),
          IconButton(
            icon: Icon(FluentIcons.refresh),
            onPressed: () {
              list = ref.read(dttStoreProvider).list;
              setState(() {});
              BtInfobar.success(context, '刷新成功');
            },
          ),
        ],
      ),
    );
  }

  /// 构建函数
  @override
  Widget build(BuildContext context) {
    super.build(context);
    list = ref.watch(dttStoreProvider).list;
    return ScaffoldPage(
      header: buildHeader(context),
      content: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        children: [
          for (var item in list) ...[
            RssDownloadCard(item.item, item.dir),
            SizedBox(height: 16.h),
          ]
        ],
      ),
    );
  }
}
