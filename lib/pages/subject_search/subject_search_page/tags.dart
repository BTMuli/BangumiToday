part of '../subject_search_page.dart';

/// 频道接口提供按条目类型排列的热门普通标签，不提供语义分类。
class _SubjectTagPicker extends ConsumerStatefulWidget {
  const _SubjectTagPicker({
    super.key,
    required this.types,
    required this.selectedTags,
    required this.onToggle,
  });

  final List<BangumiSubjectType> types;
  final List<String> selectedTags;
  final ValueChanged<String> onToggle;

  @override
  ConsumerState<_SubjectTagPicker> createState() => _SubjectTagPickerState();
}

class _SubjectTagPickerState extends ConsumerState<_SubjectTagPicker> {
  BangumiSubjectType? _type;
  final List<BangumiTag> _tags = [];
  int _version = 0;
  int _offset = 0;
  int _total = 0;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _type = widget.types.firstOrNull;
    Future.microtask(() => _load(reset: true));
  }

  @override
  void didUpdateWidget(covariant _SubjectTagPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.types.contains(_type)) {
      _type = widget.types.firstOrNull;
      Future.microtask(() => _load(reset: true));
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (!mounted || (_loading && !reset)) return;
    if (reset) {
      _version++;
      _tags.clear();
      _offset = 0;
      _total = 0;
      _hasMore = true;
    }
    var type = _type;
    if (type == null) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }
    var version = _version;
    setState(() {
      _loading = true;
      _error = null;
    });
    var response = await ref
        .read(bangumiRepositoryProvider)
        .getSubjectTags(type, offset: _offset);
    if (!mounted || version != _version) return;
    setState(() {
      _loading = false;
      var page = response.data;
      if (response.code != 0 || page == null) {
        _error = '热门标签加载失败，可重试或手动输入';
        return;
      }
      var names = _tags.map((tag) => tag.name).toSet();
      _tags.addAll(page.data.where((tag) => names.add(tag.name)));
      _offset += page.data.length;
      _total = page.total;
      _hasMore = page.data.isNotEmpty && _offset < _total;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.types.isEmpty) return const Text('请先选择至少一个条目类型');
    var visible = _tags
        .where((tag) => tag.name.toLowerCase().contains(_filter.toLowerCase()))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var type in widget.types)
              ToggleButton(
                checked: _type == type,
                child: Text(type.label),
                onChanged: (_) async {
                  if (_type == type) return;
                  _type = type;
                  await _load(reset: true);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextBox(
                placeholder: '筛选已加载的标签',
                onChanged: (value) => setState(() => _filter = value.trim()),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: '刷新热门标签',
              child: IconButton(
                icon: const Icon(
                  FluentIcons.refresh,
                  size: 14,
                  semanticLabel: '刷新热门标签',
                ),
                onPressed: _loading
                    ? null
                    : () async => await _load(reset: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('点选添加或移除，多个标签同时满足。', style: BTTypography.caption(context)),
        const SizedBox(height: 8),
        Expanded(
          child: visible.isNotEmpty
              ? ListView(
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var tag in visible)
                          Tooltip(
                            message: '${tag.name} · 使用 ${tag.count} 次',
                            child: ToggleButton(
                              checked: widget.selectedTags.contains(tag.name),
                              onChanged: (_) => widget.onToggle(tag.name),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 220,
                                ),
                                child: Text(
                                  tag.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                )
              : Center(
                  child: Text(
                    _loading
                        ? '正在加载标签…'
                        : (_tags.isEmpty ? '暂无热门标签，可手动输入' : '已加载的标签中没有匹配项'),
                    style: BTTypography.caption(context),
                  ),
                ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_error!),
          ),
        Row(
          children: [
            Expanded(
              child: Text(
                '已加载 $_offset / $_total 个标签',
                style: BTTypography.caption(context),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: _loading
                  ? '正在加载标签'
                  : (_error != null ? '重试加载标签' : '加载更多热门标签'),
              child: IconButton(
                icon: _loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    : const Icon(
                        FluentIcons.chevron_down,
                        size: 14,
                        semanticLabel: '加载更多热门标签',
                      ),
                onPressed: _loading || (!_hasMore && _error == null)
                    ? null
                    : () async => await _load(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
