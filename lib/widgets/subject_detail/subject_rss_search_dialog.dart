// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// Project imports:
import '../../core/constants/app_constants.dart';
import '../../core/services/download_directory.dart';
import '../../core/services/download_service.dart';
import '../../core/utils/tool_func.dart';
import '../../models/app/rss_selection_behavior.dart';
import '../../models/mikan/mikan_model.dart';
import '../../models/rss/anibt_filters.dart';
import '../../models/rss/anibt_search.dart';
import '../../providers/bmf_providers.dart';
import '../../request/mikan/mikan_api.dart';
import '../../request/rss/anibt_api.dart';
import '../../store/bt_download_store.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../rss/anibt_tag_chip.dart';

enum _RssSearchSource { mikan, anibt }

class _RssSearchSelection {
  final _RssSearchSource source;
  final String animeId;
  final String title;
  final String rss;
  final String? groupId;
  final String? groupName;

  const _RssSearchSelection({
    required this.source,
    required this.animeId,
    required this.title,
    required this.rss,
    this.groupId,
    this.groupName,
  });

  String get label => groupName == null ? title : '$title / $groupName';

  bool matches(_RssSearchSource source, String animeId) =>
      this.source == source && this.animeId == animeId;

  _RssSearchSelection withGroupName(String name) => _RssSearchSelection(
    source: source,
    animeId: animeId,
    title: title,
    rss: rss,
    groupId: groupId,
    groupName: name,
  );
}

class SubjectRssSearchDialog extends StatefulWidget {
  final int subjectId;
  final String title;
  final String? currentRss;
  final bool selectOnly;
  final RssSelectionBehavior selectionBehavior;
  final Future<bool> Function(BuildContext context, String rss) onSubscribe;

  const SubjectRssSearchDialog({
    super.key,
    required this.subjectId,
    required this.title,
    required this.onSubscribe,
    this.currentRss,
    this.selectOnly = false,
    this.selectionBehavior = RssSelectionBehavior.replace,
  });

  @override
  State<SubjectRssSearchDialog> createState() => _SubjectRssSearchDialogState();
}

/// 条目字幕组的加载状态；展开条目时按需加载并缓存。
class _AnibtGroupsState {
  List<AnibtAnimeGroup> groups = const [];
  bool loading = false;
  bool loaded = false;
  String? error;
}

/// 蜜柑番剧详情的加载状态；展开条目时按需加载并缓存。
class _MikanDetailState {
  MikanBangumiDetailModel? detail;
  bool loading = false;
  bool loaded = false;
  String? error;
}

class _SubjectRssSearchDialogState extends State<SubjectRssSearchDialog> {
  final _mikanApi = BtrMikanApi();
  final _anibtApi = AnibtAPI();
  late final TextEditingController _query;
  _RssSearchSource _source = _RssSearchSource.anibt;
  List<MikanSearchItemModel> _mikanItems = [];
  List<AnibtSearchItem> _anibtItems = [];
  _RssSearchSelection? _selection;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  int _generation = 0;

