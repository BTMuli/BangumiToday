part of '../subject_detail_page.dart';

extension _SubjectDetailHeader on _SubjectDetailPageState {
  /// 构建顶部栏
  Widget buildHeader() {
    var theme = FluentTheme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        bottom: 8,
        end: PageHeader.horizontalPadding(context),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(FluentIcons.back),
            onPressed: () {
              if (data == null) {
                BtInfobar.error(context, '数据为空');
                return;
              }
              ref
                  .read(navStoreProvider.notifier)
                  .removeNavItem(
                    '${data!.type.label}详情 ${widget.id}',
                    type: BtmAppNavItemType.subject,
                    param: 'subjectDetail_${widget.id}',
                  );
            },
          ),
          Expanded(
            child: DefaultTextStyle.merge(
              style: theme.typography.subtitle,
              child: Text(
                '${data?.type.label ?? '条目'}详情',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(width: PageHeader.horizontalPadding(context)),
          Tooltip(
            message: '搜索 RSS（AniBT / Mikan）',
            child: IconButton(
              icon: const Icon(FluentIcons.search, size: 16),
              onPressed: data == null ? null : searchRss,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: _refreshing ? '正在刷新' : '刷新页面',
            child: IconButton(
              icon: _refreshing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  : const Icon(FluentIcons.refresh, size: 16),
              onPressed: _refreshing ? null : refresh,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建加载中
  Widget buildLoading() {
    if (showError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(FluentIcons.error),
            SizedBox(height: 12),
            const Text('Error: 加载失败'),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ProgressRing(),
          SizedBox(height: 12),
          const Text('Loading...'),
        ],
      ),
    );
  }
}
