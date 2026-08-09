part of '../bmf_expander.dart';

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
