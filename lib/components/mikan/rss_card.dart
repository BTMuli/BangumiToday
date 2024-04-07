import 'package:dart_rss/dart_rss.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../utils/tool_func.dart';

/// Mikan Rss Card
class MikanRssCard extends StatelessWidget {
  /// rss item
  final RssItem item;

  /// 构造函数
  const MikanRssCard(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    var sizeStr = '', pubDate = '';
    if (item.enclosure?.length != null) {
      var size = item.enclosure!.length;
      sizeStr = bytes2size(size);
    }
    if (item.pubDate != null) {
      pubDate = dateTransMikan(item.pubDate!);
    }
    // todo 尝试点击下载torrent文件并调用motrix下载
    return Card(
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title ?? '',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(item.link ?? ''),
          Text('发布时间: $pubDate'),
          Text('资源类型: ${item.enclosure?.type ?? ''}'),
          Text('资源大小: $sizeStr'),
          Text('资源链接: ${item.enclosure?.url ?? ''}'),
        ],
      ),
    );
  }
}
