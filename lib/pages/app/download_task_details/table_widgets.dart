part of '../download_task_details.dart';

class _TableShell extends StatelessWidget {
  const _TableShell({
    required this.header,
    required this.itemCount,
    required this.itemBuilder,
    this.footer,
  });

  final Widget header;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(18),
      child: Container(
        decoration: BoxDecoration(
          color: BTColors.surfacePrimary(context),
          borderRadius: BTRadius.largeBR,
          border: Border.all(color: BTColors.divider(context)),
          boxShadow: BTTheme.shadow(context, level: BTShadowLevel.subtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            header,
            Expanded(
              child: ListView.builder(
                itemCount: itemCount,
                itemBuilder: itemBuilder,
              ),
            ),
            if (footer != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: BTColors.surfaceSecondary(context),
                child: Text(
                  footer!,
                  textAlign: TextAlign.center,
                  style: BTTypography.caption(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.columns,
    required this.flexes,
    this.sortIndex = -1,
    this.ascending = true,
    this.onSort,
    this.filterIndex = -1,
    this.filterActive = false,
    this.onFilter,
    this.filterController,
  });

  final List<String> columns;
  final List<int> flexes;

  /// 当前排序的列索引，-1 表示未排序
  final int sortIndex;

  /// 是否升序
  final bool ascending;

  /// 排序列点击回调
  final ValueChanged<int>? onSort;

  /// 支持筛选的列索引，-1 表示无
  final int filterIndex;

  /// 是否启用了筛选
  final bool filterActive;

  /// 筛选列点击回调
  final ValueChanged<int>? onFilter;

  /// 筛选列 Flyout 锚点控制器
  final FlyoutController? filterController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      color: BTColors.surfaceSecondary(context),
      child: Row(
        children: List.generate(columns.length, (index) {
          return Expanded(flex: flexes[index], child: _cell(context, index));
        }),
      ),
    );
  }

  Widget _cell(BuildContext context, int index) {
    var isFilterColumn = index == filterIndex && onFilter != null;
    if (isFilterColumn) {
      var cell = _clickable(
        context,
        index,
        active: filterActive,
        activeIcon: FluentIcons.filter,
        onTap: () => onFilter!(index),
      );
      var controller = filterController;
      if (controller != null) {
        return FlyoutTarget(controller: controller, child: cell);
      }
      return cell;
    }
    if (onSort == null) {
      return _plain(context, index);
    }
    return _clickable(
      context,
      index,
      active: index == sortIndex,
      activeIcon: ascending ? FluentIcons.chevron_up : FluentIcons.chevron_down,
      onTap: () => onSort!(index),
    );
  }

  Widget _plain(BuildContext context, int index) {
    return Text(
      columns[index],
      style: BTTypography.caption(
        context,
      ).copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _clickable(
    BuildContext context,
    int index, {
    required bool active,
    required IconData activeIcon,
    required VoidCallback onTap,
  }) {
    var accent = FluentTheme.of(context).accentColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  columns[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BTTypography.caption(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (active) ...[
                SizedBox(width: 4),
                Icon(activeIcon, size: 12, color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({required this.columns, required this.flexes});

  final List<Widget> columns;
  final List<int> flexes;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: BTTheme.animationDurationFast,
        padding: EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: _hovered
              ? FluentTheme.of(context).accentColor.withValues(alpha: 0.045)
              : Colors.transparent,
          border: Border(bottom: BorderSide(color: BTColors.divider(context))),
        ),
        child: DefaultTextStyle(
          style: BTTypography.caption(
            context,
          ).copyWith(color: BTColors.textPrimary(context)),
          child: Row(
            children: List.generate(
              widget.columns.length,
              (index) => Expanded(
                flex: widget.flexes[index],
                child: widget.columns[index],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
