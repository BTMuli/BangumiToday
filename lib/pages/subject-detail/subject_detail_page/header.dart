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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: '复制标题',
                child: IconButton(
                  icon: const Icon(FluentIcons.copy),
                  onPressed: () {
                    if (title == null) {
                      BtInfobar.error(context, '标题为空');
                      return;
                    }
                    Clipboard.setData(ClipboardData(text: title));
                    BtInfobar.success(context, '已复制标题: $title');
                  },
                ),
              ),
              Tooltip(
                message: '刷新页面',
                child: IconButton(
                  icon: const Icon(FluentIcons.refresh),
                  onPressed: init,
                ),
              ),
              Tooltip(
                message: '搜索RSS(Mikan)',
                child: IconButton(
                  icon: const Icon(FluentIcons.search),
                  onPressed: searchBangumi,
                ),
              ),
            ],
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

  Widget _buildBmfDrawerButton(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;
    return Tooltip(
      message: '打开 BMF 配置',
      excludeFromSemantics: true,
      child: IconButton(
        icon: Icon(FluentIcons.app_icon_default, size: 18, color: accentColor),
        onPressed: () => showBTDrawer(
          context: context,
          width: 420,
          child: BsdBmfDrawer(
            subjectId: data!.id,
            title: data!.nameCn.isEmpty ? data!.name : data!.nameCn,
            airDate: data!.date,
            rssProvider: rssProvider,
          ),
        ),
      ),
    );
  }
}
