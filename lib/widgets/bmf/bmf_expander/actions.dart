part of '../bmf_expander.dart';

class _FileItemActions extends ConsumerWidget {
  final String file;
  final int subject;
  final String dir;
  final bool isVideo;
  final bool canOpen;
  final bool isIncomplete;
  final Future<void> Function() onDelete;
  final BTFileTool fileTool = BTFileTool();

  _FileItemActions({
    required this.file,
    required this.subject,
    required this.dir,
    required this.isVideo,
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
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isVideo && canOpen)
          Tooltip(
            message: '应用内播放',
            child: IconButton(
              icon: BtIcon(FluentIcons.play, size: 14),
              onPressed: () => openLocalPlayback(
                context,
                ref,
                path.join(dir, file),
                subject: subject,
              ),
            ),
          ),
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
  final RssReleaseData release;
  final RssReleaseSource source;
  final String? dir;
  final Uri? baseUrl;
  final Future<void> Function()? onHandled;
  final bool includeDetails;

  const _RssItemActions({
    required this.release,
    required this.source,
    required this.dir,
    this.baseUrl,
    this.onHandled,
    this.includeDetails = true,
  });

  String _sourceUrl(String url) =>
      source == RssReleaseSource.mikan ? BtrMikanApi.rewriteUrl(url) : url;

  Future<void> download(BuildContext context, WidgetRef ref) async {
    if (!release.canDownload) return;
    var saveDir = dir;
    if (saveDir == null || saveDir.isEmpty) {
      await BtInfobar.error(context, '未设置下载目录');
      return;
    }
    try {
      var url = _sourceUrl(release.downloadUrl!);
      var store = ref.read(btDownloadStoreProvider.notifier);
      if (Uri.parse(url).scheme == 'magnet') {
        await store.addMagnet(
          uri: url,
          savePath: saveDir,
          displayName: release.title,
        );
      } else {
        var torrentPath = await BTDownloadTool().downloadRssTorrent(
          url,
          release.title,
          context: context,
        );
        if (!context.mounted || torrentPath.isEmpty) return;
        await store.addTorrentFile(
          torrentPath: torrentPath,
          savePath: saveDir,
          displayName: release.title,
        );
      }
      await onHandled?.call();
      if (context.mounted) await BtInfobar.success(context, '下载任务已添加');
    } catch (error) {
      if (context.mounted) {
        await BtInfobar.error(context, error.toString());
      }
    }
  }

  Future<bool> _openDescriptionLink(BuildContext context, String url) async {
    var uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return false;
    }
    try {
      var opened = await launchUrlString(_sourceUrl(url));
      if (!opened && context.mounted) {
        await BtInfobar.error(context, '无法打开链接');
      }
      return opened;
    } catch (error) {
      if (context.mounted) await BtInfobar.error(context, error.toString());
      return false;
    }
  }

  Future<void> _showDetails(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      dismissWithEsc: true,
      builder: (dialogContext) => RssReleaseDetailDialog(
        release: release,
        markdownDescription:
            source == RssReleaseSource.anibt || release.item.anibt != null,
        baseUrl: baseUrl == null
            ? null
            : Uri.tryParse(_sourceUrl(baseUrl.toString())),
        onTapUrl: (url) => _openDescriptionLink(dialogContext, url),
        actions: Row(
          children: [
            const Spacer(),
            _RssItemActions(
              release: release,
              source: source,
              dir: dir,
              baseUrl: baseUrl,
              onHandled: onHandled,
              includeDetails: false,
            ),
            const SizedBox(width: 12),
            Button(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (includeDetails &&
            release.hasDescription &&
            (source != RssReleaseSource.mikan || release.summary != null))
          Tooltip(
            message: '查看资源详情',
            child: IconButton(
              icon: BtIcon(FluentIcons.info, size: 14),
              onPressed: () => _showDetails(context),
            ),
          ),
        Tooltip(
          message: release.canDownload ? '内置下载' : '该资源没有可用的种子或磁力链接',
          child: IconButton(
            icon: BtIcon(FluentIcons.download, size: 14),
            onPressed: release.canDownload
                ? () => download(context, ref)
                : null,
          ),
        ),
        Tooltip(
          message: '打开链接',
          child: IconButton(
            icon: BtIcon(FluentIcons.edge_logo, size: 14),
            onPressed: release.detailUrl == null
                ? null
                : () => _openDescriptionLink(context, release.detailUrl!),
          ),
        ),
      ],
    );
  }
}
