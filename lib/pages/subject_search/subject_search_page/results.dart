part of '../subject_search_page.dart';

mixin _SubjectSearchResults on _SubjectSearchPageStateBase {
  Widget buildResult() {
    if (loading) {
      return BTEmptyState.loading(message: '正在搜索...');
    }
    if (controller.total == 0) {
      return BTEmptyState.noSearchResult(
        keyword: (_activeQuery ?? _draftQuery).description,
        actionText: '清除搜索',
        onAction: () async => await _resetFilters(clearKeyword: true),
      );
    }
    return Column(
      children: [
        _buildResultSummary(),
        Expanded(child: _buildTwoColumnListView()),
      ],
    );
  }

  Widget _buildResultSummary() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  FluentIcons.search,
                  size: 14,
                  color: BTColors.textSecondary(context),
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Tooltip(
                    message: _activeQuery?.description ?? '',
                    child: Text(
                      '找到 $totalResults 个结果 · '
                      '${sortMap[_activeQuery?.sort] ?? '匹配度'}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: BTColors.textSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (controller.total > 1) ...[
            SizedBox(width: 8),
            PageWidget(controller),
          ],
        ],
      ),
    );
  }

  Widget _buildTwoColumnListView() {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: EdgeInsets.symmetric(vertical: 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: constraints.maxWidth >= 1000 ? 2 : 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: SubjectCardSearch.height,
        ),
        itemCount: result.length,
        itemBuilder: (context, index) {
          return BTFadeSlideIn(
            duration: const Duration(milliseconds: 300),
            delay: Duration(milliseconds: index * 50),
            offset: const Offset(0, 0.05),
            child: SubjectCardSearch(
              result[index],
              onTagTap: _searchByTag,
              onTagLongPress: _addSearchTag,
              onMetaTagTap: (tag) => _searchByTag(tag, isMeta: true),
              onMetaTagLongPress: (tag) => _addSearchTag(tag, isMeta: true),
            ),
          );
        },
      ),
    );
  }
}
