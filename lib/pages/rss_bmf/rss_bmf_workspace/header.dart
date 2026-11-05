part of '../rss_bmf_workspace.dart';

mixin _RssBmfWorkspaceHeader on _RssBmfWorkspaceStateBase {
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          var identity = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('BMF 工作台', style: BTTypography.title(context)),
              const SizedBox(width: 12),
              Text(
                '${_filterModel.filteredList.length} / '
                '${_filterModel.totalCount} 个关联',
                style: BTTypography.caption(context),
              ),
            ],
          );
          var refresh = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<bool>(
                stream: _hasUnresolvedRecovery,
                builder: (context, snapshot) {
                  if (snapshot.data != true) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Tooltip(
                      message: _clearingRecovery
                          ? '正在清理旧记录，暂不可核对'
                          : '打开待核对的旧订阅记录',
                      child: IconButton(
                        icon: const BtIcon(FluentIcons.warning, size: 15),
                        onPressed: _clearingRecovery
                            ? null
                            : () async {
                                await showDialog<void>(
                                  context: context,
                                  builder: (_) => const _RecoveryDialog(),
                                );
                                if (mounted) await _refreshWorkspace();
                              },
                      ),
                    ),
                  );
                },
              ),
              StreamBuilder<int>(
                stream: _recoveryCount,
                builder: (context, snapshot) {
                  var count = snapshot.data ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Tooltip(
                      message: _clearingRecovery
                          ? '正在清理旧记录…'
                          : '清理全部旧记录（$count）',
                      child: IconButton(
                        icon: SizedBox(
                          width: 22,
                          height: 18,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: BtIcon(FluentIcons.delete, size: 15),
                              ),
                              Positioned(
                                right: -2,
                                top: -4,
                                child: InfoBadge(
                                  source: Text(count > 99 ? '99+' : '$count'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        onPressed: _clearingRecovery
                            ? null
                            : _clearRecoveryRecords,
                      ),
                    ),
                  );
                },
              ),
              Tooltip(
                message: _refreshing
                    ? '正在刷新…'
                    : _clearingRecovery
                    ? '正在清理旧记录，暂不可刷新'
                    : '短按刷新自动更新的 RSS，长按刷新全部 RSS（含手动更新）',
                child: IconButton(
                  icon: _refreshing
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: ProgressRing(strokeWidth: 2),
                        )
                      : const BtIcon(FluentIcons.refresh, size: 15),
                  onPressed: _refreshing || _clearingRecovery
                      ? null
                      : () => _refreshWorkspace(refreshRss: true),
                  onLongPress: _refreshing || _clearingRecovery
                      ? null
                      : () => _refreshWorkspace(
                          refreshRss: true,
                          includeManual: true,
                        ),
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (constraints.maxWidth < 560) ...[
                  identity,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: refresh),
                ] else
                  Row(
                    children: [
                      Expanded(child: identity),
                      refresh,
                    ],
                  ),
                const SizedBox(height: 12),
                _buildSearchBox(),
              ],
            );
          }
          return Row(
            children: [
              identity,
              const Spacer(),
              SizedBox(
                width: (constraints.maxWidth * 0.34).clamp(260.0, 380.0),
                child: _buildSearchBox(),
              ),
              const SizedBox(width: 10),
              refresh,
            ],
          );
        },
      ),
    );
  }

  Future<void> _clearRecoveryRecords() async {
    if (_clearingRecovery) return;
    setState(() => _clearingRecovery = true);
    int? deleted;
    try {
      var confirmed = await showConfirmAction(
        context,
        title: '清理全部旧记录',
        content: '将永久删除所有已处理及待核对的旧记录，尚未分配的旧状态也会一并放弃。此操作无法撤销。',
        confirmText: '全部清理',
      );
      if (!confirmed || !mounted) return;
      deleted = await appSubscriptionStorage.clearRecovery();
      if (!mounted) return;
      await _refreshWorkspace();
      if (mounted) await BtInfobar.success(context, '已清理 $deleted 条旧记录');
    } catch (error) {
      BTLogTool.warn('旧记录清理或工作台刷新失败：$error');
      if (mounted) {
        await BtInfobar.error(
          context,
          deleted == null ? '清理旧记录失败，请重试' : '旧记录已清理，工作台刷新失败，请手动刷新',
        );
      }
    } finally {
      if (mounted) setState(() => _clearingRecovery = false);
    }
  }

  Widget _buildSearchBox() {
    return TextBox(
      controller: _searchController,
      placeholder: '搜索标题、原名或 Bangumi ID',
      prefix: const Padding(
        padding: EdgeInsets.only(left: 10),
        child: BtIcon(FluentIcons.search, size: 14),
      ),
      suffix: _searchController.text.isEmpty
          ? null
          : IconButton(
              icon: const BtIcon(FluentIcons.clear, size: 12),
              onPressed: () {
                _debounceTimer?.cancel();
                _searchController.clear();
                _changeListOptions(() => _filterModel.searchQuery = '');
              },
            ),
      onChanged: onSearch,
    );
  }

  int get _advancedFilterCount =>
      (_filterModel.associationFilter != BmfAssociationFilter.all ? 1 : 0) +
      (_filterModel.updateFilter != BmfUpdateFilter.all ? 1 : 0) +
      (_filterModel.broadcastFilter != BmfBroadcastFilter.all ? 1 : 0) +
      (_filterModel.selectedYears != null ? 1 : 0) +
      (_filterModel.selectedSeasons != null &&
              _filterModel.selectedSeasons!.isNotEmpty
          ? 1
          : 0);

  String get _advancedFilterSummary {
    var parts = <String>[];
    if (_filterModel.selectedYears != null) {
      var years = _filterModel.selectedYears!;
      if (years.length == 1 && years.contains(BmfQuarter.unknown.year)) {
        parts.add('年份未知');
      } else {
        parts.add('年份 ${years.length}');
      }
    }
    if (_filterModel.selectedSeasons != null &&
        _filterModel.selectedSeasons!.isNotEmpty) {
      parts.add('季度 ${_filterModel.selectedSeasons!.length}');
    }
    if (_filterModel.associationFilter != BmfAssociationFilter.all) {
      parts.add(_filterModel.associationFilter.label);
    }
    if (_filterModel.updateFilter != BmfUpdateFilter.all) {
      parts.add(_filterModel.updateFilter.label);
    }
    if (_filterModel.broadcastFilter != BmfBroadcastFilter.all) {
      parts.add(_filterModel.broadcastFilter.label);
    }
    return parts.join(' · ');
  }

  Widget _buildToolbar(BuildContext context) {
    var additionalFilters = _advancedFilterCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildFilterChip(
            context,
            label: '全部',
            count: _filterModel.filterStats.total,
            value: BmfConfigurationFilter.all,
          ),
          _buildFilterChip(
            context,
            label: '待处理',
            count: _filterModel.filterStats.updates,
            value: BmfConfigurationFilter.updates,
          ),
          _buildFilterChip(
            context,
            label: '待补全',
            count: _filterModel.filterStats.incomplete,
            value: BmfConfigurationFilter.incomplete,
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: _filterModel.sortOrder.description,
            child: SizedBox(
              width: 160,
              child: BtSelect<BmfSortOrder>(
                isExpanded: true,
                value: _filterModel.sortOrder,
                items: BmfSortOrder.values
                    .map(
                      (value) =>
                          ComboBoxItem(value: value, child: Text(value.label)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    _changeListOptions(() => _filterModel.sortOrder = value);
                  }
                },
              ),
            ),
          ),
          FlyoutTarget(
            controller: _filterFlyoutController,
            child: Button(
              onPressed: _showAdditionalFilters,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BtIcon(FluentIcons.filter, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    additionalFilters == 0
                        ? '更多筛选'
                        : '更多筛选 · $additionalFilters',
                  ),
                ],
              ),
            ),
          ),
          if (_filterModel.hasActiveFilters)
            Tooltip(
              message: '清除全部筛选',
              child: IconButton(
                icon: const BtIcon(FluentIcons.clear, size: 13),
                onPressed: _resetFilters,
              ),
            ),
        ],
      ),
    );
  }

  void _showAdditionalFilters() {
    _filterFlyoutController.showFlyout(
      placementMode: FlyoutPlacementMode.bottomRight,
      additionalOffset: 8,
      forceAvailableSpace: true,
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      dismissWithEsc: true,
      builder: (context) => FlyoutContent(
        child: SizedBox(
          width: 280,
          child: StatefulBuilder(
            builder: (context, updateFlyout) {
              void change(VoidCallback update) {
                _changeListOptions(update);
                updateFlyout(() {});
              }

              var summary = _advancedFilterSummary;
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('更多筛选', style: BTTypography.subtitle(context)),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '已选：$summary',
                        style: BTTypography.caption(
                          context,
                        ).copyWith(color: BTColors.textSecondary(context)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildAdditionalFilterRow(
                      context,
                      label: '年份',
                      child: _buildYearFilter(wrap: change),
                    ),
                    const SizedBox(height: 12),
                    _buildAdditionalFilterRow(
                      context,
                      label: '季度',
                      child: _buildQuarterFilter(wrap: change),
                    ),
                    const SizedBox(height: 12),
                    _buildAdditionalFilterRow(
                      context,
                      label: '资源关联',
                      child: BtSelect<BmfAssociationFilter>(
                        isExpanded: true,
                        value: _filterModel.associationFilter,
                        items: BmfAssociationFilter.values
                            .map(
                              (value) => ComboBoxItem(
                                value: value,
                                child: Text(value.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            change(
                              () => _filterModel.associationFilter = value,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAdditionalFilterRow(
                      context,
                      label: 'RSS 更新方式',
                      child: BtSelect<BmfUpdateFilter>(
                        isExpanded: true,
                        value: _filterModel.updateFilter,
                        items: BmfUpdateFilter.values
                            .map(
                              (value) => ComboBoxItem(
                                value: value,
                                child: Text(value.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            change(() => _filterModel.updateFilter = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAdditionalFilterRow(
                      context,
                      label: '放送状态',
                      child: BtSelect<BmfBroadcastFilter>(
                        isExpanded: true,
                        value: _filterModel.broadcastFilter,
                        items: BmfBroadcastFilter.values
                            .map(
                              (value) => ComboBoxItem(
                                value: value,
                                child: Text(value.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            change(() => _filterModel.broadcastFilter = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Button(
                          onPressed: () =>
                              change(_filterModel.selectCurrentQuarter),
                          child: const Text('只看本季'),
                        ),
                        const Spacer(),
                        HyperlinkButton(
                          onPressed: () {
                            _resetFilters();
                            updateFlyout(() {});
                          },
                          child: const Text('清除筛选'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalFilterRow(
    BuildContext context, {
    required String label,
    required Widget child,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: BTTypography.caption(context)),
        ),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required int count,
    required BmfConfigurationFilter value,
  }) {
    var selected = _filterModel.configurationFilter == value;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label，$count',
      child: ToggleButton(
        checked: selected,
        onChanged: (_) => _changeListOptions(() {
          _filterModel.configurationFilter = selected
              ? BmfConfigurationFilter.all
              : value;
        }),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 8),
            Builder(
              builder: (buttonContext) => Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? DefaultTextStyle.of(buttonContext).style.color
                      : BTColors.textSecondary(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearFilter({void Function(VoidCallback)? wrap}) {
    void apply(VoidCallback update) {
      if (wrap != null) {
        wrap(update);
      } else {
        _changeListOptions(update);
      }
    }

    return Tooltip(
      message: '按首播年份筛选',
      child: _BmfPeriodFilter(
        title: '年份',
        currentValue: BmfQuarter.current().year,
        currentLabel: '本年',
        selectedValues: _filterModel.selectedYears,
        options: {
          for (var year in _filterModel.yearOptions)
            year: year == BmfQuarter.unknown.year ? '日期未知' : '$year',
        },
        columns: 3,
        maxWidth: 280,
        maxHeight: 280,
        onChanged: (values) => apply(() => _filterModel.selectYears(values)),
      ),
    );
  }

  Widget _buildQuarterFilter({void Function(VoidCallback)? wrap}) {
    void apply(VoidCallback update) {
      if (wrap != null) {
        wrap(update);
      } else {
        _changeListOptions(update);
      }
    }

    return Tooltip(
      message: '按首播季度筛选；3、6、9、12 月 25 日起首播归入下一季',
      child: _BmfPeriodFilter(
        title: '季度',
        currentValue: BmfQuarter.current().quarter,
        currentLabel: '本季',
        selectedValues: _filterModel.selectedSeasons,
        options: const {1: '冬季', 2: '春季', 3: '夏季', 4: '秋季'},
        columns: 2,
        maxWidth: 200,
        maxHeight: 200,
        onChanged: _filterModel.hasOnlyUnknownYear
            ? null
            : (values) => apply(() => _filterModel.selectedSeasons = values),
      ),
    );
  }
}
