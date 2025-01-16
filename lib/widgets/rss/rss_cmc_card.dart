// Package imports:
import 'package:dart_rss/dart_rss.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jiffy/jiffy.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../store/dtt_store.dart';
import '../../tools/download_tool.dart';
import '../../ui/bt_infobar.dart';
import '../../utils/tool_func.dart';

/// Mikan Rss Card
class RssCmcCard extends ConsumerStatefulWidget {
  /// rss item
  final RssItem item;

  /// 构造函数
  const RssCmcCard(this.item, {super.key});

  @override
  ConsumerState<RssCmcCard> createState() => _RssCmcCardState();
}

/// Mikan Rss Card State
class _RssCmcCardState extends ConsumerState<RssCmcCard> {
  /// 获取item
  RssItem get item => widget.item;

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
              assert(item.enclosure != null && item.enclosure!.url != null);
              assert(item.title != null && item.title != '');
              var saveDir = await getDirectoryPath();
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
            },
          ),
        ),
        Tooltip(
          message: '内置下载',
          child: IconButton(
            icon: Icon(FluentIcons.download, color: color),
            onPressed: () async {
              var saveDir = await getDirectoryPath();
              if (saveDir == null || saveDir.isEmpty) {
                if (context.mounted) await BtInfobar.error(context, '未选择下载目录');
                return;
              }
              var check = await ref.read(dttStoreProvider.notifier).addTask(
                    item,
                    saveDir,
                  );
              if (check) {
                if (context.mounted) {
                  await BtInfobar.success(context, '添加下载任务成功');
                }
              } else {
                if (context.mounted) await BtInfobar.warn(context, '已经在下载列表中');
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
    var time = '';
    if (item.pubDate != null && item.pubDate != '') {
      time = Jiffy.parse(
        item.pubDate!,
        pattern: 'EEE, dd MMM yyyy HH:mm:ss Z',
      ).format(pattern: 'yyyy-MM-dd HH:mm:ss');
    }
    return Card(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
      margin: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
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
          Text('发布时间: $time'),
          Text('资源类型: ${item.enclosure?.type ?? ''}'),
          Text('资源链接: ${item.enclosure?.url ?? ''}'),
          SizedBox(height: 8.h),
          buildAct(context),
        ],
      ),
    );
  }
}
