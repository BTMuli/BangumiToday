// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

// Project imports:
import '../../core/constants/app_constants.dart';
import '../../core/utils/tool_func.dart';
import '../../models/mikan/mikan_model.dart';
import '../../models/rss/anibt_filters.dart';
import '../../models/rss/anibt_search.dart';
import '../../request/mikan/mikan_api.dart';
import '../../request/rss/anibt_api.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../rss/anibt_tag_chip.dart';

enum _RssSearchSource { mikan, anibt }

class BsdRssSearchDialog extends StatefulWidget {
  final int subjectId;
  final String title;
  final String? currentRss;
  final bool selectOnly;
  final Future<bool> Function(BuildContext context, String rss) onSubscribe;

  const BsdRssSearchDialog({
    super.key,
    required this.subjectId,
    required this.title,
    required this.onSubscribe,
    this.currentRss,
    this.selectOnly = false,
  });

  @override
  State<BsdRssSearchDialog> createState() => _BsdRssSearchDialogState();
}

class _BsdRssSearchDialogState extends State<BsdRssSearchDialog> {
  final _mikanApi = BtrMikanApi();
  final _anibtApi = AnibtAPI();
  late final TextEditingController _query;
  _RssSearchSource _source = _RssSearchSource.anibt;
  List<MikanSearchItemModel> _mikanItems = [];
  List<AnibtSearchItem> _anibtItems = [];
  bool _loading = false;
  bool _saving = false;
  String? _error;
  int _generation = 0;

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
        }
      });
    }
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

  Future<void> _subscribe(String rss, String label) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (!widget.selectOnly) {
        var confirm = await showConfirm(
          context,
          title: '确认订阅？',
          content: '将「$label」的 RSS 设为当前条目的 BMF 订阅',
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

  Widget _results() {
    if (_loading) return const Center(child: ProgressRing());
    if (_error != null) return Center(child: Text(_error!));
    var isAnibt = _source == _RssSearchSource.anibt;
    var count = isAnibt ? _anibtItems.length : _mikanItems.length;
    if (count == 0) {
      return const Center(child: Text('没有找到相关条目，请尝试更换搜索词或搜索源'));
    }
    return ListView.separated(
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (isAnibt) {
          var item = _anibtItems[index];
          return _AnibtAnimeResult(
            key: ValueKey(item.bgmId),
            item: item,
            api: _anibtApi,
            subjectId: widget.subjectId,
            currentRss: widget.currentRss,
            selectOnly: widget.selectOnly,
            enabled: !_saving,
            onSubscribe: _subscribe,
          );
        }
        var item = _mikanItems[index];
        return _MikanAnimeResult(
          key: ValueKey(item.id),
          item: item,
          api: _mikanApi,
          subjectId: widget.subjectId,
          currentRss: widget.currentRss,
          selectOnly: widget.selectOnly,
          enabled: !_saving,
          onSubscribe: _subscribe,
        );
      },
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
              const Text('展开番剧选择 RSS，展开字幕组查看资源详情。'),
              const SizedBox(height: 12),
              Expanded(child: _results()),
              if (_saving) ...[const SizedBox(height: 8), const ProgressBar()],
            ],
          ),
        ),
        actions: [
          Button(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class _AnibtAnimeResult extends StatefulWidget {
  final AnibtSearchItem item;
  final AnibtAPI api;
  final int subjectId;
  final String? currentRss;
  final bool selectOnly;
  final bool enabled;
  final Future<void> Function(String rss, String label) onSubscribe;

  const _AnibtAnimeResult({
    super.key,
    required this.item,
    required this.api,
    required this.subjectId,
    required this.currentRss,
    required this.selectOnly,
    required this.enabled,
    required this.onSubscribe,
  });

  @override
  State<_AnibtAnimeResult> createState() => _AnibtAnimeResultState();
}

class _AnibtAnimeResultState extends State<_AnibtAnimeResult>
    with AutomaticKeepAliveClientMixin {
  List<AnibtAnimeGroup> _groups = [];
  String? _selectedSlug;
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    var rss = Uri.tryParse(widget.currentRss ?? '');
    if (rss?.host == 'anibt.net' &&
        rss?.path == '/rss/anime.xml' &&
        rss?.queryParameters['bgmId'] == widget.item.bgmId.toString()) {
      _selectedSlug = rss?.queryParameters['groupSlug'];
    }
  }

  Future<void> _loadGroups() async {
    if (_loading || _loaded) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    var response = await widget.api.getAnimeGroups(widget.item.bgmId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (response.code != 0) {
        _error = response.message;
      } else {
        _groups = response.data!;
        _loaded = true;
        if (!_groups.any((group) => group.slug == _selectedSlug)) {
          _selectedSlug = null;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var item = widget.item;
    var selectedGroups = _groups.where((group) => group.slug == _selectedSlug);
    var selectedGroup = selectedGroups.firstOrNull;
    var rss = AnibtAPI.animeRssUrl(bgmId: item.bgmId, groupSlug: _selectedSlug);
    var canSubscribe =
        widget.enabled && (_selectedSlug == null || selectedGroup != null);
    return Expander(
      onStateChanged: (expanded) {
        if (expanded) unawaited(_loadGroups());
      },
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            [
              'Bangumi ${item.bgmId}',
              if (item.bgmId == widget.subjectId) '当前条目',
              if (item.date != null && item.date!.isNotEmpty) item.date!,
            ].join(' · '),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Checkbox(
            checked: _selectedSlug == null,
            onChanged: widget.enabled
                ? (_) => setState(() => _selectedSlug = null)
                : null,
            content: const Text('整个番剧（全部字幕组）'),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: ProgressRing()),
            )
          else if (_error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_error!),
                const SizedBox(height: 8),
                Button(onPressed: _loadGroups, child: const Text('重试字幕组')),
              ],
            )
          else if (_loaded && _groups.isEmpty)
            const Text('该番剧暂无字幕组资源，可以订阅番剧 RSS 等待更新。')
          else
            ..._groups.map((group) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AnibtGroupResult(
                  key: ValueKey(group.slug),
                  group: group,
                  selected: _selectedSlug == group.slug,
                  onSelected: widget.enabled
                      ? (selected) => setState(() {
                          _selectedSlug = selected ? group.slug : null;
                        })
                      : null,
                ),
              );
            }),
          const SizedBox(height: 12),
          Text(rss, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: canSubscribe
                ? () => widget.onSubscribe(
                    rss,
                    selectedGroup == null
                        ? item.title
                        : '${item.title} / ${selectedGroup.name}',
                  )
                : null,
            child: Text(
              '${widget.selectOnly ? '使用' : '订阅'}'
              '${_selectedSlug == null ? '番剧' : '字幕组'} RSS',
            ),
          ),
        ],
      ),
    );
  }
}

