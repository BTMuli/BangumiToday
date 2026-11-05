part of '../subject_rss_search_dialog.dart';

class _AnibtReleasePreview extends StatelessWidget {
  final AnibtGroupRelease item;
  final int subjectId;
  final bool enabled;

  const _AnibtReleasePreview({
    super.key,
    required this.item,
    required this.subjectId,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    var subtitle =
        AnibtFilters.subtitleLabels[item.subtitle?.toUpperCase()] ??
        item.subtitle ??
        '字幕类型未知';
    var languages = item.languages.map(
      (language) =>
          AnibtFilters.languageLabels[language.toUpperCase()] ?? language,
    );
    var size = item.size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Tooltip(
                message: item.title,
                child: Text(
                  item.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _RssPreviewDownloadButton(
              title: item.title,
              subjectId: subjectId,
              magnet: item.magnet,
              torrentUrl: item.torrentStorageId?.trim().isNotEmpty == true
                  ? AnibtAPI.releaseTorrentUrl(item.releaseId)
                  : null,
              source: _RssSearchSource.anibt,
              enabled: enabled,
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (_, constraints) => Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AnibtTagChip(
                label: [...languages, subtitle].join(' · '),
                highlighted: true,
                maxWidth: constraints.maxWidth,
              ),
              AnibtTagChip(
                label: item.resolution ?? '画质未知',
                maxWidth: constraints.maxWidth,
              ),
              AnibtTagChip(
                label: size == null || size <= 0 ? '大小未知' : filesize(size),
                tooltip: size == null || size <= 0 ? '大小未知' : '$size 字节',
                maxWidth: constraints.maxWidth,
              ),
              AnibtTagChip(
                label: _anibtUpdatedAt(item.publishedAt),
                maxWidth: constraints.maxWidth,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MikanEpisodePreview extends StatelessWidget {
  final MikanEpisodeModel item;
  final int subjectId;
  final bool enabled;

  const _MikanEpisodePreview({
    super.key,
    required this.item,
    required this.subjectId,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    var size = item.size;
    var updatedAt = item.updatedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Tooltip(
                message: item.title,
                child: Text(
                  item.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _RssPreviewDownloadButton(
              title: item.title,
              subjectId: subjectId,
              magnet: item.magnet,
              torrentUrl: item.torrent,
              source: _RssSearchSource.mikan,
              enabled: enabled,
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (_, constraints) => Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (size != null)
                AnibtTagChip(label: size, maxWidth: constraints.maxWidth),
              if (updatedAt != null)
                AnibtTagChip(
                  label: '更新 $updatedAt',
                  maxWidth: constraints.maxWidth,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RssPreviewDownloadButton extends ConsumerStatefulWidget {
  final String title;
  final int subjectId;
  final String? magnet;
  final String? torrentUrl;
  final _RssSearchSource source;
  final bool enabled;

  const _RssPreviewDownloadButton({
    required this.title,
    required this.subjectId,
    required this.magnet,
    required this.torrentUrl,
    required this.source,
    required this.enabled,
  });

  @override
  ConsumerState<_RssPreviewDownloadButton> createState() =>
      _RssPreviewDownloadButtonState();
}

class _RssPreviewDownloadButtonState
    extends ConsumerState<_RssPreviewDownloadButton>
    with AutomaticKeepAliveClientMixin {
  bool _downloading = false;

  @override
  bool get wantKeepAlive => _downloading;

  String? get _downloadUrl {
    var magnet = widget.magnet?.trim();
    if (Uri.tryParse(magnet ?? '')?.scheme == 'magnet') return magnet;
    var torrent = widget.torrentUrl?.trim();
    var uri = Uri.tryParse(torrent ?? '');
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return null;
    }
    return widget.source == _RssSearchSource.mikan
        ? BtrMikanApi.rewriteUrl(torrent!)
        : torrent;
  }

  Future<void> _download() async {
    var url = _downloadUrl;
    if (_downloading || !widget.enabled || url == null) return;
    setState(() => _downloading = true);
    updateKeepAlive();
    try {
      var bmf = await ref.read(bmfRepositoryProvider).read(widget.subjectId);
      if (!mounted) return;
      var directory = bmf?.download;
      if (directory == null || directory.isEmpty) {
        directory = await pickDownloadDirectory();
      }
      if (!mounted || directory == null || directory.isEmpty) return;
      var store = ref.read(btDownloadStoreProvider.notifier);
      if (Uri.parse(url).scheme == 'magnet') {
        await store.addMagnet(
          uri: url,
          savePath: directory,
          displayName: widget.title,
          subjectId: widget.subjectId,
        );
      } else {
        var torrentPath = await BTDownloadTool().downloadRssTorrent(
          url,
          widget.title,
          context: context,
        );
        if (!mounted || torrentPath.isEmpty) return;
        await store.addTorrentFile(
          torrentPath: torrentPath,
          savePath: directory,
          displayName: widget.title,
          subjectId: widget.subjectId,
        );
      }
      if (mounted) await BtInfobar.success(context, '下载任务已添加');
    } catch (error) {
      if (mounted) await BtInfobar.error(context, error.toString());
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
        updateKeepAlive();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var available = _downloadUrl != null;
    return Tooltip(
      message: available ? '添加下载任务' : '暂无可用的种子或磁力链接',
      child: Button(
        onPressed: widget.enabled && available && !_downloading
            ? _download
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_downloading)
              const SizedBox(
                width: 14,
                height: 14,
                child: ProgressRing(strokeWidth: 2),
              )
            else
              const Icon(FluentIcons.download, size: 14),
            const SizedBox(width: 6),
            Text(_downloading ? '添加中' : '下载'),
          ],
        ),
      ),
    );
  }
}
