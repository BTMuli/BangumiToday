part of '../bmf_expander.dart';

/// 番剧信息由工作台固定在上方；资源工具栏与分组表头在此视口内吸顶。
Widget _buildEmbeddedResourcePanel(
  BuildContext context, {
  required Widget header,
  required Widget sliver,
  ScrollController? controller,
  Widget? toolbar,
}) {
  return ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: Scrollbar(
      controller: controller,
      thumbVisibility: controller != null,
      child: CustomScrollView(
        controller: controller,
        primary: false,
        slivers: [
          PinnedHeaderSliver(
            child: Container(
              decoration: BoxDecoration(
                color: BTColors.surfaceSecondary(context),
                border: Border(
                  bottom: BorderSide(color: BTColors.divider(context)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?toolbar,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: header,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: sliver,
          ),
        ],
      ),
    ),
  );
}

Widget _buildFixedResourcePanel(
  BuildContext context, {
  required Widget leading,
  required Widget header,
  required Widget content,
  ScrollController? controller,
}) {
  return Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: BTColors.surfacePrimary(context),
      borderRadius: BTRadius.largeBR,
      border: Border.all(color: BTColors.divider(context)),
    ),
    child: Column(
      children: [
        ColoredBox(
          color: BTColors.surfaceSecondary(context),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                leading,
                SizedBox(width: 10),
                Expanded(child: header),
              ],
            ),
          ),
        ),
        Container(height: 1, color: BTColors.divider(context)),
        Expanded(
          child: Scrollbar(
            controller: controller,
            thumbVisibility: controller != null,
            child: SingleChildScrollView(
              controller: controller,
              padding: EdgeInsets.all(10),
              child: content,
            ),
          ),
        ),
      ],
    ),
  );
}