  /// 已展开的条目与字幕组；跨搜索保留，避免重新加载已取回的字幕组。
  final _expandedItems = <String>{};
  final _expandedGroups = <String>{};
  final _anibtStates = <String, _AnibtGroupsState>{};
  final _mikanStates = <String, _MikanDetailState>{};

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.title);
    unawaited(_search());
  }

  @override
  void dispose() {
    _generation++;
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_saving) return;
    var query = _query.text.trim();
    var generation = ++_generation;
    var source = _source;
    setState(() {
      _mikanItems = [];
      _anibtItems = [];
      _selection = null;
      _error = null;
      _loading = false;
    });
    if (query.isEmpty ||
        (source == _RssSearchSource.anibt && query.length > 100)) {
      setState(() {
        _error = query.isEmpty ? '请输入番剧名称' : 'AniBT 搜索词不能超过 100 个字符';
      });
      return;
    }
    setState(() => _loading = true);
    if (source == _RssSearchSource.mikan) {
      var response = await _mikanApi.searchBgm(query);
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        if (response.code != 0) {
          _error = 'Mikan 搜索失败，请重试或切换搜索源';
        } else {
          var items = response.data as List<MikanSearchItemModel>;
          // 当前订阅的番剧排在首位，其余保持站点排序。
          var current = _currentMikanId();
          _mikanItems = [
            ...items.where((item) => item.id == current),
            ...items.where((item) => item.id != current),
          ];
        }
      });
    } else {
      var response = await _anibtApi.searchAnime(query);
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        if (response.code != 0) {
          _error = response.message;
        } else {
          var items = response.data!;
          // Put an exact Bangumi match first without changing other rankings.
          _anibtItems = [
            ...items.where((item) => item.bgmId == widget.subjectId),
            ...items.where((item) => item.bgmId != widget.subjectId),
          ];
          _selection = _currentAnibtSelection();
        }
      });
    }
  }

  _RssSearchSelection? _currentAnibtSelection() {
    var rss = widget.currentRss?.trim() ?? '';
    var uri = Uri.tryParse(rss);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host != 'anibt.net' ||
        uri.path != '/rss/anime.xml') {
      return null;
    }
    var item = _anibtItems
        .where((item) => item.bgmId.toString() == uri.queryParameters['bgmId'])
        .firstOrNull;
    if (item == null) return null;
    var groupSlug = uri.queryParameters['groupSlug'];
    if (groupSlug?.isEmpty == true) groupSlug = null;
    return _RssSearchSelection(
      source: _RssSearchSource.anibt,
      animeId: item.bgmId.toString(),
      title: item.title,
      rss: rss,
      groupId: groupSlug,
      groupName: groupSlug,
    );
  }

  /// 当前 RSS 对应的蜜柑番剧 ID
  String? _currentMikanId() {
    var uri = Uri.tryParse(widget.currentRss ?? '');
    if (uri == null || !BTAppConstants.isMikanHost(uri.host)) return null;
    return uri.queryParameters['bangumiId'];
  }

  void _changeSource(_RssSearchSource source) {
    if (_source == source || _saving) return;
    setState(() => _source = source);
    unawaited(_search());
  }

  void _select(_RssSearchSelection? selection) {
    if (_saving) return;
    setState(() => _selection = selection);
  }

  Future<void> _subscribe(String rss, String label) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (!widget.selectOnly) {
        var confirm = await showConfirm(
          context,
          title: '确认订阅？',
          content: widget.currentRss?.isNotEmpty == true
              ? widget.selectionBehavior == RssSelectionBehavior.replace
                    ? '将「$label」的 RSS 替换当前条目的全部已有源，只保留本次选择'
                    : '将「$label」的 RSS 新增到当前条目，保留已有源'
              : '将「$label」的 RSS 设为当前条目的 BMF 订阅',
        );
        if (!confirm || !mounted) return;
      }
      var success = await widget.onSubscribe(context, rss);
      if (success && mounted) {
        setState(() => _saving = false);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        await BtInfobar.error(context, '设置 RSS 失败，请重试');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _anibtItemKey(AnibtSearchItem item) => 'anibt:${item.bgmId}';

  String _mikanItemKey(MikanSearchItemModel item) => 'mikan:${item.id}';

  /// 展开/收起条目；首次展开时加载其字幕组。
  void _toggleItem(String key, Future<void> Function() load) {
    var expanded = _expandedItems.contains(key);
    setState(() {
      if (expanded) {
        _expandedItems.remove(key);
      } else {
        _expandedItems.add(key);
      }
    });
    if (!expanded) unawaited(load());
  }

  void _toggleGroup(String key) {
    setState(() {
      if (!_expandedGroups.remove(key)) _expandedGroups.add(key);
    });
  }

  Future<void> _loadAnibtGroups(AnibtSearchItem item) async {
    var key = _anibtItemKey(item);
    var state = _anibtStates.putIfAbsent(key, _AnibtGroupsState.new);
    if (state.loading || state.loaded) return;
    setState(() {
      state.loading = true;
      state.error = null;
    });
    var response = await _anibtApi.getAnimeGroups(item.bgmId);
    if (!mounted) return;
    setState(() {
      state.loading = false;
      if (response.code != 0) {
        state.error = response.message;
      } else {
        state.groups = response.data!;
        state.loaded = true;
      }
    });
    _syncAnibtGroupName(item, state);
  }

  /// 订阅地址只记录字幕组 slug，加载完成后补上站点显示名。
  void _syncAnibtGroupName(AnibtSearchItem item, _AnibtGroupsState state) {
    var selection = _selection;
    if (!state.loaded || selection == null) return;
    if (selection.source != _RssSearchSource.anibt) return;
    if (selection.animeId != item.bgmId.toString()) return;
    var groupId = selection.groupId;
    if (groupId == null) return;
    var group = state.groups
        .where((group) => group.slug == groupId)
        .firstOrNull;
    if (group == null || selection.groupName == group.name) return;
    var updated = selection.withGroupName(group.name);
    setState(() => _selection = updated);
  }

  Future<void> _loadMikanDetail(MikanSearchItemModel item) async {
    var key = _mikanItemKey(item);
    var state = _mikanStates.putIfAbsent(key, _MikanDetailState.new);
    if (state.loading || state.loaded) return;
    setState(() {
      state.loading = true;
      state.error = null;
    });
    var response = await _mikanApi.getBangumiDetail(item.id);
    if (!mounted) return;
    setState(() {
      state.loading = false;
      var detail = response.data;
      if (response.code != 0 || detail == null) {
        state.error = '字幕组加载失败，请重试';
        return;
      }
      state.detail = detail;
      state.loaded = true;
    });
  }

  void _selectAnibtGroup(
    AnibtSearchItem item,
    AnibtAnimeGroup? group,
    bool selected,
  ) {
    _select(
      selected
          ? _RssSearchSelection(
              source: _RssSearchSource.anibt,
              animeId: item.bgmId.toString(),
              title: item.title,
              rss: AnibtAPI.animeRssUrl(
                bgmId: item.bgmId,
                groupSlug: group?.slug,
              ),
              groupId: group?.slug,
              groupName: group?.name,
            )
          : null,
    );
  }

  void _selectMikanGroup(
    MikanSearchItemModel item,
    MikanGroupModel? group,
    bool selected,
  ) {
    _select(
      selected
          ? _RssSearchSelection(
              source: _RssSearchSource.mikan,
              animeId: item.id,
              title: item.title,
              rss: BtrMikanApi.bangumiRssUrl(
                bangumiId: item.id,
                groupId: group?.id,
              ),
              groupId: group?.id,
              groupName: group?.name,
            )
          : null,
    );
  }

  Widget _results() {
    if (_loading) return const Center(child: ProgressRing());
    if (_error != null) return Center(child: Text(_error!));
    var isAnibt = _source == _RssSearchSource.anibt;
    var count = isAnibt ? _anibtItems.length : _mikanItems.length;
    if (count == 0) {
      return const Center(child: Text('没有找到相关条目，请尝试更换搜索词或搜索源'));
    }
    return CustomScrollView(
      slivers: [
        for (var index = 0; index < count; index++) ...[
          if (index > 0) const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (isAnibt)
            _anibtItemSliver(_anibtItems[index])
          else
            _mikanItemSliver(_mikanItems[index]),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 4)),
      ],
    );
  }

  Widget _pinnedHeader({required double extent, required Widget child}) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedHeaderDelegate(extent: extent, child: child),
    );
  }

  /// 字幕组表头在其资源框可见期间吸顶，资源框保留内部滚动。
  List<Widget> _groupSlivers({
    required String key,
    required _GroupHeader header,
    required Widget content,
  }) {
    var theme = FluentTheme.of(context);
    var expanded = _expandedGroups.contains(key);
    return [
      SliverMainAxisGroup(
        slivers: [
          _pinnedHeader(
            extent: _stickyHeaderExtent(context, 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _StickyHeader(
                expanded: expanded,
                onPressed: () => _toggleGroup(key),
                base: _contentSurface(theme),
                child: header,
              ),
            ),
          ),
          if (expanded) content,
        ],
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
    ];
  }

  Widget _anibtItemSliver(AnibtSearchItem item) {
    var key = _anibtItemKey(item);
    var expanded = _expandedItems.contains(key);
    var selection = _selection;
    var matched =
        selection != null &&
        selection.source == _RssSearchSource.anibt &&
        selection.animeId == item.bgmId.toString();
    return SliverMainAxisGroup(
      slivers: [
        _pinnedHeader(
          extent: _stickyHeaderExtent(context, 48),
          child: _ItemHeader(
            title: item.title,
            meta: [
              'Bangumi ${item.bgmId}',
              if (item.bgmId == widget.subjectId) '当前条目',
              if (item.date != null && item.date!.isNotEmpty) item.date!,
            ].join(' · '),
            expanded: expanded,
            onPressed: () => _toggleItem(key, () => _loadAnibtGroups(item)),
          ),
        ),
        if (expanded) _anibtItemContent(item, key, matched ? selection : null),
      ],
    );
  }

  Widget _anibtItemContent(
    AnibtSearchItem item,
    String key,
    _RssSearchSelection? selection,
  ) {
    var state = _anibtStates[key];
    var groups = state?.groups ?? const <AnibtAnimeGroup>[];
    return DecoratedSliver(
      decoration: _contentDecoration(FluentTheme.of(context)),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Checkbox(
                checked: selection != null && selection.groupId == null,
                onChanged: _saving
                    ? null
                    : (checked) =>
                          _selectAnibtGroup(item, null, checked ?? false),
                content: const Text('整个番剧（全部字幕组）'),
              ),
            ),
          ),
          if (state == null || state.loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Center(child: ProgressRing()),
              ),
            )
          else if (state.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.error!),
                    const SizedBox(height: 8),
                    Button(
                      onPressed: () {
                        unawaited(_loadAnibtGroups(item));
                      },
                      child: const Text('重试字幕组'),
                    ),
                  ],
                ),
              ),
            )
          else if (groups.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text('该番剧暂无字幕组资源，可以订阅番剧 RSS 等待更新。'),
              ),
            )
          else
            for (var group in groups)
              ..._groupSlivers(
                key: '$key:${group.slug}',
                header: _GroupHeader(
                  title: group.totalReleases == null
                      ? group.name
                      : '${group.name} · ${group.totalReleases} 个资源',
                  subtitle: _anibtUpdatedAt(group.lastUpdatedAt),
                  selected: selection?.groupId == group.slug,
                  onSelected: _saving
                      ? null
                      : (selected) => _selectAnibtGroup(item, group, selected),
                ),
                content: _anibtReleaseBox(group),
              ),
        ],
      ),
    );
  }

  /// 字幕组资源框：资源与表头共用一条滚动流，表头因此能在资源滚过期间吸顶。
  Widget _anibtReleaseBox(AnibtAnimeGroup group) {
    var items = group.items;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: DecoratedSliver(
        decoration: _contentDecoration(FluentTheme.of(context)),
        sliver: SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: items.isEmpty
              ? const SliverToBoxAdapter(child: Text('暂无资源'))
              : SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '最近 ${items.length} 个资源',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, index) => _AnibtReleasePreview(
                        key: ValueKey(items[index].releaseId),
                        item: items[index],
                        subjectId: widget.subjectId,
                        enabled: !_saving,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _mikanItemSliver(MikanSearchItemModel item) {
    var key = _mikanItemKey(item);
    var detail = _mikanStates[key]?.detail;
    var expanded = _expandedItems.contains(key);
    var selection = _selection;
    var matched =
        selection != null &&
        selection.source == _RssSearchSource.mikan &&
        selection.animeId == item.id;
    return SliverMainAxisGroup(
      slivers: [
        _pinnedHeader(
          extent: _stickyHeaderExtent(context, 48),
          child: _ItemHeader(
            title: item.title,
            meta: [
              'Mikan ${item.id}',
              if (detail != null && detail.bgmId == widget.subjectId) '当前条目',
            ].join(' · '),
            expanded: expanded,
            onPressed: () => _toggleItem(key, () => _loadMikanDetail(item)),
          ),
        ),
        if (expanded) _mikanItemContent(item, key, matched ? selection : null),
      ],
    );
  }

  Widget _mikanItemContent(
    MikanSearchItemModel item,
    String key,
    _RssSearchSelection? selection,
  ) {
    var state = _mikanStates[key];
    var groups = state?.detail?.groups ?? const <MikanGroupModel>[];
    return DecoratedSliver(
      decoration: _contentDecoration(FluentTheme.of(context)),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Checkbox(
                checked: selection != null && selection.groupId == null,
                onChanged: _saving
                    ? null
                    : (checked) =>
                          _selectMikanGroup(item, null, checked ?? false),
                content: const Text('整个番剧（全部字幕组）'),
              ),
            ),
          ),
          if (state == null || state.loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Center(child: ProgressRing()),
              ),
            )
          else if (state.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.error!),
                    const SizedBox(height: 8),
                    Button(
                      onPressed: () {
                        unawaited(_loadMikanDetail(item));
                      },
                      child: const Text('重试字幕组'),
                    ),
                  ],
                ),
              ),
            )
          else if (groups.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text('该番剧暂无字幕组资源，可以订阅番剧 RSS 等待更新。'),
              ),
            )
          else
            for (var group in groups)
              ..._groupSlivers(
                key: '$key:${group.id}',
                header: _GroupHeader(
                  title: group.items.isEmpty
                      ? group.name
                      : '${group.name} · 最近 ${group.items.length} 个资源',
                  subtitle: group.updatedAt == null
                      ? null
                      : '更新 ${group.updatedAt}',
                  selected: selection?.groupId == group.id,
                  onSelected: _saving
                      ? null
                      : (selected) => _selectMikanGroup(item, group, selected),
                ),
                content: _mikanReleaseBox(group),
              ),
        ],
      ),
    );
  }

  Widget _mikanReleaseBox(MikanGroupModel group) {
    var items = group.items;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: DecoratedSliver(
        decoration: _contentDecoration(FluentTheme.of(context)),
        sliver: SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: items.isEmpty
              ? const SliverToBoxAdapter(child: Text('暂无资源'))
              : SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => _MikanEpisodePreview(
                    key: ValueKey(items[index].link),
                    item: items[index],
                    subjectId: widget.subjectId,
                    enabled: !_saving,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _actionBar() {
    var selection = _selection;
    var source = selection?.source == _RssSearchSource.mikan
        ? 'Mikan'
        : 'AniBT';
    var scope = '$source · ${selection?.groupName ?? '全部字幕组'}';
    var info = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selection == null) ...[
          const Text('尚未选择 RSS'),
          const SizedBox(height: 4),
          const Text('请选择整个番剧或字幕组', style: TextStyle(fontSize: 12)),
        ] else ...[
          Tooltip(
            message: selection.title,
            child: Text(
              '已选：${selection.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
          Tooltip(
            message: scope,
            child: Text(
              scope,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 4),
          Tooltip(
            message: selection.rss,
            child: Text(
              selection.rss,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ],
    );
    var buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        Button(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        FilledButton(
          onPressed: _saving || selection == null
              ? null
              : () => _subscribe(selection.rss, selection.label),
          child: Text(
            _saving
                ? '处理中…'
                : widget.selectOnly
                ? '确认使用'
                : '确认订阅',
          ),
        ),
      ],
    );
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (_, constraints) {
              if (constraints.maxWidth < 480) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    info,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: buttons),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 16),
                  buttons,
                ],
              );
            },
          ),
          if (_saving) ...[const SizedBox(height: 8), const ProgressBar()],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: ContentDialog(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        title: const Text('搜索番剧 RSS'),
        content: SizedBox(
          height: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('搜索来源'),
                  const SizedBox(width: 12),
                  ToggleButton(
                    checked: _source == _RssSearchSource.mikan,
                    onChanged: _saving
                        ? null
                        : (_) => _changeSource(_RssSearchSource.mikan),
                    child: const Text('Mikan'),
                  ),
                  const SizedBox(width: 8),
                  ToggleButton(
                    checked: _source == _RssSearchSource.anibt,
                    onChanged: _saving
                        ? null
                        : (_) => _changeSource(_RssSearchSource.anibt),
                    child: const Text('AniBT'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextBox(
                      controller: _query,
                      placeholder: '输入番剧名称',
                      autofocus: true,
                      enabled: !_saving,
                      onSubmitted: (_) => unawaited(_search()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _search,
                    child: const Text('搜索'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('选择整个番剧或字幕组后，在底部确认；展开字幕组查看资源详情。'),
              const SizedBox(height: 12),
              Expanded(child: _results()),
            ],
          ),
        ),
        actions: [_actionBar()],
      ),
    );
  }
}

String _anibtUpdatedAt(int? milliseconds) {
  if (milliseconds == null) return '更新时间未知';
  var date = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  return '更新 ${DateFormat('yyyy-MM-dd HH:mm').format(date)}';
}

/// 吸顶表头的固定高度；文本放大时按两行文本的增量抬高，避免截断。
double _stickyHeaderExtent(BuildContext context, double base) {
  var scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  return base + (scale - 1) * 36;
}

/// 展开内容的外框，与 fluent_ui 的 Expander 内容区保持一致。
ShapeDecoration _contentDecoration(FluentThemeData theme) {
  return ShapeDecoration(
    color: theme.resources.cardBackgroundFillColorSecondary,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: theme.resources.cardStrokeColorDefault),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
    ),
  );
}

