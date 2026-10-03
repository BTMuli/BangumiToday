part of '../subject_search_page.dart';

mixin _SubjectSearchFilters on _SubjectSearchPageStateBase {
  /// 构建头部
  Widget buildHeader(BuildContext context) {
    return PageHeader(
      leading: IconButton(
        icon: const Icon(FluentIcons.back),
        onPressed: () {
          ref.read(navStoreProvider).removeNavItem(pageTitle);
        },
      ),
      title: Text(
        pageTitle,
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
          if (types.isNotEmpty || selectedTag != null) ...[
            SizedBox(height: 8),
            _buildSelectedFilterChips(),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedFilterChips() {
    var chips = types.map((type) {
      return _FilterChip(
        label: type.label,
        isSelected: true,
        onDeleted: () {
          setState(() {
            types.remove(type);
          });
        },
      );
    }).toList();
    if (selectedTag != null) {
      chips.add(
        _FilterChip(
          label: '标签: $selectedTag',
          isSelected: true,
          onDeleted: () {
            selectedTag = null;
            _resetResults();
            setState(() {});
          },
        ),
      );
    }
    return Wrap(spacing: 6, runSpacing: 4, children: chips);
  }
}
