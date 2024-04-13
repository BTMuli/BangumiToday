import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_rss/dart_rss.dart';
import 'package:file_picker/file_picker.dart';
import 'package:filesize/filesize.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../tools/download_tool.dart';
import '../../utils/tool_func.dart';
import '../app/app_infobar.dart';

/// Mikan Rss Card
class MikanRssCard extends StatelessWidget {
  /// rss item
  final RssItem item;

  /// 目录，可选
  final String? dir;

  /// 构造函数
  const MikanRssCard(this.item, {super.key, this.dir});

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
              var saveDir;
              if (dir == null || dir!.isEmpty) {
                saveDir = await FilePicker.platform.getDirectoryPath();
              } else {
                saveDir = dir;
              }
              if (saveDir == null || saveDir.isEmpty) {
                await BtInfobar.error(context, '未选择下载目录');
                return;
              }
              // md5 title
              var title = md5.convert(utf8.encode(item.title!)).toString();
              var savePath = await BTDownloadTool().downloadFile(
                item.enclosure!.url!,
                title,
              );
              if (savePath != '') {
                await launchUrlString(
                  'mo://new-task/?type=torrent&dir=$saveDir',
                );
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
    var sizeStr = '', pubDate = '';
    if (item.enclosure?.length != null) {
      var size = item.enclosure!.length;
      sizeStr = filesize(size);
    }
    if (item.pubDate != null) {
      pubDate = dateTransMikan(item.pubDate!);
    }
    return Card(
      padding: EdgeInsets.symmetric(vertical: 16.w, horizontal: 16.h),
      margin: EdgeInsets.symmetric(vertical: 8.w, horizontal: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title ?? '',
            style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          Text(item.link ?? ''),
          Text('发布时间: $pubDate'),
          Text('资源类型: ${item.enclosure?.type ?? ''}'),
          Text('资源大小: $sizeStr'),
          Text('资源链接: ${item.enclosure?.url ?? ''}'),
          SizedBox(height: 8.h),
          buildAct(context),
        ],
      ),
    );
  }
}