/// 条目内容区的实际底色；吸顶表头需与它合成才能既遮挡资源又不留色带。
Color _contentSurface(FluentThemeData theme) {
  return Color.alphaBlend(
    theme.resources.cardBackgroundFillColorSecondary,
    theme.menuColor,
  );
}

/// 固定的吸顶高度由 [SliverPersistentHeader] 要求。
class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedHeaderDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: extent, child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return oldDelegate.extent != extent || oldDelegate.child != child;
  }
}

/// 表头卡片向上下各多铺的像素数。
///
/// 吸顶条之间、表头与其内容之间的边界在缩放不为整数时会被分别取整，留下一条
/// 1 物理像素宽、没有任何控件绘制的缝；缝里会露出更底层的内容。表头卡片多铺
/// 这么多像素后，这部分与相邻元素重叠，缝必然被不透明填充覆盖。
const _headerSeamExtent = 2.0;

/// 条目与字幕组共用的表头外观，沿用 Expander 表头的配色与箭头。
class _StickyHeader extends StatelessWidget {
  const _StickyHeader({
    required this.child,
    required this.expanded,
    required this.onPressed,
    required this.base,
  });

  final Widget child;
  final bool expanded;
  final VoidCallback onPressed;

  /// 表头所在的底色。fluent 的卡片填充是半透明的，先与它合成才能整条遮住
  /// 吸顶后从下方滚过的资源。
  final Color base;

