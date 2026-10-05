// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/services/download_service.dart';
import '../../core/theme/bt_theme.dart';
import '../../models/rss/rss.dart';
import '../../request/mikan/mikan_api.dart';
import '../../store/bt_download_store.dart';
import '../../ui/bt_infobar.dart';
import '../../ui/bt_select.dart';
import '../../widgets/rss/rss_release_data.dart';
import '../../widgets/rss/rss_release_detail_dialog.dart';
import '../../widgets/rss/rss_release_surface.dart';

/// Mikan / Comicat 共用资源列表，按可用字段调整每行内容。
class RssReleaseList extends ConsumerStatefulWidget {
  final Widget title;
  final List<Widget> leadingControls;
  final List<Widget> sourceControls;

  /// 由来源页面提供搜索控件，以支持站点 RSS 搜索。
  final Widget? searchControl;

  /// 站点已完成筛选时，直接展示返回的资源。
  final bool useLocalFilters;
  final bool refreshEnabled;
  final List<RssItem> items;
  final RssReleaseSource source;
  final bool refreshing;
  final bool loaded;
  final bool loadFailed;
  final Future<void> Function() onRefresh;

  const RssReleaseList({
    super.key,
    required this.title,
    this.leadingControls = const [],
    this.sourceControls = const [],
    this.searchControl,
    this.useLocalFilters = true,
    this.refreshEnabled = true,
    required this.items,
    required this.source,
    required this.refreshing,
    required this.loaded,
    required this.loadFailed,
    required this.onRefresh,
  });

  @override
  ConsumerState<RssReleaseList> createState() => _RssReleaseListState();
}

