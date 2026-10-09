part of '../bmf_expander.dart';

class BmfRssExpander extends ConsumerStatefulWidget {
  final AppBmfModel bmf;
  final bool isConfig;
  final double maxHeight;
  final Future<void> Function(int subscriptionId)? onDelete;
  final bool initiallyExpanded;
  final bool contentScrollable;
  final bool expandable;
  final bool embedded;
  final ScrollController? contentScrollController;

  const BmfRssExpander({
    super.key,
    required this.bmf,
    required this.isConfig,
    required this.maxHeight,
    this.onDelete,
    this.initiallyExpanded = true,
    this.contentScrollable = true,
    this.expandable = true,
    this.embedded = false,
    this.contentScrollController,
  });

  @override
  ConsumerState<BmfRssExpander> createState() => _BmfRssExpanderState();
}

class _BmfRssExpanderState extends ConsumerState<BmfRssExpander> {
  late final BmfRssData _data = BmfRssData(bmf: widget.bmf);
  final FlyoutController _sourceFlyout = FlyoutController();
  StreamSubscription<BmfRssUpdateEvent>? _updateSubscription;
  StreamSubscription<BmfRssStatusEvent>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _data.addListener(_onDataChanged);
    _listenToUpdate();
    Future.microtask(_data.load);
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  void _listenToUpdate() {
    _updateSubscription = BmfRssService.instance.updateStream.listen((event) {
      if (!mounted) return;
      _data.applyUpdate(event);
    });
    _statusSubscription = BmfRssService.instance.statusStream.listen((event) {
      if (mounted && event.subscriptionId == _data.selectedSubscriptionId) {
        unawaited(_data.load());
      }
    });
  }

