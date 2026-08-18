part of '../subject_detail_page.dart';

extension _SubjectDetailHeader on _SubjectDetailPageState {
  /// 构建顶部栏
  Widget buildHeader() {
    String? title;
    if (data == null) {
      title = 'ID: ${widget.id}';
    } else {
      title = data?.nameCn == '' ? data?.name : data?.nameCn;
    }
    var theme = FluentTheme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        bottom: 18,
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
                  .read(navStoreProvider)
                  .removeNavItem(
                    '${data!.type.label}详情 ${widget.id}',
                    type: BtmAppNavItemType.subject,
                    param: 'subjectDetail_${widget.id}',
                  );
            },
          ),
          Expanded(
            child: DefaultTextStyle.merge(
              style: theme.typography.title,
              child: Tooltip(
                message: title,
                child: Text(
                  '${data?.type.label ?? '条目'}详情：$title',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          SizedBox(width: PageHeader.horizontalPadding(context)),
          Tooltip(
            message: '刷新页面',
            child: IconButton(
              icon: const Icon(FluentIcons.refresh),
              onPressed: init,
            ),
          ),
          SizedBox(width: 8),
          const SdpLayoutSwitcher(),
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
