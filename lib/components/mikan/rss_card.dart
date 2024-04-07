import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_rss/dart_rss.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../tools/download_tool.dart';
import '../../utils/tool_func.dart';

/// Mikan Rss Card
class MikanRssCard extends StatelessWidget {
  /// rss item
  final RssItem item;

  /// 构造函数
  const MikanRssCard(this.item, {super.key});

  /// 构建操作按钮
  Widget buildAct() {
    return Row(
      children: [
        IconButton(
          // 调用磁力链接下载
          icon: Icon(FluentIcons.link),
          onPressed: () async {
            if (item.enclosure?.url == null || item.enclosure?.url == '') {
              return;
            }
            if (item.title == null || item.title == '') {
              return;
            }
            if (!BTDownloadTool.isInit) {
              await BTDownloadTool.init();
            }
            // md5 title
            var title = md5.convert(utf8.encode(item.title!)).toString();
            var savePath = await BTDownloadTool.downloadFile(
              item.enclosure!.url!,
              title,
            );
            if (savePath != '') {
              // await launchUrlString('mo://new-task/?type=torrent&'
              //     'url=${Uri.encodeComponent(savePath)}');
              // 调用 motrix 打开文件
              await launchUrlString('file://$savePath');
            }
          },
        ),
      ],
    );
  }

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
          SizedBox(height: 8.h),
          buildAct(),
        ],
      ),
    );
  }
}