  @override
  void didUpdateWidget(BmfRssExpander oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bmf, widget.bmf)) {
      _data.updateBmf(widget.bmf);
    }
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    _statusSubscription?.cancel();
    _data.removeListener(_onDataChanged);
    _data.dispose();
    _sourceFlyout.dispose();
    super.dispose();
  }

  Widget buildRssItem(BuildContext context, RssReleaseData release) {
    var itemKey = _data.itemKey(release.item);
    var key = ValueKey((_data.selectedSubscriptionId, itemKey));
    var pending = _data.pendingItemKeys.contains(itemKey);
    return Padding(
      key: key,
      padding: EdgeInsets.only(bottom: widget.embedded ? 8 : 6),
      child: BmfRssItem(
        release: release,
        isPending: pending,
        spacious: widget.embedded,
        actions: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pending)
              Tooltip(
                message: '标记为已处理',
                child: IconButton(
                  icon: BtIcon(FluentIcons.check_mark, size: 14),
                  onPressed: () => _data.markItemHandled(release.item),
                ),
              ),
            _RssItemActions(
              key: key,
              release: release,
              source: _data.source,
              dir: widget.bmf.download,
              subjectId: widget.bmf.subject,
              baseUrl: Uri.tryParse(release.detailUrl ?? _data.rssUrl),
              onHandled: () => _data.markItemHandled(release.item),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildContent() {
    if (_data.rssItems.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('没有找到任何 RSS 信息', style: BTTypography.body(context)),
      );
    }

    var groups = _data.rssGroups;
    var count = groups.isEmpty ? _data.rssReleases.length : groups.length;

    Widget buildEntry(int index) {
      if (groups.isEmpty) {
        return buildRssItem(context, _data.rssReleases[index]);
      }
      var group = groups[index];
      var pendingCount = group.releases.where((release) {
        return _data.pendingItemKeys.contains(_data.itemKey(release.item));
      }).length;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _RssSubtitleGroup(
          key: ValueKey((_data.selectedSubscriptionId, group.key)),
          group: group,
          pendingCount: pendingCount,
          maxHeight: widget.maxHeight,
          itemBuilder: (release) => buildRssItem(context, release),
        ),
      );
    }

    if (!widget.contentScrollable || count <= 6) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, buildEntry),
      );
    }

    return SizedBox(
      height: widget.maxHeight,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: count,
        itemBuilder: (_, index) => buildEntry(index),
      ),
    );
  }

  Widget _buildCountBadge(BuildContext context, int count) {
    var accentColor = FluentTheme.of(context).accentColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: accentColor,
        ),
      ),
    );
  }

  String _sourceLabel(String provider) =>
      RssReleaseSource.fromProvider(provider).label;

  Future<void> _showSourceOptions() async {
    if (_sourceFlyout.isOpen) return;
    var id = await _sourceFlyout.showFlyout<int>(
      autoModeConfiguration: FlyoutAutoConfiguration(
        preferredMode: FlyoutPlacementMode.bottomRight,
      ),
      additionalOffset: 8,
      forceAvailableSpace: true,
      builder: (flyoutContext) => MenuFlyout(
        constraints: const BoxConstraints(minWidth: 160, maxWidth: 240),
        items: [
          for (var subscription in widget.bmf.subscriptions)
            MenuFlyoutItem(
              text: Tooltip(
                message: subscription.url,
                child: Text(_sourceLabel(subscription.provider)),
              ),
              selected: subscription.id == _data.selectedSubscriptionId,
              trailing: subscription.id == _data.selectedSubscriptionId
                  ? const Icon(FluentIcons.check_mark, size: 12)
                  : null,
              closeAfterClick: false,
              onPressed: () => Navigator.of(flyoutContext).pop(subscription.id),
            ),
        ],
      ),
    );
    if (!mounted || id == null || id == _data.selectedSubscriptionId) return;
    if (!widget.bmf.subscriptions.any(
      (subscription) => subscription.id == id,
    )) {
      return;
    }
    setState(() => _data.selectSubscription(id));
  }

  Widget _buildSourceButton() {
    var selected = widget.bmf.subscriptions
        .where(
          (subscription) => subscription.id == _data.selectedSubscriptionId,
        )
        .firstOrNull;
    var label = selected == null ? null : _sourceLabel(selected.provider);
    return FlyoutTarget(
      controller: _sourceFlyout,
      child: Tooltip(
        message: label == null ? '切换来源' : '切换来源（当前：$label）',
        child: IconButton(
          icon: BtIcon(MdiIcons.swapHorizontal, size: 14),
          onPressed: () => unawaited(_showSourceOptions()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;
    var rssLink = _data.rssUrl;

    var metadata = Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          widget.embedded ? '${_data.rssItems.length} 条资源' : 'RSS 订阅',
          style: widget.embedded
              ? BTTypography.caption(context)
              : BTTypography.subtitle(context),
        ),
        Text(_data.source.label, style: BTTypography.caption(context)),
        RssRefreshStatus(lastUpdated: _data.lastUpdated),
        if (!widget.embedded && _data.rssItems.isNotEmpty)
          _buildCountBadge(context, _data.rssItems.length),
        if (_data.pendingItemKeys.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BTRadius.roundBR,
            ),
            child: Text(
              '${_data.pendingItemKeys.length} 条更新',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Tooltip(
          message: rssLink,
          child: Icon(
            FluentIcons.info,
            size: 14,
            color: BTColors.textTertiary(context),
          ),
        ),
      ],
    );
    var actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.bmf.subscriptions.length > 1) _buildSourceButton(),
        if (_data.pendingItemKeys.isNotEmpty)
          Tooltip(
            message: '全部标记为已处理',
            child: IconButton(
              icon: BtIcon(FluentIcons.clear_selection, size: 14),
              onPressed: _data.markAllHandled,
            ),
          ),
        if (widget.onDelete != null)
          Tooltip(
            message: '删除订阅',
            child: IconButton(
              icon: BtIcon(
                FluentIcons.delete,
                size: 14,
                color: FluentTheme.of(context).accentColor,
              ),
              onPressed: () async {
                var confirm = await showConfirm(
                  context,
                  title: '删除 RSS 订阅',
                  content: '确定删除该 RSS 订阅配置吗？',
                );
                if (!confirm) return;
                var id = _data.selectedSubscriptionId;
                if (id != null) await widget.onDelete!(id);
              },
            ),
          ),
        Tooltip(
          message: '刷新 RSS',
          child: IconButton(
            icon: BtIcon(FluentIcons.refresh, size: 14),
            onPressed: _data.subscription?.canRefresh != true
                ? null
                : () async {
                    var result = await BmfRssService.instance
                        .refreshSubscription(_data.selectedSubscriptionId!);
                    if (!context.mounted) return;
                    if (result) {
                      await BtInfobar.success(context, 'RSS 刷新成功');
                    } else {
                      await BtInfobar.error(context, 'RSS 刷新失败');
                    }
                  },
          ),
        ),
        Tooltip(
          message: '打开 RSS',
          child: IconButton(
            icon: BtIcon(FluentIcons.edge_logo, size: 14),
            onPressed: () async => await launchUrlString(rssLink),
          ),
        ),
      ],
    );

    var header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: metadata),
            const SizedBox(width: 12),
            actions,
          ],
        ),
        if (_data.subscription?.status == 'needsReview')
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('订阅待核对，请在 BMF 工作台确认旧状态归属或修正地址'),
          ),
      ],
    );

    if (!widget.expandable) {
      return _buildFixedResourcePanel(
        context,
        leading: Icon(MdiIcons.rss, size: 18, color: accentColor),
        header: header,
        content: buildContent(),
        controller: widget.contentScrollController,
        embedded: widget.embedded,
      );
    }

    return Expander(
      initiallyExpanded: widget.initiallyExpanded,
      leading: Icon(MdiIcons.rss, size: 18, color: accentColor),
      header: header,
      content: buildContent(),
    );
  }
}

class _RssSubtitleGroup extends StatefulWidget {
  final RssReleaseGroup group;
  final int pendingCount;
  final double maxHeight;
  final Widget Function(RssReleaseData release) itemBuilder;

  const _RssSubtitleGroup({
    super.key,
    required this.group,
    required this.pendingCount,
    required this.maxHeight,
    required this.itemBuilder,
  });

  @override
  State<_RssSubtitleGroup> createState() => _RssSubtitleGroupState();
}

class _RssSubtitleGroupState extends State<_RssSubtitleGroup>
    with AutomaticKeepAliveClientMixin {
  bool _expanded = false;

  @override
  bool get wantKeepAlive => _expanded;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var group = widget.group;
    return Expander(
      onStateChanged: (expanded) {
        setState(() => _expanded = expanded);
        updateKeepAlive();
      },
      header: RssGroupHeader(
        name: group.name,
        count: group.releases.length,
        pendingCount: widget.pendingCount,
      ),
      content: !_expanded
          ? const SizedBox.shrink()
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxHeight),
              child: ListView.builder(
                shrinkWrap: true,
                primary: false,
                itemCount: group.releases.length,
                itemBuilder: (_, index) =>
                    widget.itemBuilder(group.releases[index]),
              ),
            ),
    );
  }
}
