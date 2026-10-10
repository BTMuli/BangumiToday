part of '../subject_search_page.dart';

mixin _SubjectSearchResults on _SubjectSearchPageStateBase {
  Widget buildResult() {
    if (loading) {
      return BTEmptyState.loading(message: '正在搜索...');
    }
    if (controller.total == 0) {
      return BTEmptyState.noSearchResult(
        keyword:
            (_activeQuery ??
                    SubjectSearchQuery(
                      keyword: textController.text,
                      tags: selectedTags,
                    ))
                .description,
        actionText: '清除搜索',
        onAction: () {
          textController.clear();
          selectedTags.clear();
          tagController.clear();
          addingTag = false;
          _resetResults();
          setState(() {});
        },
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                Text(
                  '找到 $totalResults 个结果',
                  style: TextStyle(
                    fontSize: 13,
                    color: BTColors.textSecondary(context),
                    fontWeight: FontWeight.w500,
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
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 168,
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
          ),
        );
      },
    );
  }
}
