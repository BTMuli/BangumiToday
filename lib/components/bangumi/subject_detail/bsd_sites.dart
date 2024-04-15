import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../database/bangumi/bangumi_data.dart';
import '../../../models/bangumi/bangumi_data_model.dart';

/// bangumi-data 的播放站点数据
class BsdSiteItem {
  /// 站点名称
  final String name;

  /// 站点链接
  final String url;

  /// 站点key
  final String key;

  /// 站点类型
  final String type;

  /// 构造
  const BsdSiteItem({
    required this.name,
    required this.url,
    required this.key,
    required this.type,
  });
}

/// bangumi-data 的播放站点数据
class BsdSites extends StatefulWidget {
  /// 条目标题
  final String title;

  /// 构造
  const BsdSites(this.title, {super.key});

  @override
  State<BsdSites> createState() => _BsdSitesState();
}

class _BsdSitesState extends State<BsdSites> {
  /// bangumi-data数据库
  final BtsBangumiData sqlite = BtsBangumiData();

  /// 站点数据
  List<BsdSiteItem> siteItems = [];

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      await init();
    });
  }

  /// 初始化
  Future<void> init() async {
    var item = await sqlite.readItem(widget.title);
    var sites = [];
    var res = <BsdSiteItem>[];
    if (item == null || item.sites.isEmpty) return;
    sites = await sqlite.readSiteAll();
    if (sites.isEmpty) return;
    for (var siteItem in item.sites) {
      BangumiDataSiteFull? siteF =
          sites.firstWhere((e) => e.key == siteItem.site);
      if (siteF == null) continue;
      if (siteItem.id == null) continue;
      var link = siteF.urlTemplate.replaceAll('{{id}}', siteItem.id!);
      res.add(BsdSiteItem(
        name: siteF.title,
        url: link,
        key: siteF.key,
        type: siteF.type,
      ));
    }
    siteItems = res;
    setState(() {});
  }

  Widget buildSiteItem(BsdSiteItem item) {
    IconData icon;
    if (item.type == "resource") {
      icon = FluentIcons.cloud;
    } else if (item.type == "onair") {
      icon = FluentIcons.t_v_monitor;
    } else if (item.type == "info") {
      icon = FluentIcons.info;
    } else {
      icon = FluentIcons.link;
    }
    return Button(
      child: Row(
        children: [
          Icon(icon),
          SizedBox(width: 8.w),
          Text(item.name),
        ],
      ),
      onPressed: () async {
        await launchUrlString(item.url);
      },
    );
  }

  /// 构建滚动站点
  Widget buildScrollSites() {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 300.h),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var item in siteItems) ...[
              buildSiteItem(item),
              SizedBox(height: 8.h)
            ],
          ],
        ),
      ),
    );
  }

  /// 构建
  @override
  Widget build(BuildContext context) {
    if (siteItems.isEmpty) return Container();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('播放站点', style: FluentTheme.of(context).typography.subtitle),
        SizedBox(width: 8.w),
        buildScrollSites(),
      ],
    );
  }
}
