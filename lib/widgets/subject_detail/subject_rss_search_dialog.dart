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
            selection:
                _selection?.matches(
                      _RssSearchSource.anibt,
                      item.bgmId.toString(),
                    ) ==
                    true
                ? _selection
                : null,
            enabled: !_saving,
            onSelected: _select,
          );
        }
        var item = _mikanItems[index];
        return _MikanAnimeResult(
          key: ValueKey(item.id),
          item: item,
          api: _mikanApi,
          subjectId: widget.subjectId,
          selection:
              _selection?.matches(_RssSearchSource.mikan, item.id) == true
              ? _selection
              : null,
          enabled: !_saving,
          onSelected: _select,
        );
      },
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

class _AnibtAnimeResult extends StatefulWidget {
  final AnibtSearchItem item;
  final AnibtAPI api;
  final int subjectId;
  final _RssSearchSelection? selection;
  final bool enabled;
  final ValueChanged<_RssSearchSelection?> onSelected;

  const _AnibtAnimeResult({
    super.key,
    required this.item,
    required this.api,
    required this.subjectId,
    required this.selection,
    required this.enabled,
    required this.onSelected,
  });

  @override
  State<_AnibtAnimeResult> createState() => _AnibtAnimeResultState();
}

class _AnibtAnimeResultState extends State<_AnibtAnimeResult>
    with AutomaticKeepAliveClientMixin {
  List<AnibtAnimeGroup> _groups = [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
      }
    });
    var selection = widget.selection;
    if (_loaded && selection?.groupId != null) {
      var group = _groups
          .where((group) => group.slug == selection!.groupId)
          .firstOrNull;
      if (group != null && selection!.groupName != group.name) {
        widget.onSelected(selection.withGroupName(group.name));
      }
    }
  }

  void _select(AnibtAnimeGroup? group, bool selected) {
    widget.onSelected(
      selected
          ? _RssSearchSelection(
              source: _RssSearchSource.anibt,
              animeId: widget.item.bgmId.toString(),
              title: widget.item.title,
              rss: AnibtAPI.animeRssUrl(
                bgmId: widget.item.bgmId,
                groupSlug: group?.slug,
              ),
              groupId: group?.slug,
              groupName: group?.name,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var item = widget.item;
    var selection = widget.selection;
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
            checked: selection != null && selection.groupId == null,
            onChanged: widget.enabled
                ? (checked) => _select(null, checked ?? false)
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
                  subjectId: widget.subjectId,
                  selected: selection?.groupId == group.slug,
                  onSelected: widget.enabled
                      ? (selected) => _select(group, selected)
                      : null,
                ),
              );
            }),
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
  final int subjectId;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  const _AnibtGroupResult({
    super.key,
    required this.group,
    required this.subjectId,
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
                    itemBuilder: (_, index) => _AnibtReleasePreview(
                      key: ValueKey(group.items[index].releaseId),
                      item: group.items[index],
                      subjectId: subjectId,
                      enabled: onSelected != null,
                    ),
                  ),
                ),
              ],
            ),
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

class _MikanAnimeResult extends StatefulWidget {
  final MikanSearchItemModel item;
  final BtrMikanApi api;
  final int subjectId;
  final _RssSearchSelection? selection;
  final bool enabled;
  final ValueChanged<_RssSearchSelection?> onSelected;

  const _MikanAnimeResult({
    super.key,
    required this.item,
    required this.api,
    required this.subjectId,
    required this.selection,
    required this.enabled,
    required this.onSelected,
  });

  @override
  State<_MikanAnimeResult> createState() => _MikanAnimeResultState();
}

class _MikanAnimeResultState extends State<_MikanAnimeResult>
    with AutomaticKeepAliveClientMixin {
  MikanBangumiDetailModel? _detail;
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
    });
  }

  void _select(MikanGroupModel? group, bool selected) {
    widget.onSelected(
      selected
          ? _RssSearchSelection(
              source: _RssSearchSource.mikan,
              animeId: widget.item.id,
              title: widget.item.title,
              rss: BtrMikanApi.bangumiRssUrl(
                bangumiId: widget.item.id,
                groupId: group?.id,
              ),
              groupId: group?.id,
              groupName: group?.name,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var item = widget.item;
    var detail = _detail;
    var groups = detail?.groups ?? const <MikanGroupModel>[];
    var selection = widget.selection;
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
            ].join(' · '),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Checkbox(
            checked: selection != null && selection.groupId == null,
            onChanged: widget.enabled
                ? (checked) => _select(null, checked ?? false)
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
                  subjectId: widget.subjectId,
                  selected: selection?.groupId == group.id,
                  onSelected: widget.enabled
                      ? (selected) => _select(group, selected)
                      : null,
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _MikanGroupResult extends StatelessWidget {
  final MikanGroupModel group;
  final int subjectId;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  const _MikanGroupResult({
    super.key,
    required this.group,
    required this.subjectId,
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
                itemBuilder: (_, index) => _MikanEpisodePreview(
                  key: ValueKey(group.items[index].link),
                  item: group.items[index],
                  subjectId: subjectId,
                  enabled: onSelected != null,
                ),
              ),
            ),
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