String _anibtUpdatedAt(int? milliseconds) {
  if (milliseconds == null) return '更新时间未知';
  var date = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  return '更新 ${DateFormat('yyyy-MM-dd HH:mm').format(date)}';
}

class _AnibtGroupResult extends StatelessWidget {
  final AnibtAnimeGroup group;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  const _AnibtGroupResult({
    super.key,
    required this.group,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    var count = group.totalReleases;
    return Expander(
      header: Row(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == null ? group.name : '${group.name} · $count 个资源',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _anibtUpdatedAt(group.lastUpdatedAt),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      content: group.items.isEmpty
          ? const Text('暂无资源')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '最近 ${group.items.length} 个资源',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    primary: false,
                    itemCount: group.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, index) =>
                        _AnibtReleasePreview(item: group.items[index]),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AnibtReleasePreview extends StatelessWidget {
  final AnibtGroupRelease item;

  const _AnibtReleasePreview({required this.item});

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
        Tooltip(
          message: item.title,
          child: Text(
            item.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
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

class _MikanAnimeResult extends StatefulWidget {
  final MikanSearchItemModel item;
  final BtrMikanApi api;
  final int subjectId;
  final String? currentRss;
  final bool selectOnly;
  final bool enabled;
  final Future<void> Function(String rss, String label) onSubscribe;

  const _MikanAnimeResult({
    super.key,
    required this.item,
    required this.api,
    required this.subjectId,
    required this.currentRss,
    required this.selectOnly,
    required this.enabled,
    required this.onSubscribe,
  });

  @override
  State<_MikanAnimeResult> createState() => _MikanAnimeResultState();
}

class _MikanAnimeResultState extends State<_MikanAnimeResult>
    with AutomaticKeepAliveClientMixin {
  MikanBangumiDetailModel? _detail;
  String? _selectedGroupId;
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    var rss = Uri.tryParse(widget.currentRss ?? '');
    if (rss == null) return;
    if (rss.queryParameters['bangumiId'] != widget.item.id) return;
    _selectedGroupId = rss.queryParameters['subgroupid'];
  }

  Future<void> _loadDetail() async {
    if (_loading || _loaded) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    var response = await widget.api.getBangumiDetail(widget.item.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      var detail = response.data;
      if (response.code != 0 || detail == null) {
        _error = '字幕组加载失败，请重试';
        return;
      }
      _detail = detail;
      _loaded = true;
      if (!detail.groups.any((group) => group.id == _selectedGroupId)) {
        _selectedGroupId = null;
      }
    });
  }

  /// 当前选中的字幕组，未选中时订阅整个番剧
  String get _rssUrl {
    return BtrMikanApi.bangumiRssUrl(
      bangumiId: widget.item.id,
      groupId: _selectedGroupId,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var item = widget.item;
    var detail = _detail;
    var groups = detail?.groups ?? const <MikanGroupModel>[];
    var selected = groups
        .where((group) => group.id == _selectedGroupId)
        .firstOrNull;
    var canSubscribe =
        widget.enabled && (_selectedGroupId == null || selected != null);
    return Expander(
      onStateChanged: (expanded) {
        if (expanded) unawaited(_loadDetail());
      },
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            [
              'Mikan ${item.id}',
              if (detail != null && detail.bgmId == widget.subjectId) '当前条目',
              if (_selectedGroupId != null && selected != null)
                '已选 ${selected.name}',
            ].join(' · '),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Checkbox(
            checked: _selectedGroupId == null,
            onChanged: widget.enabled
                ? (_) => setState(() => _selectedGroupId = null)
                : null,
            content: const Text('整个番剧（全部字幕组）'),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: ProgressRing()),
            )
          else if (_error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_error!),
                const SizedBox(height: 8),
                Button(onPressed: _loadDetail, child: const Text('重试字幕组')),
              ],
            )
          else if (_loaded && groups.isEmpty)
            const Text('该番剧暂无字幕组资源，可以订阅番剧 RSS 等待更新。')
          else
            ...groups.map((group) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MikanGroupResult(
                  key: ValueKey(group.id),
                  group: group,
                  selected: _selectedGroupId == group.id,
                  onSelected: widget.enabled
                      ? (selected) => setState(() {
                          _selectedGroupId = selected ? group.id : null;
                        })
                      : null,
                ),
              );
            }),
          const SizedBox(height: 12),
          Text(_rssUrl, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: canSubscribe
                ? () => widget.onSubscribe(
                    _rssUrl,
                    selected == null
                        ? item.title
                        : '${item.title} / ${selected.name}',
                  )
                : null,
            child: Text(
              '${widget.selectOnly ? '使用' : '订阅'}'
              '${_selectedGroupId == null ? '番剧' : '字幕组'} RSS',
            ),
          ),
        ],
      ),
    );
  }
}

class _MikanGroupResult extends StatelessWidget {
  final MikanGroupModel group;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  const _MikanGroupResult({
    super.key,
    required this.group,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    var count = group.items.length;
    return Expander(
      header: Row(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 0 ? group.name : '${group.name} · 最近 $count 个资源',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (group.updatedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '更新 ${group.updatedAt}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      content: group.items.isEmpty
          ? const Text('暂无资源')
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                primary: false,
                itemCount: group.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) =>
                    _MikanEpisodePreview(item: group.items[index]),
              ),
            ),
    );
  }
}

class _MikanEpisodePreview extends StatelessWidget {
  final MikanEpisodeModel item;

  const _MikanEpisodePreview({required this.item});

  @override
  Widget build(BuildContext context) {
    var size = item.size;
    var updatedAt = item.updatedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: item.title,
          child: Text(
            item.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
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