  @override
  Widget build(BuildContext context) {
    var theme = FluentTheme.of(context);
    var shape = RoundedRectangleBorder(
      side: BorderSide(color: theme.resources.cardStrokeColorDefault),
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(6),
        bottom: Radius.circular(expanded ? 0 : 6),
      ),
    );
    return HoverButton(
      onPressed: onPressed,
      hitTestBehavior: HitTestBehavior.deferToChild,
      builder: (context, states) {
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            // 卡片底纹与边框画在可溢出的一层里，向上下各多铺几个像素：
            // 两条吸顶条（或表头与其内容）的边界在缩放取整后会留下 1px 透明
            // 缝，多铺的部分就在缝的位置，且与相邻元素重叠，不会露底色。
            Positioned(
              top: -_headerSeamExtent,
              bottom: expanded ? -_headerSeamExtent : 0,
              left: 0,
              right: 0,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: Color.alphaBlend(
                    theme.resources.cardBackgroundFillColorDefault,
                    base,
                  ),
                  shape: shape,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsetsDirectional.only(start: 16),
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                children: [
                  Expanded(child: child),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 20,
                      end: 8,
                      top: 8,
                      bottom: 8,
                    ),
                    child: FocusBorder(
                      focused: states.isFocused,
                      child: Container(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: ButtonThemeData.uncheckedInputColor(
                            theme,
                            states,
                            transparentWhenNone: true,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: theme.fastAnimationDuration,
                          curve: theme.animationCurve,
                          child: const Icon(FluentIcons.chevron_down, size: 8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 条目表头：番剧名与站点信息，整条可点击展开。
class _ItemHeader extends StatelessWidget {
  const _ItemHeader({
    required this.title,
    required this.meta,
    required this.expanded,
    required this.onPressed,
  });

  final String title;
  final String meta;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    var theme = FluentTheme.of(context);
    return _StickyHeader(
      expanded: expanded,
      onPressed: onPressed,
      base: theme.menuColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: title,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 字幕组表头：勾选框用于选中该字幕组，其余区域用于展开资源。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.selected,
    required this.onSelected,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    var subtitle = this.subtitle;
    return Row(
      children: [
        Checkbox(
          checked: selected,
          onChanged: onSelected == null
              ? null
              : (checked) => onSelected!(checked ?? false),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: title,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

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
