import 'dart:convert';

// import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'package:dart_rss/dart_rss.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../tools/download_tool.dart';
import '../../utils/tool_func.dart';

/// Mikan Rss Card
class ComicatRssCard extends StatelessWidget {
  /// rss item
  final RssItem item;

  /// 构造函数
  const ComicatRssCard(this.item, {super.key});

  /// 构建操作按钮
  Widget buildAct(BuildContext context) {
    var color = FluentTheme.of(context).accentColor;
    return Row(
      children: [
        Tooltip(
          message: '下载',
          child: IconButton(
            icon: Icon(FluentIcons.link, color: color),
            onPressed: () async {
              if (item.enclosure?.url == null || item.enclosure?.url == '') {
                return;
              }
              if (item.title == null || item.title == '') {
                return;
              }
              // md5 title
              var title = md5.convert(utf8.encode(item.title!)).toString();
              var savePath = await BTDownloadTool().downloadFile(
                item.enclosure!.url!,
                title,
              );
              // var transUrl = Uri.encodeComponent(item.enclosure!.url!);
              // var saveDir = path.join(BTDownloadTool.defaultBgmPath, title);
              // var transTorrent = Uri.encodeComponent('$savePath');
              // 重命名文件 out=${transOut}
              // var transOut = Uri.encodeComponent(item.title!);
              // 保存目录
              // var transDir = Uri.encodeComponent(saveDir);
              if (savePath != '') {
                // await launchUrlString(
                //     'mo://new-task/?type=torrent&dir=$transDir&torrent=$transTorrent&selectFile=$transTorrent');
                // 调用 motrix 打开文件
                await launchUrlString('file://$savePath');
              }
            },
          ),
        ),
        Tooltip(
          message: '打开链接',
          child: IconButton(
            icon: Icon(FluentIcons.edge_logo, color: color),
            onPressed: () async {
              if (item.link == null || item.link == '') {
                return;
              }
              await launchUrlString(item.link!);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var title = '';
    if (item.title != null && item.title != '') {
      title = replaceEscape(item.title!);
    }
    return Card(
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          Text(item.link ?? ''),
          Text('发布者: ${item.author ?? ''}'),
          Text('发布时间: ${item.pubDate ?? ''}'),
          Text('资源类型: ${item.enclosure?.type ?? ''}'),
          Text('资源链接: ${item.enclosure?.url ?? ''}'),
          SizedBox(height: 8.h),
          buildAct(context),
        ],
      ),
    );
  }
}
