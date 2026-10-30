part of '../download_task_details.dart';

class _TrackersTab extends StatelessWidget {
  const _TrackersTab({
    required this.trackers,
    required this.loading,
    required this.isHttp,
    required this.reannouncing,
    required this.canReannounce,
    required this.onReannounce,
    required this.onRetry,
    required this.onShowPeers,
    this.peerEndpoint,
    this.error,
  });

  final List<BtTaskTrackerDetail> trackers;
  final bool loading;
  final bool isHttp;
  final bool reannouncing;
  final bool canReannounce;
  final VoidCallback onReannounce;
  final VoidCallback onRetry;
  final ValueChanged<String> onShowPeers;
  final String? peerEndpoint;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (isHttp) {
      return const _DetailEmptyState(
        icon: FluentIcons.link,
        title: 'HTTP 任务不使用 Tracker',
        description: '可在信息页查看服务器响应与 Range 支持情况',
      );
    }
    if (error != null && trackers.isEmpty) {
      return _DetailTabError(error: error!, onRetry: onRetry);
    }
    if (loading) return const Center(child: ProgressRing());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '点击节点查看详情，悬停 Tracker 查看完整地址',
                  style: BTTypography.caption(context),
                ),
              ),
              Tooltip(
                message: reannouncing
                    ? '正在请求重新汇报'
                    : canReannounce
                    ? '重新汇报（遵守 Tracker 最小间隔）'
                    : '继续任务后可重新汇报',
                child: IconButton(
                  icon: reannouncing
                      ? const SizedBox.square(
                          dimension: 14,
                          child: ProgressRing(strokeWidth: 2),
                        )
                      : const Icon(FluentIcons.refresh, size: 14),
                  onPressed: canReannounce && !reannouncing
                      ? onReannounce
                      : null,
                ),
              ),
            ],
          ),
        ),
        if (error != null)
          Text('刷新失败，正在显示上次结果：$error', style: BTTypography.caption(context)),
        Expanded(
          child: trackers.isEmpty
              ? _DetailEmptyState(
                  icon: FluentIcons.link,
                  title: peerEndpoint == null
                      ? '任务没有 Tracker'
                      : '此 Peer 暂无有效 Tracker 返回记录',
                  description: peerEndpoint == null
                      ? '公开种子仍可通过 DHT、PEX 或本地发现寻找节点'
                      : '关联记录可能已过期，或对应 Tracker 已从任务移除',
                )
              : _TrackerGraph(
                  key: ValueKey(peerEndpoint),
                  trackers: trackers,
                  showDetails: peerEndpoint != null,
                  onShowPeers: onShowPeers,
                ),
        ),
      ],
    );
  }
}

class _TrackerStatus extends StatelessWidget {
  const _TrackerStatus({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    var color = switch (state) {
      'working' => BTColors.successLight(context),
      'error' => BTColors.errorLight(context),
      'mixed' => BTColors.warningLight(context),
      'updating' => FluentTheme.of(context).accentColor,
      _ => BTColors.textSecondary(context),
    };
    return Text(
      _trackerStateLabel(state),
      style: BTTypography.caption(context).copyWith(color: color),
    );
  }
}

String _trackerStateLabel(String state) => switch (state) {
  'updating' => '正在汇报',
  'working' => '正常',
  'error' => '汇报失败',
  'mixed' => '部分失败',
  'paused' => '已暂停',
  'disabled' => '接口已禁用',
  _ => '等待汇报',
};

class _TrackerEndpoint extends StatelessWidget {
  const _TrackerEndpoint({required this.tracker});

  final BtTaskTrackerDetail tracker;

  String get _nextAnnounceLabel => tracker.nextAnnounceSeconds == null
      ? '未安排'
      : '${tracker.nextAnnounceSeconds} 秒后';

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SelectableText(
              tracker.endpoint.isEmpty
                  ? '等待本地接口'
                  : '本地接口：${tracker.endpoint} · '
                        '${tracker.protocol.toUpperCase()}',
              style: BTTypography.body(context).copyWith(fontSize: 12),
            ),
            _TrackerStatus(state: tracker.state),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '返回节点：${tracker.peers?.toString() ?? '尚无响应'} · '
          '下次汇报：$_nextAnnounceLabel',
          style: BTTypography.caption(context),
        ),
        if (tracker.lastError.isNotEmpty) ...[
          const SizedBox(height: 4),
          SelectableText(
            '错误：${tracker.lastError}',
            style: BTTypography.caption(
              context,
            ).copyWith(color: BTColors.errorLight(context)),
          ),
        ],
        if (tracker.message.isNotEmpty) ...[
          const SizedBox(height: 4),
          SelectableText(
            '消息：${tracker.message}',
            style: BTTypography.caption(context),
          ),
        ],
      ],
    ),
  );
}

class _AssociationFilterBar extends StatelessWidget {
  const _AssociationFilterBar({
    required this.label,
    required this.value,
    required this.onClear,
    required this.onBack,
    required this.backLabel,
  });

