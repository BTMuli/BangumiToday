part of '../subject_search_page.dart';

mixin _SubjectSearchFilters on _SubjectSearchPageStateBase {
  /// 构建头部
  Widget buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          var title = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: '返回',
                child: IconButton(
                  icon: const Icon(FluentIcons.back, semanticLabel: '返回'),
                  onPressed: () => ref
                      .read(navStoreProvider.notifier)
                      .removeNavItem(SubjectSearchPage.title),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                SubjectSearchPage.title,
                style: BTTypography.subtitle(
                  context,
                ).copyWith(fontSize: 24, fontWeight: FontWeight.w600),
              ),
            ],
          );
          var searchBox = Row(
            children: [
              Expanded(
                child: _AnimatedSearchBox(
                  controller: textController,
                  focusNode: searchFocusNode,
                  onAddTag: _beginTagInput,
                  addingTag: addingTag,
                  onSubmitted: (_) async => await search(),
                  onClear: () {
                    textController.clear();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: loading ? '正在搜索' : '搜索',
                child: _AnimatedSearchButton(
                  onPressed: () async => await search(),
                  isLoading: loading,
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 10), searchBox],
            );
          }
          return Row(
            children: [
              title,
              const SizedBox(width: 24),
              Expanded(child: searchBox),
            ],
          );
        },
      ),
    );
  }

  Widget buildTypeSelects() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: BangumiSubjectType.values.map((type) {
        return _FilterChip(
          label: type.label,
          isSelected: types.contains(type),
          onTap: () {
            setState(() {
              if (types.contains(type)) {
                types.remove(type);
              } else {
                types.add(type);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget buildNsfwCheck() {
    return Tooltip(
      message: '包含 NSFW 内容需要账号具备相应权限',
      child: _FilterChip(
        label: nsfw == false ? '排除 NSFW' : '包含 NSFW',
        isSelected: nsfw != false,
        onTap: () => setState(() => nsfw = nsfw == false ? null : false),
      ),
    );
  }

  Widget buildSearch() {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BTRadius.largeBR,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _filterLabel('分类'),
              const SizedBox(width: 14),
              Expanded(child: buildTypeSelects()),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: const Divider(),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              var sortControls = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _filterLabel('排序'),
                  const SizedBox(width: 14),
                  buildSortSelect(),
                ],
              );
              var filterActions = Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  buildNsfwCheck(),
                  _filterAction(
                    '浏览热门标签',
                    FluentIcons.tag_group,
                    tagDrawerOpen,
                    () async => await _openTagDrawer(),
                  ),
                  _filterAction(
                    '条件筛选：日期、评分和排名',
                    FluentIcons.filter,
                    filterDrawerOpen || _draftQuery.hasRangeFilters,
                    () async => await _openFilterDrawer(),
                  ),
                  Tooltip(
                    message: '重置筛选',
                    child: IconButton(
                      icon: const Icon(
                        FluentIcons.clear_filter,
                        size: 14,
                        semanticLabel: '重置筛选',
                      ),
                      onPressed: () async => await _resetFilters(),
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 650) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sortControls,
                    const SizedBox(height: 10),
                    filterActions,
                  ],
                );
              }
              return Row(
                children: [sortControls, const Spacer(), filterActions],
              );
            },
          ),
          if (selectedTags.isNotEmpty ||
              selectedMetaTags.isNotEmpty ||
              _draftQuery.hasRangeFilters ||
              addingTag) ...[
            SizedBox(height: 8),
            _buildTagInputs(),
          ],
        ],
      ),
    );
  }

  Widget _filterLabel(String label) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Text(label, style: BTTypography.caption(context)),
  );

  Widget _filterAction(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onPressed,
  ) => Tooltip(
    message: label,
    child: IconButton(
      icon: Icon(
        icon,
        size: 14,
        semanticLabel: label,
        color: selected ? FluentTheme.of(context).accentColor : null,
      ),
      onPressed: onPressed,
    ),
  );

  List<Widget> _buildRangeChips() {
    var chips = <Widget>[];
    for (var range in [
      ('date', '日期范围', FluentIcons.calendar),
      ('rating', '评分范围', FluentIcons.favorite_star_fill),
      ('rank', '排名范围', FluentIcons.bar_chart4),
    ]) {
      var from = rangeControllers['${range.$1}From']!.text.trim();
      var to = rangeControllers['${range.$1}To']!.text.trim();
      if (from.isEmpty && to.isEmpty) continue;
      var lower = from.isNotEmpty ? from : (range.$1 == 'rank' ? '1' : '不限');
      var label = '$lower～${to.isEmpty ? '不限' : to}';
      chips.add(
        _FilterChip(
          key: ValueKey(('range', range.$1)),
          label: label,
          icon: range.$3,
          tooltip: '${range.$2}：$label',
          isSelected: true,
          onTap: _openFilterDrawer,
          onDeleted: () async {
            setState(() {
              rangeControllers['${range.$1}From']!.clear();
              rangeControllers['${range.$1}To']!.clear();
            });
            if (_activeQuery != null) await search();
          },
        ),
      );
    }
    return chips;
  }

  Widget _buildTagInputs() {
    var accentColor = FluentTheme.of(context).accentColor;
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ..._buildRangeChips(),
          for (var tag in selectedTags)
            _FilterChip(
              key: ValueKey(('tag', tag)),
              label: tag,
              icon: FluentIcons.tag,
              tooltip: '普通标签：$tag',
              isSelected: true,
              onDeleted: () {
                setState(() {
                  selectedTags.remove(tag);
                });
              },
            ),
          for (var tag in selectedMetaTags)
            _FilterChip(
              key: ValueKey(('meta', tag)),
              label: tag,
              icon: FluentIcons.tag_group,
              tooltip: '公共标签：$tag',
              isSelected: true,
              onDeleted: () => setState(() => selectedMetaTags.remove(tag)),
            ),
          if (addingTag)
            DropDownButton(
              title: Text(tagIsMeta ? '公共标签' : '普通标签'),
              placement: FlyoutPlacementMode.bottomLeft,
              items: [
                for (var meta in [false, true])
                  MenuFlyoutItem(
                    text: Text(meta ? '公共标签' : '普通标签'),
                    selected: tagIsMeta == meta,
                    onPressed: () {
                      setState(() => tagIsMeta = meta);
                      tagFocusNode.requestFocus();
                    },
                  ),
              ],
            ),
          if (addingTag)
            SizedBox(
              width: 200,
              child: TextBox(
                controller: tagController,
                focusNode: tagFocusNode,
                placeholder: tagIsMeta ? '公共标签，回车确认' : '输入标签，回车确认',
                style: BTTypography.caption(context),
                decoration: WidgetStatePropertyAll(
                  BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BTRadius.roundBR,
                    border: Border.all(color: accentColor),
                  ),
                ),
                prefix: Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Icon(FluentIcons.tag, size: 12, color: accentColor),
                ),
                suffix: Tooltip(
                  message: '取消添加标签',
                  child: IconButton(
                    icon: const Icon(
                      FluentIcons.clear,
                      size: 12,
                      semanticLabel: '取消添加标签',
                    ),
                    onPressed: _cancelTagInput,
                  ),
                ),
                onSubmitted: _completeTagInput,
              ),
            ),
        ],
      ),
    );
  }
}
