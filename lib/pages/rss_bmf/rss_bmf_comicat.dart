// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../domain/rss/comicat_feed.dart';
import '../../models/rss/rss.dart';
import '../../request/rss/comicat_api.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/rss/rss_release_data.dart';
import 'rss_release_list.dart';

/// 负责 ComicatProject RSS 页面的显示
class RssBmfComicat extends StatefulWidget {
  /// 构造函数
  const RssBmfComicat({super.key});

  @override
  State<RssBmfComicat> createState() => _RssBmfComicatState();
}

/// ComicatRSS 页面状态
class _RssBmfComicatState extends State<RssBmfComicat>
    with AutomaticKeepAliveClientMixin {
  static const _defaultFeed = ComicatFeed.category(ComicatRssCategory.anime);

  /// 请求客户端
  final ComicatAPI comicatAPI = ComicatAPI();
  final TextEditingController _searchController = TextEditingController();
  ComicatFeed _feed = _defaultFeed;
  int _requestId = 0;

  /// RSS 数据
  List<RssItem> rssItems = [];
  bool _refreshing = false;
  bool _loaded = false;
  bool _loadFailed = false;

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// 初始化
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
    super.dispose();
  }

  /// 刷新数据
  Future<void> refresh({bool notify = true}) async {
    if (!mounted) return;
    var requestId = ++_requestId;
    setState(() {
      _refreshing = true;
      _loadFailed = false;
    });
    var resGet = await comicatAPI.getRSS(feed: _feed);
    if (!mounted || requestId != _requestId) return;
    var success = resGet.code == 0 && resGet.data != null;
    setState(() {
      _refreshing = false;
      _loaded = true;
      _loadFailed = !success;
      if (success) rssItems = resGet.data!;
    });
    if (!success) {
      await showRespErr(resGet, context);
      return;
    }
    if (notify) await BtInfobar.success(context, '已刷新 Comicat 列表');
  }

  Future<void> _applyFeed(ComicatFeed feed) async {
    if (!mounted) return;
    if (_feed.path != feed.path || _feed.isSearch != feed.isSearch) {
      setState(() {
        _feed = feed;
        rssItems = [];
        _loaded = false;
        _loadFailed = false;
      });
    }
    await refresh(notify: false);
  }

  Future<void> _search() async {
    var feed = ComicatFeed.search(_searchController.text);
    await _applyFeed(feed.isSearch ? feed : _defaultFeed);
  }

  Future<void> _selectCategory(ComicatRssCategory category) async {
    _searchController.clear();
    await _applyFeed(ComicatFeed.category(category));
  }

  Future<void> _clearSearch() async {
    _searchController.clear();
    if (_feed.isSearch) {
      await _applyFeed(_defaultFeed);
    }
  }

  Widget _buildSearch() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) => TextBox(
        controller: _searchController,
        placeholder: '搜索全站资源，多个关键词用空格或 + 分隔',
        textInputAction: TextInputAction.search,
        prefix: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Icon(
            FluentIcons.search,
            size: 14,
            color: BTColors.textTertiary(context),
          ),
        ),
        suffix: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value.text.isNotEmpty || _feed.isSearch)
              Tooltip(
                message: '清除搜索',
                child: IconButton(
                  icon: const Icon(FluentIcons.clear, size: 12),
                  onPressed: _clearSearch,
                ),
              ),
            Tooltip(
              message: '搜索 Comicat（Enter）',
              child: IconButton(
                icon: const Icon(FluentIcons.search, size: 14),
                onPressed: _search,
              ),
            ),
          ],
        ),
        onSubmitted: (_) => unawaited(_search()),
      ),
    );
  }

  /// 构建标题
  Widget buildTitle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Tooltip(
          message: '打开漫猫动漫',
          child: IconButton(
            icon: Image.asset(
              'assets/images/platforms/comicat-favicon.ico',
              width: 30,
              height: 30,
              fit: BoxFit.contain,
            ),
            onPressed: () async {
              await launchUrlString('https://comicat.org');
            },
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Comicat', style: BTTypography.title(context)),
              Text(
                _feed.isSearch
                    ? '全站搜索：${_feed.query}'
                    : '${_feed.category.label} · 最近发布的资源',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BTTypography.caption(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildContent() {
    return RssReleaseList(
      title: buildTitle(),
      searchControl: _buildSearch(),
      useLocalFilters: false,
      sourceControls: [
        for (var category in ComicatRssCategory.values)
          ToggleButton(
            checked: !_feed.isSearch && _feed.category == category,
            onChanged: (_) => unawaited(_selectCategory(category)),
            child: Text(category.label),
          ),
      ],
      items: rssItems,
      source: RssReleaseSource.comicat,
      refreshing: _refreshing,
      loaded: _loaded,
      loadFailed: _loadFailed,
      onRefresh: refresh,
    );
  }

  /// 构建函数
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(padding: EdgeInsets.zero, content: buildContent());
  }
}
