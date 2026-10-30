// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../controller/animegarden_controller.dart';
import '../../core/theme/bt_theme.dart';
import '../../domain/rss/animegarden_query.dart';
import '../../models/rss/animegarden_resource.dart';
import '../../pages/rss_bmf/rss_release_list.dart';
import '../../ui/bt_infobar.dart';
import '../../ui/bt_select.dart';
import 'rss_refresh_status.dart';
import 'rss_release_data.dart';

/// Full-site resource browsing, search and downloads.
class AnimeGardenBrowser extends StatefulWidget {
  const AnimeGardenBrowser({super.key});

  @override
  State<AnimeGardenBrowser> createState() => _AnimeGardenBrowserState();
}

class _AnimeGardenBrowserState extends State<AnimeGardenBrowser> {
  final _controller = AnimeGardenController();
  final _search = TextEditingController();
  final _fansub = TextEditingController();
  final _keywords = TextEditingController();
  final _exclude = TextEditingController();
  final _customType = TextEditingController();
  static const _typeOptions = ['动画', '漫画', '音乐', '游戏'];
  static const _customTypeOption = 'custom';
  String _type = '动画';
  final _scrollController = ScrollController();
  List<AnimeGardenResource>? _projectedResources;
  List<RssReleaseData> _releases = [];
  int _navigationGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_submit());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _search.dispose();
    _fansub.dispose();
    _keywords.dispose();
    _exclude.dispose();
    _customType.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _terms(String value) => value.split(RegExp(r'[,，\n]'));

  Future<void> _submit() async {
    var type = _type == _customTypeOption ? _customType.text.trim() : _type;
    if (_type == _customTypeOption && type.isEmpty) {
      await BtInfobar.warn(context, '请输入资源类型名称');
      return;
    }
    await _loadPage(
      () => _controller.search(
        AnimeGardenQuery(
          type: type,
          search: _search.text.trim(),
          fansub: _fansub.text.trim(),
          keywords: _terms(_keywords.text),
          exclude: _terms(_exclude.text),
        ),
      ),
    );
  }

  Future<void> _loadPage(Future<void> Function() action) async {
    var generation = ++_navigationGeneration;
    await action();
    if (!mounted ||
        generation != _navigationGeneration ||
        _controller.loading ||
        _controller.error != null) {
      return;
    }
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  List<RssReleaseData> _pageReleases() {
    if (!identical(_projectedResources, _controller.resources)) {
      _projectedResources = _controller.resources;
      _releases = _controller.resources
          .map(RssReleaseData.fromAnimeGarden)
          .toList();
    }
    return _releases;
  }

  Widget _action(
    String label,
    IconData icon,
    VoidCallback? action, {
    bool loading = false,
  }) => Tooltip(
    message: label,
    child: IconButton(
      icon: loading
          ? const SizedBox(
              width: 15,
              height: 15,
              child: ProgressRing(strokeWidth: 2),
            )
          : Icon(icon, size: 15, semanticLabel: label),
      onPressed: action,
    ),
  );

  Widget _field(TextEditingController controller, String label) => TextBox(
    controller: controller,
    placeholder: label,
    onSubmitted: (_) => unawaited(_submit()),
  );

  Widget _typeField() {
    var select = Tooltip(
      message: '资源类型',
      child: BtSelect<String>(
        value: _type,
        isExpanded: true,
        items: [
          const ComboBoxItem(value: '', child: Text('全部类型')),
          for (var type in _typeOptions)
            ComboBoxItem(value: type, child: Text(type)),
          const ComboBoxItem(value: _customTypeOption, child: Text('自定义…')),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => _type = value);
          if (value != _customTypeOption) unawaited(_submit());
        },
      ),
    );
    if (_type != _customTypeOption) return select;
    return Row(
      children: [
        Expanded(child: select),
        const SizedBox(width: 8),
        Expanded(child: _field(_customType, '类型名称')),
      ],
    );
  }

  Widget _pagination(AnimeGardenController state) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _action(
        state.page == 1 ? '已是第一页' : '上一页',
        FluentIcons.chevron_left,
        state.canGoPrevious
            ? () => unawaited(_loadPage(state.previousPage))
            : null,
        loading: state.pendingPage == state.page - 1,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('第 ${state.page} 页'),
      ),
      _action(
        state.complete ? '已是最后一页' : '下一页',
        FluentIcons.chevron_right,
        state.canGoNext ? () => unawaited(_loadPage(state.nextPage)) : null,
        loading: state.pendingPage == state.page + 1,
      ),
      if (state.failedPage != null)
        _action(
          '重试第 ${state.failedPage} 页',
          FluentIcons.refresh,
          () => unawaited(_loadPage(state.retry)),
        ),
    ],
  );

  Widget _header(AnimeGardenController state) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
    child: LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        double width(double preferred) =>
            preferred.clamp(0.0, constraints.maxWidth);
        Widget headerRow(Widget left, Widget right, double rightWidth) {
          if (constraints.maxWidth >= rightWidth + 24 + 280) {
            return Row(
              children: [
                Expanded(child: left),
                const SizedBox(width: 24),
                SizedBox(width: rightWidth, child: right),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              const SizedBox(height: gap),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(width: width(rightWidth), child: right),
              ),
            ],
          );
        }

        var fieldHeight = MediaQuery.textScalerOf(context).scale(14) + 20;
        var title = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/platforms/animegarden-favicon.png',
              width: 22,
              height: 22,
              fit: BoxFit.contain,
              semanticLabel: 'Anime Garden',
            ),
            const SizedBox(width: 8),
            Text('Anime Garden', style: BTTypography.bodyStrong(context)),
          ],
        );
        var actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _action(
              '搜索 Anime Garden',
              FluentIcons.search,
              () => unawaited(_submit()),
            ),
            _action(
              '刷新当前页',
              FluentIcons.refresh,
              state.loading ? null : () => unawaited(_loadPage(state.refresh)),
              loading: state.loading,
            ),
            _action('重置搜索与筛选', FluentIcons.clear, () {
              _search.clear();
              _fansub.clear();
              _keywords.clear();
              _exclude.clear();
              _customType.clear();
              setState(() => _type = '动画');
              unawaited(_submit());
            }),
            _action(
              '打开 Anime Garden 网站',
              FluentIcons.globe,
              () => unawaited(launchUrlString('https://animes.garden')),
            ),
          ],
        );
        var status = Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Tooltip(
              message: state.query.type.isEmpty ? '全部类型' : state.query.type,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 160),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BTColors.surfaceSecondary(context),
                  borderRadius: BTRadius.smallBR,
                ),
                child: Text(
                  state.query.type.isEmpty ? '全部类型' : state.query.type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BTTypography.caption(context),
                ),
              ),
            ),
            Text(
              '${state.resources.length} 条资源 · 每页 ${state.query.pageSize} 条',
              style: BTTypography.caption(context),
            ),
            RssRefreshStatus(lastUpdated: state.lastUpdated),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            headerRow(
              Wrap(
                spacing: 16,
                runSpacing: gap,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [title, if (state.page > 0) _pagination(state)],
              ),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: fieldHeight,
                      child: _field(_search, '搜索资源标题'),
                    ),
                  ),
                  const SizedBox(width: gap),
                  actions,
                ],
              ),
              480,
            ),
            const SizedBox(height: gap),
            headerRow(
              status,
              Wrap(
                alignment: WrapAlignment.end,
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var (preferredWidth, field) in [
                    (_type == _customTypeOption ? 280.0 : 128.0, _typeField()),
                    (160.0, _field(_fansub, '字幕组名称')),
                    (176.0, _field(_keywords, '包含词（逗号分隔）')),
                    (176.0, _field(_exclude, '排除词（逗号分隔）')),
                  ])
                    SizedBox(
                      width: width(preferredWidth),
                      height: fieldHeight,
                      child: field,
                    ),
                ],
              ),
              _type == _customTypeOption ? 816 : 664,
            ),
          ],
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      var state = _controller;
      return Column(
        children: [
          Expanded(
            child: RssReleaseList(
              title: const Text('Anime Garden'),
              toolbar: _header(state),
              items: const [],
              releases: _pageReleases(),
              scrollController: _scrollController,
              source: RssReleaseSource.animegarden,
              useLocalFilters: false,
              isSearch: true,
              refreshing: state.loading,
              loaded: state.loaded,
              loadFailed: state.error != null,
              lastUpdated: state.lastUpdated,
              onRefresh: () => _loadPage(state.refresh),
              onRetry: () => _loadPage(state.retry),
              failureMessage: state.page > 0 && state.failedPage != null
                  ? '第 ${state.failedPage} 页加载失败，仍显示第 ${state.page} 页'
                  : null,
            ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(state.error!),
            ),
        ],
      );
    },
  );
}
