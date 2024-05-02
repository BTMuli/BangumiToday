// Package imports:
import 'package:dart_rss/dart_rss.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:jiffy/jiffy.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../tools/download_tool.dart';
import '../../utils/tool_func.dart';
import '../app/app_infobar.dart';

/// MikanRss卡片，仅用于动画详情页面
class RssMikanCard2 extends StatelessWidget {
  /// rss item
  final RssItem item;

  /// 目录，可选
  final String? dir;

  /// 构造函数
  const RssMikanCard2(this.item, {super.key, this.dir});

  /// 下载
  Future<void> download(BuildContext context) async {
    assert(item.enclosure != null && item.enclosure!.url != null);
    assert(item.title != null && item.title != '');
    String? saveDir;
    if (dir == null || dir!.isEmpty) {
      saveDir = await getDirectoryPath();
    } else {
      saveDir = dir;
    }
    if (saveDir == null || saveDir.isEmpty) {
      if (context.mounted) await BtInfobar.error(context, '未选择下载目录');
      return;
    }
    var savePath = await BTDownloadTool().downloadRssTorrent(
      item.enclosure!.url!,
      item.title!,
    );
    if (savePath != '') {
      await launchUrlString(
        'mo://new-task/?type=torrent&dir=$saveDir',
      );
      await launchUrlString('file://$savePath');
    }
  }

  /// 构建操作按钮
  Widget buildAct(BuildContext context) {
    var color = FluentTheme.of(context).accentColor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Tooltip(
          message: '下载',
          child: IconButton(
            icon: Icon(FluentIcons.link, color: color),
            onPressed: () async {
              await download(context);
            },
          ),
        ),
        Tooltip(
          message: '打开链接',
          child: IconButton(
            icon: Icon(FluentIcons.edge_logo, color: color),
            onPressed: () async {
              if (item.link == null || item.link == '') {
                await BtInfobar.error(context, '链接为空');
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
      pubDate = Jiffy.parse(
        item.pubDate!,
        pattern: 'yyyy-MM-ddTHH:mm:ss',
      ).format(pattern: 'yyyy-MM-dd HH:mm:ss');
    }
    var title = Tooltip(
      message: item.title ?? '',
      child: Text(
        item.title ?? '',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
    return SizedBox(
      width: 275,
      height: 180,
      child: Card(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const Spacer(),
            Row(
              children: [
                const Text('发布时间: '),
                Text(pubDate,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('资源大小: '),
                Text(sizeStr,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            buildAct(context),
          ],
        ),
      ),
    );
  }
}
