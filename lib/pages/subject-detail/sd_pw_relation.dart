import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../core/theme/bt_theme.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/bt_dialog.dart';
import '../../utils/tool_func.dart';

class SdpRelationWidget extends ConsumerStatefulWidget {
  final int subjectId;

  const SdpRelationWidget(this.subjectId, {super.key});

  @override
  ConsumerState<SdpRelationWidget> createState() => _SdpRelationWidgetState();
}

class _SdpRelationWidgetState extends ConsumerState<SdpRelationWidget>
    with AutomaticKeepAliveClientMixin {
  int get subjectId => widget.subjectId;

  List<BangumiSubjectRelation> relations = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await load();
    });
  }

  Future<void> load() async {
    var repository = ref.read(bangumiRepositoryProvider);
    var resp = await repository.getSubjectRelations(subjectId);
    if (resp.code != 0 || resp.data == null) {
      if (mounted) await showRespErr(resp, context);
      return;
    }
    relations = resp.data!;
    setState(() {});
  }

  Widget buildCardInfo(BangumiSubjectRelation data) {
    return Padding(
      padding: EdgeInsets.all(8.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Tooltip(
            message: data.name,
            child: Text(
              '【${data.relation}】${replaceEscape(data.name)}',
              style: BTTypography.bodyStrong(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Text('类型：${data.type.label}', style: BTTypography.caption(context)),
          SizedBox(height: 4.h),
          Row(
            children: [
              Text('ID: ${data.id}', style: BTTypography.caption(context)),
              SizedBox(width: 4.w),
              Tooltip(
                message: '查看详情',
                child: IconButton(
                  icon: Icon(
                    FluentIcons.info,
                    size: 14.sp,
                    color: FluentTheme.of(context).accentColor,
                  ),
                  onPressed: () => ref.read(navStoreProvider).addNavItemB(
                    type: data.type.label,
                    subject: data.id,
                    paneTitle: data.nameCn == '' ? data.name : data.nameCn,
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              Tooltip(
                message: '打开链接',
                child: IconButton(
                  icon: Icon(
                    FluentIcons.link,
                    size: 14.sp,
                    color: FluentTheme.of(context).accentColor,
                  ),
                  onPressed: () {
                    launchUrlString('https://bgm.tv/subject/${data.id}');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildCover(BangumiImages images) {
    var pathGet = Uri.parse(images.large).path;
    var link = 'https://lain.bgm.tv/r/0x600$pathGet';
    return ClipRRect(
      borderRadius: BTRadius.smallBR,
      child: CachedNetworkImage(
        imageUrl: link,
        fit: BoxFit.cover,
        width: 80.w,
        height: 120.h,
        progressIndicatorBuilder: (context, url, dp) => Container(
          width: 80.w,
          height: 120.h,
          color: BTColors.surfaceSecondary(context),
          child: Center(
            child: SizedBox(
              width: 16.w,
              height: 16.w,
              child: ProgressRing(
                value: dp.progress == null ? 0 : dp.progress! * 100,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 80.w,
          height: 120.h,
          color: BTColors.surfaceSecondary(context),
          child: Icon(
            FluentIcons.photo_error,
            size: 20.sp,
            color: BTColors.textTertiary(context),
          ),
        ),
      ),
    );
  }

  Widget buildRelationCard(BangumiSubjectRelation data) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    var hasImage = data.images.large.isNotEmpty;

    return Container(
      width: 260.w,
      height: 120.h,
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          if (hasImage) ...[buildCover(data.images), SizedBox(width: 8.w)],
          Expanded(child: buildCardInfo(data)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (relations.isEmpty) {
      return Row(
        children: [
          Icon(
            FluentIcons.link,
            size: 16.sp,
            color: BTColors.textTertiary(context),
          ),
          SizedBox(width: 8.w),
          Text('暂无关联条目', style: BTTypography.body(context)),
          const Spacer(),
          Tooltip(
            message: '刷新',
            child: IconButton(
              icon: Icon(FluentIcons.refresh, size: 14.sp),
              onPressed: load,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '共 ${relations.length} 个关联条目',
              style: BTTypography.caption(context),
            ),
            const Spacer(),
            Tooltip(
              message: '刷新',
              child: IconButton(
                icon: Icon(FluentIcons.refresh, size: 14.sp),
                onPressed: load,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 400.h),
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Wrap(
              spacing: 8.w,
              runSpacing: 0,
              children: relations.map(buildRelationCard).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
