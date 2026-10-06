// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../core/utils/tool_func.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../providers/app_providers.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../ui/bt_dialog.dart';
import '../../widgets/bangumi/bt_bangumi_cover.dart';
import 'subject_detail_colors.dart';
import 'subject_detail_refreshable.dart';

class SubjectDetailRelation extends ConsumerStatefulWidget {
  final int subjectId;
  final ValueChanged<int>? onCountChanged;

  const SubjectDetailRelation(this.subjectId, {super.key, this.onCountChanged});

  @override
  ConsumerState<SubjectDetailRelation> createState() =>
      _SubjectDetailRelationState();
}

class _SubjectDetailRelationState extends ConsumerState<SubjectDetailRelation>
    with AutomaticKeepAliveClientMixin, SubjectDetailRefreshable {
  int get subjectId => widget.subjectId;

  List<BangumiSubjectRelation> relations = [];
  bool _loading = true;
  String? _loadError;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await load();
    });
  }

  Future<void> load({bool reportError = false}) async {
    var repository = ref.read(bangumiRepositoryProvider);
    var resp = await repository.getSubjectRelations(subjectId);
    if (!mounted) return;
    if (resp.code != 0 || resp.data == null) {
      setState(() {
        _loading = false;
        _loadError = resp.message;
      });
      if (reportError) await showRespErr(resp, context);
      return;
    }
    setState(() {
      relations = resp.data!;
      _loading = false;
      _loadError = null;
    });
    widget.onCountChanged?.call(relations.length);
  }

  /// 重新拉取关联条目（由详情页刷新按钮触发）
  @override
  Future<void> refresh() => load(reportError: true);

  Widget buildCardInfo(BangumiSubjectRelation data) {
    return Padding(
      padding: EdgeInsets.all(8),
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
          SizedBox(height: 4),
          Row(
            children: [
              Text('ID: ${data.id}', style: BTTypography.caption(context)),
              SizedBox(width: 4),
              Tooltip(
                message: '查看详情',
                child: IconButton(
                  icon: Icon(
                    FluentIcons.info,
                    size: 14,
                    color: FluentTheme.of(context).accentColor,
                  ),
                  onPressed: () => ref
                      .read(navStoreProvider.notifier)
                      .addNavItemB(
                        type: data.type.label,
                        subject: data.id,
                        paneTitle: data.nameCn == '' ? data.name : data.nameCn,
                      ),
                ),
              ),
              SizedBox(width: 4),
              Tooltip(
                message: '打开链接',
                child: IconButton(
                  icon: Icon(
                    FluentIcons.link,
                    size: 14,
                    color: FluentTheme.of(context).accentColor,
                  ),
                  onPressed: () {
                    launchUrlString(
                      '${BtrBangumiApi.siteBaseUrl}/subject/${data.id}',
                    );
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
    return BtBangumiCover(
      imageUrl: images.large,
      width: 80,
      height: 120,
      maxRequestEdge: BangumiCoverUrl.thumbMaxEdge,
      borderRadius: BTRadius.smallBR,
      progressSize: 16,
      errorBuilder: (context, {err}) => Container(
        width: 80,
        height: 120,
        color: SubjectDetailColors.card(context),
        child: Icon(
          FluentIcons.photo_error,
          size: 20,
          color: BTColors.textTertiary(context),
        ),
      ),
    );
  }

  Widget buildRelationCard(BangumiSubjectRelation data) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    var hasImage = data.images.large.isNotEmpty;

    return Container(
      width: 260,
      height: 120,
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: SubjectDetailColors.card(context),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          if (hasImage) ...[buildCover(data.images), SizedBox(width: 8)],
          Expanded(child: buildCardInfo(data)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox.square(
          dimension: 24,
          child: ProgressRing(strokeWidth: 2),
        ),
      );
    }
    if (relations.isEmpty) {
      return Row(
        children: [
          Icon(
            FluentIcons.link,
            size: 16,
            color: BTColors.textTertiary(context),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _loadError == null ? '暂无关联条目' : '关联条目加载失败：$_loadError',
              style: BTTypography.body(context),
            ),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 0,
      children: relations.map(buildRelationCard).toList(),
    );
  }
}
