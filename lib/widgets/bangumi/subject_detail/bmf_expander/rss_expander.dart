part of '../bmf_expander.dart';

class BmfRssExpander extends ConsumerStatefulWidget {
  final AppBmfModel bmf;
  final bool isConfig;
  final double maxHeight;
  final Future<void> Function()? onDelete;
  final bool initiallyExpanded;
  final bool contentScrollable;
  final bool expandable;
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
    this.contentScrollController,
  });

  @override
  ConsumerState<BmfRssExpander> createState() => _BmfRssExpanderState();
}

class _BmfRssExpanderState extends ConsumerState<BmfRssExpander> {
  late final BmfRssData _data = BmfRssData(
    sqlite: BtsAppRss(),
    bmf: widget.bmf,
  );
  StreamSubscription<BmfRssUpdateEvent>? _updateSubscription;

  String? get _updateKey {
    var bmf = widget.bmf;
    if (bmf.mkBgmId != null && bmf.mkBgmId!.isNotEmpty) return bmf.mkBgmId;
    return bmf.rss;
  }

  String? get mikanRss => ref.watch(appStoreProvider).mikanRss;

  @override
  void initState() {
    super.initState();
    _data.mikanRss = mikanRss;
    _data.addListener(_onDataChanged);
    _listenToUpdate();
    Future.microtask(_data.load);
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  void _listenToUpdate() {
    var key = _updateKey;
    if (key == null) return;
    _updateSubscription = BmfRssService.instance.updateStream
        .where((event) => event.key == key)
        .listen((event) {
          if (!mounted || _updateKey != key) return;
          _data.applyUpdate(event);
        });
  }

  @override
  void didUpdateWidget(BmfRssExpander oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bmf.rss != widget.bmf.rss ||
        oldWidget.bmf.mkBgmId != widget.bmf.mkBgmId ||
        oldWidget.bmf.mkGroupId != widget.bmf.mkGroupId) {
      _updateSubscription?.cancel();
      _updateSubscription = null;
      _data.updateBmf(widget.bmf, mikanRss: mikanRss);
      _listenToUpdate();
    }
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    _data.removeListener(_onDataChanged);
    _data.dispose();
    super.dispose();
  }

  Widget buildRssItem(BuildContext context, RssItem item) {
    var fileSize = item.enclosure?.length != null
        ? filesize(item.enclosure!.length)
        : null;
    var isPending = _data.pendingItemKeys.contains(_data.itemKey(item));
    var accentColor = FluentTheme.of(context).accentColor;

    return Container(
      margin: EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isPending
            ? accentColor.withValues(alpha: 0.1)
            : BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.smallBR,
        border: Border.all(
          color: isPending ? accentColor : BTColors.divider(context),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                MdiIcons.download,
                size: 16,
                color: isPending
                    ? accentColor
                    : BTColors.textSecondary(context),
              ),
              SizedBox(width: 8),
              if (isPending) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BTRadius.roundBR,
                  ),
                  child: Text(
                    '新',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 7),
              ],
              Expanded(
                child: Tooltip(
                  message: item.title ?? '',
                  child: Text(
                    item.title ?? '',
                    style: BTTypography.body(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: [
              if (fileSize != null) ...[
                Icon(
                  FluentIcons.save,
                  size: 10,
                  color: BTColors.textTertiary(context),
                ),
                SizedBox(width: 4),
                Text(fileSize, style: BTTypography.caption(context)),
                SizedBox(width: 12),
              ],
              if (item.pubDate != null) ...[
                Icon(
                  FluentIcons.clock,
                  size: 10,
                  color: BTColors.textTertiary(context),
                ),
                SizedBox(width: 4),
                Text(
                  item.pubDate!.length > 10
                      ? item.pubDate!.substring(0, 10)
                      : item.pubDate!,
                  style: BTTypography.caption(context),
                ),
              ],
              const Spacer(),
              if (isPending)
                Tooltip(
                  message: '标记为已处理',
                  child: IconButton(
                    icon: BtIcon(FluentIcons.check_mark, size: 14),
                    onPressed: () => _data.markItemHandled(item),
                  ),
                ),
              _RssItemActions(
                item: item,
                dir: widget.bmf.download,
                subject: widget.bmf.subject,
                rssLink: widget.bmf.rss!,
                onHandled: () => _data.markItemHandled(item),
              ),
            ],
          ),
        ],
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

    if (!widget.contentScrollable || _data.rssItems.length <= 6) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: _data.rssItems
            .map((item) => buildRssItem(context, item))
            .toList(),
      );
    }

    return SizedBox(
      height: widget.maxHeight,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _data.rssItems.length,
        itemBuilder: (context, index) {
          return buildRssItem(context, _data.rssItems[index]);
        },
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

  @override
  Widget build(BuildContext context) {
    _data.mikanRss = mikanRss;
    var accentColor = FluentTheme.of(context).accentColor;
    var rssLink = _data.rssUrl;

    var header = Row(
      children: [
        Text('RSS 订阅', style: BTTypography.subtitle(context)),
        if (_data.rssItems.isNotEmpty) ...[
          SizedBox(width: 8),
          _buildCountBadge(context, _data.rssItems.length),
        ],
        if (_data.pendingItemKeys.isNotEmpty) ...[
          SizedBox(width: 8),
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
        ],
        SizedBox(width: 8),
        Tooltip(
          message: rssLink,
          child: Icon(
            FluentIcons.info,
            size: 14,
            color: BTColors.textTertiary(context),
          ),
        ),
        const Spacer(),
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
                await widget.onDelete!();
              },
            ),
          ),
        Tooltip(
          message: '刷新 RSS',
          child: IconButton(
            icon: BtIcon(FluentIcons.refresh, size: 14),
            onPressed: () async {
              var result = await BmfRssService.instance.refreshBmf(widget.bmf);
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

    if (!widget.expandable) {
      return _buildFixedResourcePanel(
        context,
        leading: Icon(MdiIcons.rss, size: 18, color: accentColor),
        header: header,
        content: buildContent(),
        controller: widget.contentScrollController,
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
