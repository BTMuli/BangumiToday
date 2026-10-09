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

class _RssItemActions extends ConsumerStatefulWidget {
  final RssReleaseData release;
  final RssReleaseSource source;
  final String? dir;
  final int subjectId;
  final Uri? baseUrl;
  final Future<void> Function()? onHandled;

  const _RssItemActions({
    super.key,
    required this.release,
    required this.source,
    required this.dir,
    required this.subjectId,
    this.baseUrl,
    this.onHandled,
  });

  @override
  ConsumerState<_RssItemActions> createState() => _RssItemActionsState();
}

class _RssItemActionsState extends ConsumerState<_RssItemActions>
    with AutomaticKeepAliveClientMixin {
  final ValueNotifier<bool> _downloading = ValueNotifier(false);
  bool _showingDetails = false;

  @override
  bool get wantKeepAlive => _downloading.value || _showingDetails;

  @override
  void dispose() {
    _downloading.dispose();
    super.dispose();
  }

  String _sourceUrl(String url) => widget.source == RssReleaseSource.mikan
      ? BtrMikanApi.rewriteUrl(url)
      : url;

  Future<void> _download() async {
    var release = widget.release;
    if (!mounted || _downloading.value || !release.canDownload) return;
    var saveDir = widget.dir;
    if (saveDir == null || saveDir.isEmpty) {
      await BtInfobar.error(context, '未设置下载目录');
      return;
    }
    var subjectId = widget.subjectId;
    var onHandled = widget.onHandled;
    _downloading.value = true;
    updateKeepAlive();
    try {
      var url = _sourceUrl(release.downloadUrl!);
      var store = ref.read(btDownloadStoreProvider.notifier);
      if (Uri.parse(url).scheme == 'magnet') {
        await store.addMagnet(
          uri: url,
          savePath: saveDir,
          displayName: release.title,
          subjectId: subjectId,
        );
      } else {
        var torrentPath = await BTDownloadTool().downloadRssTorrent(
          url,
          release.title,
          context: context,
        );
        if (!mounted || torrentPath.isEmpty) return;
        await store.addTorrentFile(
          torrentPath: torrentPath,
          savePath: saveDir,
          displayName: release.title,
          subjectId: subjectId,
        );
      }
      await onHandled?.call();
      if (mounted) await BtInfobar.success(context, '下载任务已添加');
    } catch (error) {
      if (mounted) {
        await BtInfobar.error(context, error.toString());
      }
    } finally {
      if (mounted) {
        _downloading.value = false;
        updateKeepAlive();
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

  Future<void> _showDetails() async {
    var release = widget.release;
    var baseUrl = widget.baseUrl;
    _showingDetails = true;
    updateKeepAlive();
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        dismissWithEsc: true,
        builder: (dialogContext) => RssReleaseDetailDialog(
          release: release,
          markdownDescription:
              widget.source == RssReleaseSource.anibt ||
              release.item.anibt != null,
          baseUrl: baseUrl == null
              ? null
              : Uri.tryParse(_sourceUrl(baseUrl.toString())),
          onTapUrl: (url) => _openDescriptionLink(dialogContext, url),
          actions: Row(
            children: [
              const Spacer(),
              _buildActions(includeDetails: false),
              const SizedBox(width: 12),
              Button(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) {
        _showingDetails = false;
        updateKeepAlive();
      }
    }
  }

  Widget _buildActions({bool includeDetails = true}) {
    var release = widget.release;
    return ValueListenableBuilder<bool>(
      valueListenable: _downloading,
      builder: (context, downloading, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (includeDetails &&
              release.hasDescription &&
              (widget.source != RssReleaseSource.mikan ||
                  release.summary != null))
            Tooltip(
              message: '查看资源详情',
              child: IconButton(
                icon: BtIcon(FluentIcons.info, size: 14),
                onPressed: _showDetails,
              ),
            ),
          Tooltip(
            message: downloading
                ? '正在添加下载任务'
                : release.canDownload
                ? '内置下载'
                : '该资源没有可用的种子或磁力链接',
            child: IconButton(
              icon: downloading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  : BtIcon(FluentIcons.download, size: 14),
              onPressed: release.canDownload && !downloading ? _download : null,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildActions();
  }
}
