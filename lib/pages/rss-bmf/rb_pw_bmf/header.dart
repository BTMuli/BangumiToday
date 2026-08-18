part of '../rb_pw_bmf.dart';

mixin _RbpBmfHeader on _RbpBmfStateBase {
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            padding: EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: FluentTheme.of(
                context,
              ).accentColor.withValues(alpha: 0.14),
              borderRadius: BTRadius.mediumBR,
            ),
            child: Image.asset('assets/images/logo.png'),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BMF 工作台', style: BTTypography.title(context)),
                Text(
                  '集中管理番剧、RSS 订阅与本地目录的关联',
                  style: BTTypography.caption(context),
                ),
              ],
            ),
          ),
          Text(
            '${_filterModel.filterStats.total} 个关联',
            style: BTTypography.caption(context),
          ),
          SizedBox(width: 8),
          Tooltip(
            message: '刷新 BMF 配置',
            child: IconButton(
              icon: BtIcon(FluentIcons.refresh, size: 15),
              onPressed: () async {
                await ref.read(bmfListProvider.notifier).refresh();
                if (context.mounted) {
                  await BtInfobar.success(context, 'BMF 配置刷新完成');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 4, 18, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          var filters = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                context,
                label: '全部',
                count: _filterModel.filterStats.total,
                value: BmfConfigurationFilter.all,
              ),
              _buildFilterChip(
                context,
                label: '有更新',
                count: _filterModel.filterStats.updates,
                value: BmfConfigurationFilter.updates,
              ),
              _buildFilterChip(
                context,
                label: '已关联 RSS',
                count: _filterModel.filterStats.hasRss,
                value: BmfConfigurationFilter.hasRss,
              ),
              _buildFilterChip(
                context,
                label: '自动更新',
                count: _filterModel.filterStats.autoUpdate,
                value: BmfConfigurationFilter.autoUpdate,
              ),
              _buildFilterChip(
                context,
                label: '手动更新',
                count: _filterModel.filterStats.manualUpdate,
                value: BmfConfigurationFilter.manualUpdate,
              ),
              _buildFilterChip(
                context,
                label: '待补全',
                count: _filterModel.filterStats.incomplete,
                value: BmfConfigurationFilter.incomplete,
              ),
            ],
          );
          var controls = Row(
            children: [
              SizedBox(width: 140, child: _buildQuarterFilter()),
              SizedBox(width: 8),
              Expanded(
                child: TextBox(
                  controller: _searchController,
                  placeholder: '搜索番剧标题或 ID…',
                  prefix: BtIcon(FluentIcons.search, size: 14),
                  suffix: _filterModel.searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: BtIcon(FluentIcons.clear, size: 12),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _filterModel.searchQuery = '');
                          },
                        ),
                  onChanged: onSearch,
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 860) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [filters, SizedBox(height: 8), controls],
            );
          }
          return Row(
            children: [
              Expanded(child: filters),
              SizedBox(width: 12),
              SizedBox(width: 430, child: controls),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required int count,
    required BmfConfigurationFilter value,
  }) {
    var selected = _filterModel.configurationFilter == value;
    var accent = FluentTheme.of(context).accentColor;
    return Button(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(
          selected
              ? accent.withValues(alpha: 0.15)
              : BTColors.surfaceSecondary(context),
        ),
      ),
      onPressed: () => setState(() => _filterModel.configurationFilter = value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? accent : BTColors.textPrimary(context),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          SizedBox(width: 6),
          Text(
            '$count',
            style: BTTypography.caption(context).copyWith(
              color: selected ? accent : BTColors.textTertiary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuarterFilter() {
    return ComboBox<BmfQuarter>(
      value: _filterModel.selectedQuarter,
      isExpanded: true,
      items: [
        const ComboBoxItem<BmfQuarter>(
          value: BmfQuarter.all,
          child: Text('全部季度'),
        ),
        ..._filterModel.quarterOptions.map(
          (quarter) => ComboBoxItem<BmfQuarter>(
            value: quarter,
            child: Text(quarter.label),
          ),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _filterModel.selectedQuarter = value);
        }
      },
    );
  }
}
