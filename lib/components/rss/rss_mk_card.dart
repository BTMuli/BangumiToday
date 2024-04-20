import 'package:dart_rss/domain/rss_item.dart';
import 'package:file_selector/file_selector.dart';
import 'package:filesize/filesize.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../database/app/app_bmf.dart';
import '../../database/app/app_rss.dart';
import '../../models/app/nav_model.dart';
import '../../pages/bangumi/bangumi_detail.dart';
import '../../store/dtt_store.dart';
import '../../store/nav_store.dart';
import '../../tools/download_tool.dart';
import '../../tools/log_tool.dart';
import '../../tools/notifier_tool.dart';
import '../../utils/tool_func.dart';
import '../app/app_infobar.dart';

/// MikanRSS Card
class RssMikanCard extends ConsumerStatefulWidget {
  /// rss链接
  final String link;

  /// rssItem
  final RssItem item;

  /// 下载目录，可选
  final String? dir;

  /// subject id 可选
  final int? subject;

  /// 是否是新项，这部分检测交给父元素
  final bool isNew;

  /// 是否需要提醒
  final bool notify;

  /// 构造函数
  const RssMikanCard(
    this.link,
    this.item, {
    super.key,
    this.dir,
    this.isNew = false,
    this.notify = false,
    this.subject,
  });

  @override
  ConsumerState<RssMikanCard> createState() => _RssMikanCardState();
}

/// MikanRSS Card State
class _RssMikanCardState extends ConsumerState<RssMikanCard> {
  /// 获取rss链接
  String get link => widget.link;

  /// 获取item
  RssItem get item => widget.item;

  /// 获取目录
  String? get dir => widget.dir;

  /// 获取条目
  int? get subject => widget.subject;

  /// 是否需要提醒
  bool get notify => widget.notify;

  /// 是否是新项
  bool get isNew => widget.isNew;

  /// 数据库
  final BtsAppRss sqlite = BtsAppRss();

  /// bmf数据库
  final BtsAppBmf sqliteBmf = BtsAppBmf();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      await init();
    });
  }

  /// 初始化
  Future<void> init() async {
    if (isNew && notify) {
      await BTNotifierTool.showMini(
        title: 'RSS 订阅更新',
        body: '${item.title}',
        onClick: () async {
          var title = '条目详情 $subject';
          var pane = PaneItem(
            icon: const Icon(FluentIcons.info),
            title: Text(title),
            body: BangumiDetail(id: subject.toString()),
          );
          ref.read(navStoreProvider.notifier).addNavItem(
                pane,
                title,
                type: BtmAppNavItemType.bangumiSubject,
                param: 'subjectDetail_$subject',
              );
        },
      );
      BTLogTool.info('RSS 订阅更新: ${item.title}');
    }
  }

  /// 获取下载目录
  Future<String?> getSaveDir() async {
    String? saveDir;
    if (dir == null || dir!.isEmpty) {
      saveDir = await getDirectoryPath();
    } else {
      saveDir = dir;
    }
    if (saveDir == null || saveDir.isEmpty) {
      if (mounted) await BtInfobar.error(context, '未选择下载目录');
      return null;
    }
    return saveDir;
  }

  /// 下载
  Future<String?> getSavePath(BuildContext context, String saveDir) async {
    assert(item.enclosure?.url != null && item.enclosure?.url != '');
    assert(item.title != null && item.title != '');
    var savePath = await BTDownloadTool().downloadRssTorrent(
      item.enclosure!.url!,
      item.title!,
    );
    return savePath;
  }

  /// 通过内置下载
  Future<void> downloadInner(BuildContext context) async {
    var saveDir = await getSaveDir();
    if (saveDir == null || saveDir.isEmpty) {
      return;
    }
    var check = ref.read(dttStoreProvider.notifier).addTask(item, saveDir);
    if (check) {
      if (context.mounted) BtInfobar.success(context, '添加下载任务成功');
    } else {
      if (context.mounted) BtInfobar.warn(context, '已经在下载列表中');
    }
  }

  /// 调用 motrix 下载
  Future<void> downloadMotrix(BuildContext context) async {
    var saveDir = await getSaveDir();
    if (saveDir == null || saveDir.isEmpty) {
      return;
    }
    if (!context.mounted) return;
    var savePath = await getSavePath(context, saveDir);
    await launchUrlString(
      'mo://new-task/?type=torrent&dir=$saveDir',
    );
    await launchUrlString('file://$savePath');
  }

  /// 构建内置下载按钮
  Widget buildActInner(BuildContext context) {
    return Tooltip(
      message: '内置下载',
      child: IconButton(
        icon: const Icon(FluentIcons.link),
        onPressed: () async {
          await downloadInner(context);
        },
      ),
    );
  }

  /// 构建 motrix 下载按钮
  Widget buildActMotrix(BuildContext context) {
    return Tooltip(
      message: 'Motrix 下载',
      child: IconButton(
        icon: Image.asset(
          'assets/images/platforms/motrix-logo.png',
          width: 16,
          height: 16,
        ),
        onPressed: () async {
          await downloadMotrix(context);
        },
      ),
    );
  }

  /// 构建打开链接按钮
  Widget buildActLink(BuildContext context) {
    return Tooltip(
      message: '打开链接',
      child: IconButton(
        icon: const Icon(FluentIcons.edge_logo),
        onPressed: () async {
          assert(item.link != null && item.link != '');
          await launchUrlString(item.link!);
        },
      ),
    );
  }

  /// 构建操作按钮
  Widget buildAct(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (kDebugMode) buildActInner(context),
        buildActMotrix(context),
        buildActLink(context),
      ],
    );
  }

  /// 构建标题
  Widget buildTitle() {
    return Tooltip(
      message: item.title ?? '',
      child: Text(
        item.title ?? '',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// 构建发布时间
  Widget buildPubDate() {
    assert(item.pubDate != null);
    return Row(
      children: [
        const Text('发布时间: '),
        Text(
          dateTransLocal(item.pubDate!),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// 构建资源大小
  Widget buildSource() {
    assert(item.enclosure != null);
    return Row(
      children: [
        const Text('资源大小: '),
        Text(
          filesize(item.enclosure!.length),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 275,
      height: 180,
      child: Card(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildTitle(),
            const Spacer(),
            if (item.pubDate != null) buildPubDate(),
            const SizedBox(height: 4),
            buildSource(),
            buildAct(context),
          ],
        ),
      ),
    );
  }
}
