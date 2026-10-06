part of '../subject_detail_resources.dart';

extension _ResourceRss on _SubjectDetailResourcesState {
  String _sourceLabel(String provider) =>
      RssReleaseSource.fromProvider(provider).label;

  Future<void> _selectSource() async {
    if (_sourceFlyout.isOpen) return;
    var id = await _sourceFlyout.showFlyout<int>(
      autoModeConfiguration: FlyoutAutoConfiguration(
        preferredMode: FlyoutPlacementMode.bottomLeft,
      ),
      additionalOffset: 8,
      forceAvailableSpace: true,
      builder: (flyoutContext) => MenuFlyout(
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 360),
        items: [
          for (var (index, subscription) in _bmf.subscriptions.indexed)
            MenuFlyoutItem(
              text: Tooltip(
                message: subscription.url,
                child: Text(
                  '${_sourceLabel(subscription.provider)} · 订阅 ${index + 1}',
                ),
              ),
              selected: subscription.id == _rss.selectedSubscriptionId,
              trailing: subscription.id == _rss.selectedSubscriptionId
                  ? const Icon(FluentIcons.check_mark, size: 12)
                  : null,
              closeAfterClick: false,
              onPressed: () => Navigator.of(flyoutContext).pop(subscription.id),
            ),
        ],
      ),
    );
    if (!mounted || id == null || !_bmf.subscriptions.any((s) => s.id == id)) {
      return;
    }
    _update(() => _rss.selectSubscription(id));
  }

  Widget _buildRss() {
    if (_bmf.subscriptions.isEmpty) {
      return _emptyState(
        '尚未订阅资源',
        action: () => _run(_searchRss),
        label: '搜索订阅',
      );
    }
    var id = _rss.selectedSubscriptionId;
    var source = _rss.source;
    var subscription = _rss.subscription;
    var sourceIndex = _bmf.subscriptions.indexWhere((s) => s.id == id) + 1;
    // 将字幕组与资源行展开为同一个惰性列表，不再嵌套多个滚动面板。
    var entries = <Object>[];
    if (_rss.rssGroups.isEmpty) {
      entries.addAll(_rss.rssReleases);
    } else {
      for (var group in _rss.rssGroups) {
        entries.add(group);
        if (!_collapsedGroups.contains((id, group.key))) {
          entries.addAll(group.releases);
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FlyoutTarget(
                controller: _sourceFlyout,
                child: Button(
                  onPressed: _bmf.subscriptions.length > 1
                      ? _selectSource
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${source.label} · 订阅 $sourceIndex'),
                      if (_bmf.subscriptions.length > 1) ...[
                        const SizedBox(width: 8),
                        const Icon(FluentIcons.chevron_down, size: 10),
                      ],
                    ],
                  ),
                ),
              ),
              if (_rss.pendingItemKeys.isNotEmpty)
                _badge('${_rss.pendingItemKeys.length} 条更新'),
              _iconAction(
                '刷新订阅',
                FluentIcons.refresh,
                _refreshingRss || subscription?.canRefresh != true
                    ? null
                    : _refreshRss,
              ),
              _iconAction(
                '打开 RSS',
                FluentIcons.open_in_new_window,
                () => _openLink(_rss.rssUrl, source),
              ),
              if (_rss.pendingItemKeys.isNotEmpty)
                _iconAction(
                  '全部标记为已处理',
                  FluentIcons.check_mark,
                  () => _run(_rss.markAllHandled),
                ),
              _iconAction(
                '删除当前订阅',
                FluentIcons.delete,
                _busy || id == null
                    ? null
                    : () => _run(() => _removeSubscription(id)),
              ),
              if (_refreshingRss)
                const SizedBox.square(
                  dimension: 16,
                  child: ProgressRing(strokeWidth: 2),
                ),
            ],
          ),
        ),
        if (subscription?.status == 'needsReview')
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('订阅待核对，请在 BMF 工作台确认旧状态归属或修正地址'),
          ),
        Expanded(
          child: entries.isEmpty
              ? _emptyState('暂无缓存资源，可刷新订阅获取最新内容')
              : ListView.separated(
                  key: PageStorageKey('subject-${widget.subjectId}-rss-$id'),
                  primary: false,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    var entry = entries[index];
                    return entry is RssReleaseGroup
                        ? _buildGroup(entry, id)
                        : _buildRelease(entry as RssReleaseData, source, id);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGroup(RssReleaseGroup group, int? id) {
    var collapsed = _collapsedGroups.contains((id, group.key));
    var pending = group.releases
        .where(
          (release) =>
              _rss.pendingItemKeys.contains(_rss.itemKey(release.item)),
        )
        .length;
    return Button(
      onPressed: () => _update(() {
        if (collapsed) {
          _collapsedGroups.remove((id, group.key));
        } else {
          _collapsedGroups.add((id, group.key));
        }
      }),
      child: Row(
        children: [
          Icon(
            collapsed ? FluentIcons.chevron_right : FluentIcons.chevron_down,
            size: 12,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('${group.name} · ${group.releases.length} 条资源')),
          if (pending > 0) _badge('$pending 条更新'),
        ],
      ),
    );
  }

  Widget _buildRelease(
    RssReleaseData release,
    RssReleaseSource source,
    int? id,
  ) {
    var pending = _rss.pendingItemKeys.contains(_rss.itemKey(release.item));
    var downloading = _downloading.contains((id, release.key));
    return BmfRssItem(
      release: release,
      backgroundColor: SubjectDetailColors.card(context),
      isPending: pending,
      spacious: true,
      actions: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (downloading)
            const SizedBox.square(
              dimension: 16,
              child: ProgressRing(strokeWidth: 2),
            ),
          _iconAction(
            downloading ? '正在添加下载任务' : '下载',
            FluentIcons.download,
            downloading || !release.canDownload
                ? null
                : () => _download(release, source, id),
          ),
          if (release.hasDescription)
            _iconAction(
              '资源详情',
              FluentIcons.info,
              () => _showReleaseDetails(release, source, id),
            ),
          if (release.detailUrl != null)
            _iconAction(
              '打开资源页面',
              FluentIcons.open_in_new_window,
              () => _openLink(release.detailUrl!, source),
            ),
          if (pending)
            _iconAction(
              '标记为已处理',
              FluentIcons.check_mark,
              () => _run(() => _markHandled(release, id)),
            ),
        ],
      ),
    );
  }
}
