// Dart imports:
import 'dart:async';
import 'dart:convert';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../models/rss/anibt_filters.dart';
import '../../models/rss/rss.dart';
import '../../request/rss/anibt_api.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import 'anibt_filter_dialog.dart';
import 'rss_anibt_card_fluent.dart';

class RbpAnibtWidget extends StatefulWidget {
  const RbpAnibtWidget({super.key});

  @override
  State<RbpAnibtWidget> createState() => _RbpAnibtState();
}

class _RbpAnibtState extends State<RbpAnibtWidget>
    with AutomaticKeepAliveClientMixin {
  final AnibtAPI anibtAPI = AnibtAPI();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  AnibtFilters _filters = AnibtFilters();
  List<RssItem> rssItems = [];
  List<RssItem> _visibleItems = [];
  bool _refreshing = false;
  bool _loaded = false;
  bool _loadFailed = false;
  bool _localFallback = false;

  @override
  bool get wantKeepAlive => true;

  void _updateVisibleItems() {
    _visibleItems = _localFallback
        ? _filters.applyToFeedWindow(rssItems)
        : _filters.applyLocal(rssItems);
  }

  bool get _usesLocalResults => _localFallback || _filters.usesLocalResults;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.delayed(Duration.zero, () => refresh(notify: false)),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> refresh({bool notify = true}) async {
    if (!mounted || _refreshing) return;
    setState(() => _refreshing = true);
    var resGet = await anibtAPI.getMagnetsRSS(filters: _filters);
    if (!mounted) return;
    var localFallback = false;
    if (resGet.code == 503 &&
        resGet.data is String &&
        (resGet.data as String).contains('Search backend unavailable') &&
        _filters.queryParameters.isNotEmpty) {
      resGet = await anibtAPI.getMagnetsRSS();
      if (!mounted) return;
      localFallback = resGet.code == 0 && resGet.data != null;
    }
    var success = resGet.code == 0 && resGet.data != null;
    setState(() {
      _refreshing = false;
      _loaded = true;
      _loadFailed = !success;
      _localFallback = localFallback;
      if (success) {
        rssItems = resGet.data!;
        _updateVisibleItems();
      }
    });
    if (!success) {
      await showRespErr(resGet, context);
      return;
    }
    if (notify) await BtInfobar.success(context, '已刷新 AniBT 列表');
  }

  Future<void> _applyFilters(AnibtFilters filters) async {
    if (_refreshing) return;
    if (utf8.encode(filters.query.trim()).length > 160) {
      await BtInfobar.warn(context, '搜索关键词过长，请缩短后重试');
      return;
    }
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    var onlyLocalChange =
        _loaded &&
        !_loadFailed &&
        jsonEncode(filters.queryParameters) ==
            jsonEncode(_filters.queryParameters);
    setState(() {
      _filters = filters;
      if (onlyLocalChange) _updateVisibleItems();
    });
    if (onlyLocalChange) return;
    await refresh(notify: false);
  }

  Future<void> _search() =>
      _applyFilters(_filters.copyWith(query: _searchController.text.trim()));

  Future<void> _reset() async {
    _searchController.clear();
    await _applyFilters(AnibtFilters());
  }

  Future<void> _showFilters() async {
    var filters = await showDialog<AnibtFilters>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AnibtFilterDialog(filters: _filters),
    );
    if (!mounted || filters == null) return;
    await _applyFilters(filters.copyWith(query: _searchController.text.trim()));
  }

  Widget buildTitle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        IconButton(
          icon: Image.asset(
            'assets/images/platforms/anibt-logo.png',
            height: 30,
            fit: BoxFit.contain,
            semanticLabel: 'AniBT',
          ),
          onPressed: () async {
            await launchUrlString('${AnibtAPI.baseUrl}/magnets');
          },
        ),
        SizedBox(width: 10),
        Tooltip(
          message: '刷新 AniBT',
          child: IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: ProgressRing(strokeWidth: 2),
                  )
                : const Icon(FluentIcons.refresh),
            onPressed: _refreshing ? null : refresh,
          ),
        ),
        Tooltip(
          message: '打开 RSS 源',
          child: IconButton(
            icon: const Icon(FluentIcons.subscribe),
            onPressed: () async =>
                await launchUrlString('${AnibtAPI.baseUrl}/magnets'),
          ),
        ),
        const Spacer(),
        if (_loaded && !_loadFailed && !_refreshing)
          Text(
            _usesLocalResults
                ? '${_visibleItems.length} / ${rssItems.length} 条资源'
                : '${rssItems.length} 条资源',
            style: const TextStyle(fontSize: 12),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchBox() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) => TextBox(
        controller: _searchController,
        placeholder: '搜索番剧、发布标题或字幕组...',
        enabled: !_refreshing,
        onSubmitted: (_) async => await _search(),
        prefix: const Padding(
          padding: EdgeInsets.only(left: 10),
          child: Icon(FluentIcons.search, size: 14),
        ),
        suffix: value.text.isEmpty
            ? null
            : Tooltip(
                message: '清除搜索',
                child: IconButton(
                  icon: const Icon(FluentIcons.clear, size: 12),
                  onPressed: _refreshing
                      ? null
                      : () async {
                          _searchController.clear();
                          if (_filters.query.isNotEmpty) await _search();
                        },
                ),
              ),
      ),
    );
  }

  Widget _buildSearchBar() {
    var actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton(
          onPressed: _refreshing ? null : _search,
          child: const Text('搜索'),
        ),
        Button(
          onPressed: _refreshing ? null : _showFilters,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(FluentIcons.filter, size: 14),
              const SizedBox(width: 6),
              Text(_filters.tagCount == 0 ? '筛选' : '筛选 (${_filters.tagCount})'),
            ],
          ),
        ),
        if (!_filters.isDefault)
          Button(
            onPressed: _refreshing ? null : _reset,
            child: const Text('重置'),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 600) {
              return Row(
                children: [
                  Expanded(child: _buildSearchBox()),
                  const SizedBox(width: 8),
                  actions,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_buildSearchBox(), const SizedBox(height: 8), actions],
            );
          },
        ),
        if (!_filters.isDefault) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _filters.labels.map((label) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: FluentTheme.of(
                    context,
                  ).accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(label, style: const TextStyle(fontSize: 12)),
              );
            }).toList(),
          ),
        ],
        if (_usesLocalResults) ...[
          const SizedBox(height: 6),
          Text(
            _localFallback
                ? 'AniBT 搜索服务暂不可用：已在最新 RSS 结果内筛选（最多 100 条）'
                : '字幕筛选与集数排序范围：当前 RSS 返回的最多 100 条资源',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget buildContent() {
    var items = _visibleItems;
    if (_refreshing || !_loaded || _loadFailed || items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_refreshing || !_loaded) ...[
              const ProgressRing(),
              SizedBox(height: 20),
              const Text('正在加载数据...'),
            ] else ...[
              Text(
                _loadFailed
                    ? '加载失败，请点击刷新重试'
                    : (_filters.isDefault ? '暂无 RSS 数据' : '未找到匹配的资源'),
              ),
              if (!_loadFailed && !_filters.isDefault) ...[
                const SizedBox(height: 12),
                Button(onPressed: _reset, child: const Text('重置搜索与筛选')),
              ],
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      key: const PageStorageKey('anibt-rss-list'),
      controller: _scrollController,
      // Build and repaint only viewport rows and the nearby scroll cache.
      addRepaintBoundaries: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => RssAnibtCardFluent(
        key: ValueKey(
          items[index].guid ??
              items[index].anibt?.releasePageUrl ??
              items[index].link ??
              items[index],
        ),
        item: items[index],
        filters: _filters,
        onTagSelected: (tag) =>
            unawaited(_applyFilters(_filters.toggleTag(tag))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage.withPadding(
      padding: EdgeInsets.zero,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildTitle(),
            const SizedBox(height: 8),
            _buildSearchBar(),
          ],
        ),
      ),
      content: buildContent(),
    );
  }
}
