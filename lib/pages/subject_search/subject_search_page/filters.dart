part of '../subject_search_page.dart';

mixin _SubjectSearchFilters on _SubjectSearchPageStateBase {
  /// 构建头部
  Widget buildHeader(BuildContext context) {
    return PageHeader(
      leading: IconButton(
        icon: const Icon(FluentIcons.back),
        onPressed: () {
          ref
              .read(navStoreProvider.notifier)
              .removeNavItem(SubjectSearchPage.title);
        },
      ),
      title: Text(
        SubjectSearchPage.title,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget buildTypeSelects() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: BangumiSubjectType.values.map((type) {
        return Padding(
          padding: EdgeInsets.only(right: 6),
          child: _FilterChip(
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
          ),
        );
      }).toList(),
    );
  }

  Widget buildNsfwCheck() {
    var nsfwLabel = nsfw == true ? '包含' : (nsfw == false ? '排除' : '全部');
    return _FilterChip(
      label: 'NSFW: $nsfwLabel',
      isSelected: nsfw != false,
      onTap: () {
        var index = nsfwList.indexOf(nsfw);
        if (index == -1) {
          BtInfobar.error(context, '未知值');
          return;
        }
        setState(() {
          nsfw = nsfwList[(index + 1) % nsfwList.length];
        });
      },
    );
  }

  Widget buildSearch() {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            children: [
              _AnimatedSearchButton(
                onPressed: () async => await search(),
                isLoading: loading,
              ),
              SizedBox(width: 10),
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
              SizedBox(width: 10),
              buildTypeSelects(),
              SizedBox(width: 6),
              buildNsfwCheck(),
            ],
          ),
          if (selectedTags.isNotEmpty || addingTag) ...[
            SizedBox(height: 8),
            _buildTagInputs(),
          ],
        ],
      ),
    );
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
          for (var tag in selectedTags)
            _FilterChip(
              key: ValueKey(tag),
              label: '标签: $tag',
              isSelected: true,
              onDeleted: () {
                setState(() {
                  selectedTags.remove(tag);
                });
              },
            ),
          if (addingTag)
            SizedBox(
              width: 200,
              child: TextBox(
                controller: tagController,
                focusNode: tagFocusNode,
                placeholder: '输入标签，回车确认',
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
