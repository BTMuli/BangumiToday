part of '../bmf_expander.dart';

class _FileItemActions extends StatelessWidget {
  final String file;
  final String dir;
  final bool isVideo;
  final bool isTorrent;
  final bool canOpen;
  final bool isIncomplete;
  final Future<void> Function() onDelete;
  final BTFileTool fileTool = BTFileTool();

  _FileItemActions({
    required this.file,
    required this.dir,
    required this.isVideo,
    required this.isTorrent,
    required this.canOpen,
    required this.isIncomplete,
    required this.onDelete,
  });

  Future<void> tryDeleteFile(String filePath, BuildContext context) async {
    var check = await fileTool.deleteFile(filePath);
    if (!check) {
      if (context.mounted) await BtInfobar.error(context, '删除文件失败');
      return;
    }
    await onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isVideo && canOpen)
          Tooltip(
            message: '打开文件',
            child: IconButton(
              icon: BtIcon(FluentIcons.open_file, size: 14),
              onPressed: () async {
                var filePath = path.join(dir, file);
                await launchUrlString('file://$filePath');
              },
            ),
          ),
        Tooltip(
          message: '删除 (长按直接删除)',
          child: IconButton(
            icon: BtIcon(
              FluentIcons.delete,
              size: 14,
              color: FluentTheme.of(context).accentColor,
            ),
            onPressed: () async {
              var confirm = await showConfirm(
                context,
                title: '删除文件',
                content: isIncomplete
                    ? '该文件尚未下载完成，删除可能中断下载任务。确定删除文件 $file 吗？'
                    : '确定删除文件 $file 吗？',
              );
              if (!confirm) return;
              var filePath = path.join(dir, file);
              if (context.mounted) await tryDeleteFile(filePath, context);
            },
            onLongPress: () async {
              var filePath = path.join(dir, file);
              if (context.mounted) await tryDeleteFile(filePath, context);
            },
          ),
        ),
      ],
    );
  }
}

class _RssItemActions extends ConsumerWidget {
  final RssItem item;
  final String? dir;
  final int? subject;
  final String rssLink;
  final Future<void> Function()? onHandled;

  const _RssItemActions({
    required this.item,
    required this.dir,
    required this.subject,
    required this.rssLink,
    this.onHandled,
  });

  Future<String?> getSavePath(BuildContext context) async {
    if (item.enclosure?.url == null || item.title == null) return null;
    var urlReal = BtrMikanApi.rewriteUrl(item.enclosure!.url!);
    var dtt = BTDownloadTool();
    var savePath = await dtt.downloadRssTorrent(urlReal, item.title!);
    return savePath.isEmpty ? null : savePath;
  }

  Future<void> download(BuildContext context, WidgetRef ref) async {
    if (item.enclosure?.url == null || item.title == null) return;
    var saveDir = dir;
    if (saveDir == null || saveDir.isEmpty) {
      await BtInfobar.error(context, '未设置下载目录');
      return;
    }
    var savePath = await getSavePath(context);
    if (savePath == null) return;
    try {
      await ref
          .read(btDownloadStoreProvider)
          .addTorrentFile(
            torrentPath: savePath,
            savePath: saveDir,
            displayName: item.title,
          );
      await onHandled?.call();
      if (context.mounted) await BtInfobar.success(context, '下载任务已添加');
    } catch (error) {
      if (context.mounted) {
        await BtInfobar.error(context, error.toString());
      }
    }
  }

  Future<void> openLink(BuildContext context) async {
    if (item.link == null) return;
    var linkReal = BtrMikanApi.rewriteUrl(item.link!);
    await launchUrlString(linkReal);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: '内置下载',
          child: IconButton(
            icon: BtIcon(FluentIcons.download, size: 14),
            onPressed: () async => await download(context, ref),
          ),
        ),
        Tooltip(
          message: '打开链接',
          child: IconButton(
            icon: BtIcon(FluentIcons.edge_logo, size: 14),
            onPressed: () async => await openLink(context),
          ),
        ),
      ],
    );
  }
}
