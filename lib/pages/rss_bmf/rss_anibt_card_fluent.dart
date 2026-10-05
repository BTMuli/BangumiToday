// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiffy/jiffy.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/services/download_directory.dart';
import '../../core/services/download_service.dart';
import '../../core/theme/bt_theme.dart';
import '../../core/utils/tool_func.dart';
import '../../models/rss/anibt_filters.dart';
import '../../models/rss/rss.dart';
import '../../request/rss/anibt_api.dart';
import '../../store/bt_download_store.dart';
import '../../store/nav_store.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/rss/anibt_tag_chip.dart';
import '../../widgets/rss/rss_release_data.dart';
import '../../widgets/rss/rss_release_detail_dialog.dart';
import '../../widgets/rss/rss_release_surface.dart';

class RssAnibtCardFluent extends ConsumerStatefulWidget {
  final RssItem item;
  final AnibtFilters filters;
  final ValueChanged<AnibtTagSelection>? onTagSelected;

  const RssAnibtCardFluent({
    super.key,
    required this.item,
    required this.filters,
    this.onTagSelected,
  });

  @override
  ConsumerState<RssAnibtCardFluent> createState() => _RssAnibtCardFluentState();
}

class _RssAnibtCardFluentState extends ConsumerState<RssAnibtCardFluent>
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

  RssItem get item => widget.item;

  RssAnibtMetadata? get metadata => item.anibt;

  String get releaseTitle =>
      metadata?.releaseTitle ??
      item.title ??
      item.torrent?.filename ??
      'AniBT 资源';

  String? get magnetUri => _nonEmpty(item.torrent?.magnetUri);

  String? get torrentUrl =>
      _nonEmpty(metadata?.torrentUrl) ?? _nonEmpty(item.enclosure?.url);

  String? get releaseUrl =>
      _nonEmpty(metadata?.releasePageUrl) ?? _nonEmpty(item.link);

  String? get groupUrl {
    var slug = _nonEmpty(metadata?.groupSlug);
    if (slug == null) return null;
    return Uri.parse(
      AnibtAPI.baseUrl,
    ).replace(pathSegments: ['group', slug]).toString();
  }

  int? get contentLength {
    for (var size in [
      metadata?.fileSize,
      item.torrent?.contentLength,
      item.enclosure?.length,
    ]) {
      if (size != null && size > 0) return size;
    }
    return null;
  }

  DateTime? get publishedAt {
    for (var value in [item.torrent?.pubDate, item.pubDate, item.dc?.date]) {
      if (value == null || value.trim().isEmpty) continue;
      var date = DateTime.tryParse(value);
      if (date != null) return date.toLocal();
      try {
        return Jiffy.parse(
          value,
          pattern: 'EEE, dd MMM yyyy HH:mm:ss Z',
        ).dateTime.toLocal();
      } catch (_) {
        // A malformed date should not prevent the release from being shown.
      }
    }
    return null;
  }

  String? _nonEmpty(String? value) {
    var text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  Future<void> _download() async {
    var magnet = magnetUri;
    var torrent = torrentUrl;
    if (_downloading.value || (magnet == null && torrent == null)) return;
    _downloading.value = true;
    updateKeepAlive();
    try {
      var saveDir = await pickDownloadDirectory();
      if (!mounted || saveDir == null || saveDir.isEmpty) return;

      if (magnet != null) {
        await ref
            .read(btDownloadStoreProvider.notifier)
            .addMagnet(
              uri: magnet,
              savePath: saveDir,
              displayName: releaseTitle,
            );
      } else {
        var torrentPath = await BTDownloadTool().downloadRssTorrent(
          torrent!,
          releaseTitle,
          context: context,
        );
        if (!mounted || torrentPath.isEmpty) return;
        await ref
            .read(btDownloadStoreProvider.notifier)
            .addTorrentFile(
              torrentPath: torrentPath,
              savePath: saveDir,
              displayName: releaseTitle,
            );
      }
      if (mounted) await BtInfobar.success(context, '下载任务已添加');
    } catch (error) {
      if (mounted) await BtInfobar.error(context, error.toString());
    } finally {
      if (mounted) {
        _downloading.value = false;
        updateKeepAlive();
      }
    }
  }

  Widget _buildHeading(String title, Color secondaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _text(
          title,
          maxLines: 2,
          tooltip: [
            title,
            if (metadata?.animeTitleEnglish != null)
              metadata!.animeTitleEnglish!,
          ].join('\n'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        if (title != releaseTitle) ...[
          const SizedBox(height: 5),
          _text(
            releaseTitle,
            maxLines: 3,
            style: TextStyle(fontSize: 12, color: secondaryColor, height: 1.4),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoTags(String specifications) {
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          if (metadata?.groupName != null)
            AnibtTagChip(
              label: metadata!.groupName!,
              icon: FluentIcons.contact,
              maxWidth: constraints.maxWidth,
              tooltip: '打开 ${metadata!.groupName!} 字幕组主页',
              onPressed: groupUrl == null ? null : _openGroup,
            ),
          if (specifications.isNotEmpty)
            AnibtTagChip(
              label: specifications,
              icon: FluentIcons.video,
              maxWidth: constraints.maxWidth,
            ),
          if (metadata?.resolution != null)
            _filterTag(
              AnibtTagKind.resolution,
              metadata!.resolution!,
              constraints.maxWidth,
              icon: FluentIcons.video,
            ),
          for (var language in metadata?.languages ?? <String>[])
            _filterTag(
              AnibtTagKind.language,
              language.toUpperCase(),
              constraints.maxWidth,
              label: _languageLabel(language),
              icon: FluentIcons.locale_language,
            ),
          if (metadata?.subtitle != null)
            _filterTag(
              AnibtTagKind.subtitle,
              metadata!.subtitle!.toUpperCase(),
              constraints.maxWidth,
              label: subtitleLabel,
              highlighted: true,
            ),
          if (metadata?.format != null)
            _filterTag(
              AnibtTagKind.format,
              metadata!.format!.toUpperCase(),
              constraints.maxWidth,
            ),
          if (metadata?.customTags.isNotEmpty ?? false)
            AnibtTagChip(
              label: metadata!.customTags.join(' · '),
              icon: FluentIcons.tag,
              maxWidth: constraints.maxWidth,
            ),
        ],
      ),
    );
  }

  Future<void> _openLink() async {
    var url = releaseUrl;
    if (url != null) await launchUrlString(url);
  }

  Future<void> _openGroup() async {
    var url = groupUrl;
    if (url != null) await launchUrlString(url);
  }

  void _openSubject() {
    var id = metadata?.bgmId;
    if (id == null || id <= 0) return;
    ref
        .read(navStoreProvider.notifier)
        .addNavItemB(subject: id, paneTitle: metadata?.animeTitle, type: '动画');
  }

  String _languageLabel(String value) =>
      AnibtFilters.languageLabels[value.toUpperCase()] ?? value;

  String? get subtitleLabel =>
      AnibtFilters.subtitleLabels[metadata?.subtitle?.toUpperCase()] ??
      metadata?.subtitle;

  Widget _text(
    String value, {
    int maxLines = 1,
    required TextStyle style,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? value,
      child: Text(
        value,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _filterTag(
    AnibtTagKind kind,
    String value,
    double maxWidth, {
    String? label,
    IconData? icon,
    bool highlighted = false,
  }) {
    var tag = AnibtTagSelection(kind, value);
    var selected = widget.filters.includesTag(tag);
    var supported = switch (kind) {
      AnibtTagKind.resolution => AnibtFilters.resolutions.contains(value),
      AnibtTagKind.language => AnibtFilters.languageLabels.containsKey(value),
      AnibtTagKind.subtitle => AnibtFilters.subtitleLabels.containsKey(value),
      AnibtTagKind.format => AnibtFilters.formats.contains(value),
    };
    return AnibtTagChip(
      label: label ?? value,
      icon: icon,
      selected: selected,
      highlighted: highlighted,
      maxWidth: maxWidth,
      tooltip: supported
          ? '${selected ? '取消筛选' : '筛选'} ${label ?? value}'
          : (label ?? value),
      onPressed: supported && widget.onTagSelected != null
          ? () => widget.onTagSelected!(tag)
          : null,
    );
  }

  Future<void> _showDetails() async {
    var size = contentLength;
    var release = RssReleaseData(
      item: item,
      title: releaseTitle,
      categories: item.categories
          .map((category) => category.value?.trim())
          .whereType<String>()
          .where((text) => text.isNotEmpty)
          .toList(),
      tags: [
        ?metadata?.episodeLabel,
        ?metadata?.version,
        ?metadata?.resolution,
        ...?metadata?.languages.map(_languageLabel),
        ?subtitleLabel,
        ?metadata?.format,
        ...?metadata?.customTags,
      ],
      author: metadata?.groupName ?? item.author,
      sizeLabel: size == null ? null : filesize(size),
      publishedAt: publishedAt,
      downloadUrl: magnetUri ?? torrentUrl,
      detailUrl: releaseUrl,
    );
    _showingDetails = true;
    updateKeepAlive();
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        dismissWithEsc: true,
        builder: (dialogContext) => RssReleaseDetailDialog(
          release: release,
          markdownDescription: true,
          baseUrl: Uri.tryParse(releaseUrl ?? AnibtAPI.baseUrl),
          onTapUrl: _openDescriptionLink,
          actions: Row(
            children: [
              const Spacer(),
              _buildActions(
                FluentTheme.of(dialogContext).accentColor,
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
    } finally {
      if (mounted) {
        _showingDetails = false;
        updateKeepAlive();
      }
    }
  }

  Future<bool> _openDescriptionLink(String url) async {
    var uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return false;
    }
    try {
      var opened = await launchUrlString(url);
      if (!opened && mounted) await BtInfobar.error(context, '无法打开链接');
      return opened;
    } catch (error) {
      if (mounted) await BtInfobar.error(context, error.toString());
      return false;
    }
  }

  Widget _buildActions(Color accentColor, {bool includeDetails = true}) {
    var bgmId = metadata?.bgmId;
    return ValueListenableBuilder<bool>(
      valueListenable: _downloading,
      builder: (context, downloading, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (includeDetails)
            Tooltip(
              message: '查看资源详情',
              child: IconButton(
                icon: Icon(FluentIcons.info, size: 16, color: accentColor),
                onPressed: _showDetails,
              ),
            ),
          Tooltip(
            message: downloading
                ? '正在添加下载任务'
                : magnetUri == null
                ? '种子下载'
                : '磁力下载',
            child: IconButton(
              icon: downloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  : Icon(FluentIcons.download, size: 16, color: accentColor),
              onPressed:
                  downloading || (magnetUri == null && torrentUrl == null)
                  ? null
                  : _download,
            ),
          ),
          if (bgmId != null && bgmId > 0)
            Tooltip(
              message: '打开番剧详情',
              child: IconButton(
                icon: Icon(
                  FluentIcons.open_in_new_tab,
                  size: 16,
                  color: accentColor,
                ),
                onPressed: _openSubject,
              ),
            ),
          Tooltip(
            message: '在浏览器打开资源页面',
            child: IconButton(
              icon: Icon(FluentIcons.edge_logo, size: 16, color: accentColor),
              onPressed: releaseUrl == null ? null : _openLink,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var theme = FluentTheme.of(context);
    var accentColor = theme.accentColor;
    var secondaryColor = BTColors.textSecondary(context);
    var title = metadata?.animeTitle ?? releaseTitle;
    var specifications = [
      ?metadata?.episodeLabel,
      if (metadata?.version != null) metadata!.version!,
    ].join(' · ');
    var date = publishedAt;
    var time = date == null
        ? '时间未知'
        : Jiffy.parseFromDateTime(date).format(pattern: 'MM-dd HH:mm');
    var size = contentLength;

    var content = LayoutBuilder(
      builder: (context, constraints) {
        var heading = _buildHeading(title, secondaryColor);
        var tags = _buildInfoTags(specifications);
        var timestamp = _text(
          time,
          tooltip: date?.toString(),
          style: TextStyle(fontSize: 12, color: secondaryColor),
        );
        var fileSize = AnibtTagChip(
          label: size == null ? '大小未知' : filesize(size),
          highlighted: size != null,
          tooltip: size == null ? '大小未知' : '$size 字节',
        );

        if (constraints.maxWidth >= 600) {
          return Table(
            columnWidths: const {
              0: FlexColumnWidth(),
              1: FixedColumnWidth(174),
            },
            children: [
              TableRow(
                children: [
                  heading,
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        timestamp,
                        const SizedBox(height: 5),
                        fileSize,
                      ],
                    ),
                  ),
                ],
              ),
              TableRow(
                children: [
                  TableCell(
                    verticalAlignment: TableCellVerticalAlignment.bottom,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: tags,
                    ),
                  ),
                  TableCell(
                    verticalAlignment: TableCellVerticalAlignment.bottom,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, top: 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _buildActions(accentColor),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            heading,
            const SizedBox(height: 8),
            tags,
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [timestamp, fileSize],
                  ),
                ),
                const SizedBox(width: 8),
                _buildActions(accentColor),
              ],
            ),
          ],
        );
      },
    );

    return RssReleaseSurface(child: content);
  }
}