class _RssReleaseListState extends ConsumerState<RssReleaseList> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<Set<String>> _downloading = ValueNotifier({});
  List<RssReleaseData> _releases = [];
  List<String> _categories = [];
  String? _category;

  @override
  void initState() {
    super.initState();
    _parseItems();
  }

  @override
  void didUpdateWidget(RssReleaseList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items) ||
        oldWidget.source != widget.source) {
      _parseItems();
    }
  }

  void _parseItems() {
    _releases = widget.items
        .map((item) => RssReleaseData.fromItem(item, widget.source))
        .toList();
    _categories = _releases.expand((item) => item.categories).toSet().toList()
      ..sort();
    if (!_categories.contains(_category)) _category = null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _downloading.dispose();
    super.dispose();
  }

  String _sourceUrl(String url) => widget.source == RssReleaseSource.mikan
      ? BtrMikanApi.rewriteUrl(url)
      : url;

  Future<void> _download(RssReleaseData release) async {
    if (!mounted ||
        !release.canDownload ||
        _downloading.value.contains(release.key)) {
      return;
    }
    _downloading.value = {..._downloading.value, release.key};
    try {
      var directory = await getDirectoryPath();
      if (!mounted || directory == null || directory.isEmpty) return;
      var downloadUrl = _sourceUrl(release.downloadUrl!);
      var store = ref.read(btDownloadStoreProvider.notifier);
      if (Uri.parse(downloadUrl).scheme == 'magnet') {
        await store.addMagnet(
          uri: downloadUrl,
          savePath: directory,
          displayName: release.title,
        );
      } else {
        var torrent = await BTDownloadTool().downloadRssTorrent(
          downloadUrl,
          release.title,
          context: context,
        );
        if (!mounted || torrent.isEmpty) return;
        await store.addTorrentFile(
          torrentPath: torrent,
          savePath: directory,
          displayName: release.title,
        );
      }
      if (mounted) await BtInfobar.success(context, '下载任务已添加');
    } catch (error) {
      if (mounted) await BtInfobar.error(context, error.toString());
    } finally {
      if (mounted) {
        _downloading.value = {..._downloading.value}..remove(release.key);
      }
    }
  }

  Future<void> _open(RssReleaseData release) async {
    if (release.detailUrl == null) return;
    try {
      var opened = await launchUrlString(_sourceUrl(release.detailUrl!));
      if (!opened && mounted) await BtInfobar.error(context, '无法打开资源详情');
    } catch (error) {
      if (mounted) await BtInfobar.error(context, error.toString());
    }
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() => _category = null);
  }

  @override
  Widget build(BuildContext context) {
    var filtered = widget.useLocalFilters
        ? filterRssReleases(
            _releases,
            query: _searchController.text,
            category: _category,
          )
        : _releases;
    return Column(
      children: [
        _buildToolbar(context, filtered.length),
        if (widget.refreshing && _releases.isNotEmpty) const ProgressBar(),
        if (widget.loadFailed && _releases.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: InfoBar(
              title: const Text('刷新失败，当前显示上次加载的资源'),
              severity: InfoBarSeverity.warning,
              action: Button(
                onPressed: widget.refreshing ? null : widget.onRefresh,
                child: const Text('重试'),
              ),
            ),
          ),
        Expanded(
          child: ColoredBox(
            color: BTColors.surfaceSecondary(context),
            child: filtered.isEmpty
                ? _buildEmptyState(context)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildRow(context, filtered[index]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          var search =
              widget.searchControl ??
              TextBox(
                controller: _searchController,
                placeholder: '搜索资源标题、发布者或格式',
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Icon(
                    FluentIcons.search,
                    size: 14,
                    color: BTColors.textTertiary(context),
                  ),
                ),
                suffix: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(FluentIcons.clear, size: 12),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                onChanged: (_) => setState(() {}),
              );
          var controls = Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...widget.sourceControls,
              if (widget.useLocalFilters && _categories.isNotEmpty)
                SizedBox(
                  width: 136,
                  child: BtSelect<String>(
                    value: _category ?? '',
                    isExpanded: true,
                    items: [
                      const ComboBoxItem(value: '', child: Text('全部分类')),
                      ..._categories.map(
                        (category) => ComboBoxItem(
                          value: category,
                          child: Text(category),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _category = value == '' ? null : value;
                    }),
                  ),
                ),
            ],
          );
          var feedControls = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...widget.leadingControls,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  widget.useLocalFilters
                      ? '$count / ${_releases.length} 条资源'
                      : '$count 条资源',
                  style: BTTypography.caption(context),
                ),
              ),
              if (widget.useLocalFilters &&
                  (_category != null || _searchController.text.isNotEmpty))
                Tooltip(
                  message: '清除搜索与分类筛选',
                  child: IconButton(
                    icon: const Icon(FluentIcons.clear, size: 12),
                    onPressed: _clearFilters,
                  ),
                ),
            ],
          );
          var refresh = Tooltip(
            message: widget.source == RssReleaseSource.mikan
                ? '刷新 Mikan'
                : '刷新 Comicat',
            child: IconButton(
              icon: widget.refreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  : const Icon(FluentIcons.refresh, size: 15),
              onPressed: widget.refreshing || !widget.refreshEnabled
                  ? null
                  : widget.onRefresh,
            ),
          );
          if (constraints.maxWidth < 840) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: widget.title),
                    refresh,
                  ],
                ),
                const SizedBox(height: 12),
                search,
                const SizedBox(height: 12),
                feedControls,
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: controls),
              ],
            );
          }
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: widget.title),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: (constraints.maxWidth * 0.42).clamp(320.0, 520.0),
                    child: search,
                  ),
                  const SizedBox(width: 12),
                  refresh,
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: feedControls),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: controls),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRow(BuildContext context, RssReleaseData release) {
    var timestamp = release.publishedAt == null
        ? null
        : DateFormat('yyyy-MM-dd HH:mm').format(release.publishedAt!.toLocal());
    var showCover =
        widget.source == RssReleaseSource.comicat && release.imageUrl != null;
    return RssReleaseSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showCover) ...[
                _buildThumbnail(context, release),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tooltip(
                      message: release.title,
                      child: Text(
                        release.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: BTTypography.bodyStrong(context),
                      ),
                    ),
                    if (release.categories.isNotEmpty ||
                        release.tags.isNotEmpty ||
                        release.author != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ...release.categories.map(
                            (text) => _buildTag(context, text),
                          ),
                          ...release.tags.map(
                            (text) => _buildTag(context, text),
                          ),
                          if (release.author != null)
                            Text(
                              '发布者 ${release.author}',
                              style: BTTypography.caption(context),
                            ),
                        ],
                      ),
                    ],
                    if (release.summary != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        release.summary!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BTTypography.caption(context),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    if (release.sizeLabel != null)
                      Text(
                        release.sizeLabel!,
                        style: BTTypography.caption(context),
                      ),
                    if (timestamp != null)
                      Text(timestamp, style: BTTypography.caption(context)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildActions(context, release),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.smallBR,
      ),
      child: Text(label, style: BTTypography.caption(context)),
    );
  }

  Widget _buildThumbnail(BuildContext context, RssReleaseData release) {
    var category = release.categories.join(' ');
    var icon = category.contains('音乐') || category.contains('音樂')
        ? MdiIcons.music
        : category.contains('漫画') || category.contains('漫畫')
        ? MdiIcons.bookOpenPageVariant
        : category.contains('游戏') || category.contains('遊戲')
        ? MdiIcons.gamepadVariant
        : MdiIcons.video;
    Widget placeholder() => Container(
      color: BTColors.surfaceSecondary(context),
      alignment: Alignment.center,
      child: Icon(icon, size: 24, color: BTColors.textTertiary(context)),
    );
    return ClipRRect(
      borderRadius: BTRadius.smallBR,
      child: SizedBox(
        width: 48,
        height: 64,
        child: release.imageUrl == null
            ? placeholder()
            : CachedNetworkImage(
                imageUrl: release.imageUrl!,
                fit: BoxFit.cover,
                memCacheWidth: (48 * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                placeholder: (_, _) => placeholder(),
                errorWidget: (_, _, _) => placeholder(),
              ),
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    RssReleaseData release, {
    bool includeDetails = true,
  }) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _downloading,
      builder: (context, downloadingKeys, _) {
        var downloading = downloadingKeys.contains(release.key);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (includeDetails &&
                widget.source == RssReleaseSource.comicat) ...[
              Tooltip(
                message: '查看资源详情',
                child: IconButton(
                  icon: const Icon(
                    FluentIcons.info,
                    size: 16,
                    semanticLabel: '查看详情',
                  ),
                  onPressed: () => _showReleaseDetails(release),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Tooltip(
              message: downloading
                  ? '正在添加下载任务'
                  : release.canDownload
                  ? '下载资源'
                  : '该资源没有可用的种子或磁力链接',
              child: IconButton(
                onPressed: release.canDownload && !downloading
                    ? () => _download(release)
                    : null,
                icon: downloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    : const Icon(
                        FluentIcons.download,
                        size: 16,
                        semanticLabel: '下载',
                      ),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: '在浏览器打开资源页面',
              child: IconButton(
                icon: const Icon(
                  FluentIcons.open_in_new_tab,
                  size: 16,
                  semanticLabel: '在浏览器打开',
                ),
                onPressed: release.detailUrl == null
                    ? null
                    : () => _open(release),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showReleaseDetails(RssReleaseData release) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      dismissWithEsc: true,
      builder: (dialogContext) => RssReleaseDetailDialog(
        release: release,
        onTapUrl: _openDescriptionLink,
        actions: Row(
          children: [
            const Spacer(),
            _buildActions(dialogContext, release, includeDetails: false),
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

  Widget _buildEmptyState(BuildContext context) {
    var initialLoad = !widget.loaded && _releases.isEmpty;
    var loading = widget.refreshing || initialLoad;
    var filtered = _releases.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const ProgressRing()
          else
            Icon(
              filtered ? FluentIcons.search : MdiIcons.rss,
              size: 36,
              color: BTColors.textTertiary(context),
            ),
          const SizedBox(height: 12),
          Text(
            loading
                ? '正在加载资源…'
                : filtered
                ? '没有匹配的资源'
                : widget.loadFailed
                ? '资源加载失败'
                : '暂无 RSS 资源',
            style: BTTypography.subtitle(context),
          ),
          if (!loading) ...[
            const SizedBox(height: 8),
            Button(
              onPressed: filtered ? _clearFilters : widget.onRefresh,
              child: Text(filtered ? '清除筛选' : '重新加载'),
            ),
          ],
        ],
      ),
    );
  }
}