  final String label;
  final String value;
  final VoidCallback onClear;
  final VoidCallback onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
    child: Row(
      children: [
        Tooltip(
          message: backLabel,
          child: IconButton(
            icon: const Icon(FluentIcons.back, size: 14),
            onPressed: onBack,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Tooltip(
            message: '$value\n按最近 30 分钟的返回记录关联，可有多个来源；重启后重新记录',
            child: Text(
              '$label：$value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BTTypography.caption(context),
            ),
          ),
        ),
        Tooltip(
          message: '清除关联筛选，显示全部',
          child: IconButton(
            icon: const Icon(FluentIcons.clear_filter, size: 14),
            onPressed: onClear,
          ),
        ),
      ],
    ),
  );
}

class _DetailPager extends StatefulWidget {
  const _DetailPager({
    required this.offset,
    required this.count,
    required this.total,
    required this.nextOffset,
    required this.pageSize,
    required this.loading,
    required this.description,
    required this.onPage,
    this.actions,
    super.key,
  });

  final int offset;
  final int count;
  final int total;
  final int? nextOffset;
  final int pageSize;
  final bool loading;
  final String description;
  final ValueChanged<int> onPage;
  final Widget? actions;

  @override
  State<_DetailPager> createState() => _DetailPagerState();
}

class _DetailPagerState extends State<_DetailPager> {
  late final TextEditingController _pageController;
  final FocusNode _pageFocus = FocusNode();
  int? _queuedPage;
  bool _jumpScheduled = false;

  int get _pageCount => (widget.total + widget.pageSize - 1) ~/ widget.pageSize;

  int get _currentPage => _pageCount == 0
      ? 0
      : (widget.offset ~/ widget.pageSize + 1).clamp(1, _pageCount);

  @override
  void initState() {
    super.initState();
    _pageController = TextEditingController(text: '$_currentPage');
    _pageFocus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _DetailPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_pageFocus.hasFocus ||
        oldWidget.offset != widget.offset ||
        oldWidget.pageSize != widget.pageSize ||
        _pageCount == 0) {
      _restorePage();
    }
    if (!widget.loading && _queuedPage != null && !_jumpScheduled) {
      _jumpScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpScheduled = false;
        if (!mounted || widget.loading) return;
        var page = _queuedPage;
        _queuedPage = null;
        if (page != null) _jumpToPage(page);
      });
    }
  }

  @override
  void dispose() {
    _pageFocus.removeListener(_onFocusChanged);
    _pageFocus.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_pageFocus.hasFocus) return;
    // Enter 的提交回调先读取输入，再处理普通失焦时的还原。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !_pageFocus.hasFocus &&
          _queuedPage == null &&
          !widget.loading) {
        _restorePage();
      }
    });
  }

  void _restorePage() {
    var text = '$_currentPage';
    if (_pageController.text != text) _pageController.text = text;
  }

  void _submitPage(String text) {
    var page = int.tryParse(text);
    if (page == null || _pageCount == 0) {
      _queuedPage = null;
      _restorePage();
      return;
    }
    _jumpToPage(page);
  }

  void _jumpToPage(int requested) {
    if (_pageCount == 0) {
      _restorePage();
      return;
    }
    var page = requested.clamp(1, _pageCount);
    _pageController.text = '$page';
    if (widget.loading) {
      // 自动刷新期间保留输入，待当前请求结束再提交跳转。
      _queuedPage = page;
      return;
    }
    _queuedPage = null;
    var offset = (page - 1) * widget.pageSize;
    if (offset != widget.offset) widget.onPage(offset);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${widget.count == 0 ? 0 : widget.offset + 1}–'
            '${widget.offset + widget.count} / ${widget.total}'
            '${widget.description.isEmpty ? '' : ' · '}'
            '${widget.description}',
            style: BTTypography.caption(context),
          ),
        ),
        if (widget.actions != null) ...[
          widget.actions!,
          const SizedBox(width: 8),
        ],
        Tooltip(
          message: '上一页',
          child: IconButton(
            icon: const Icon(FluentIcons.chevron_left, size: 14),
            onPressed: !widget.loading && widget.offset > 0
                ? () => widget.onPage(max(0, widget.offset - widget.pageSize))
                : null,
          ),
        ),
        Tooltip(
          message: _pageCount == 0
              ? '暂无可跳转页'
              : '输入 1–$_pageCount 后按 Enter 跳转\n每页 ${widget.pageSize} 项',
          child: Semantics(
            label: '当前页码，共 $_pageCount 页',
            child: SizedBox(
              width: 52,
              child: TextBox(
                controller: _pageController,
                focusNode: _pageFocus,
                enabled: _pageCount > 0,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: _submitPage,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('/ $_pageCount', style: BTTypography.caption(context)),
        ),
        Tooltip(
          message: widget.loading ? '正在加载' : '下一页',
          child: IconButton(
            icon: widget.loading
                ? const SizedBox.square(
                    dimension: 14,
                    child: ProgressRing(strokeWidth: 2),
                  )
                : const Icon(FluentIcons.chevron_right, size: 14),
            onPressed: !widget.loading && widget.nextOffset != null
                ? () => widget.onPage(widget.nextOffset!)
                : null,
          ),
        ),
      ],
    ),
  );
}
