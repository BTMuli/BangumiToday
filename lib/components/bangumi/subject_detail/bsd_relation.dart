import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../models/bangumi/bangumi_enum_extension.dart';
import '../../../models/bangumi/bangumi_model.dart';
import '../../../pages/bangumi/bangumi_detail.dart';
import '../../../request/bangumi/bangumi_api.dart';
import '../../../store/nav_store.dart';
import '../../../utils/tool_func.dart';
import '../../app/app_dialog_resp.dart';

/// Bangumi Subject Detail 的 Relation 部件
/// 用于展示条目的关联条目
class BsdRelation extends ConsumerStatefulWidget {
  /// 条目id
  final int subjectId;

  /// 构造函数
  const BsdRelation(this.subjectId, {super.key});

  @override
  ConsumerState<BsdRelation> createState() => _BsdRelationState();
}

/// Bangumi Subject Detail 的 Relation 部件状态
class _BsdRelationState extends ConsumerState<BsdRelation>
    with AutomaticKeepAliveClientMixin {
  /// 条目id
  int get subjectId => widget.subjectId;

  /// 请求客户端
  final BtrBangumiApi api = BtrBangumiApi();

  /// 关联条目
  List<BangumiSubjectRelation> relations = [];

  @override
  bool get wantKeepAlive => true;

  /// init
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await load();
    });
  }

  /// 加载
  Future<void> load() async {
    var resp = await api.getSubjectRelations(subjectId);
    if (resp.code != 0 || resp.data.isEmpty) {
      showRespErr(resp, context);
      return;
    }
    relations = resp.data;
    setState(() {});
  }

  /// 跳转到条目详情
  void toSubjectDetail(int id, String label) {
    var title = '$label详情 $id';
    var pane = PaneItem(
      icon: Icon(FluentIcons.info),
      title: Text(title),
      body: BangumiDetail(id: id.toString()),
    );
    ref.read(navStoreProvider).addNavItem(pane, title);
  }

  /// 构建信息
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Spacer(),
          Text('类型：${data.type.label}'),
          SizedBox(height: 4.h),
          Row(
            children: [
              Text('ID: ${data.id}'),
              SizedBox(width: 4.w),
              Tooltip(
                message: '查看详情',
                child: IconButton(
                  icon: Icon(
                    FluentIcons.info,
                    color: FluentTheme.of(context).accentColor,
                  ),
                  onPressed: () {
                    toSubjectDetail(data.id, data.type.label);
                  },
                ),
              ),
              SizedBox(width: 4.w),
              Tooltip(
                message: '打开链接',
                child: IconButton(
                  icon: Icon(
                    FluentIcons.link,
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

  /// 构建封面
  Widget buildCover(BangumiImages images) {
    // bangumi 在线切图
    // see: https://github.com/bangumi/img-proxy
    var pathGet = Uri.parse(images.large).path;
    var link = 'https://lain.bgm.tv/r/0x600$pathGet';
    return CachedNetworkImage(
      imageUrl: link,
      fit: BoxFit.cover,
      progressIndicatorBuilder: (context, url, dp) => Center(
        child: ProgressRing(
          value: dp.progress == null ? 0 : dp.progress! * 100,
        ),
      ),
      errorWidget: (context, url, error) => Center(
        child: Text(error.toString()),
      ),
    );
  }

  /// 构建关联条目卡片
  Widget buildRelationCard(BangumiSubjectRelation data) {
    var color = FluentTheme.of(context).brightness == Brightness.light
        ? Color(0xfcfcfc)
        : Color(0xff3a3a3a);
    var width = 275.0;
    var height = 150.0;
    if (data.images.large.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: color,
          border: Border.all(color: Colors.black.withOpacity(0.1)),
        ),
        width: width,
        height: height,
        child: Row(
          children: [Expanded(child: buildCardInfo(data))],
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: color,
          border: Border.all(color: Colors.black.withOpacity(0.1)),
        ),
        width: width,
        height: height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 50,
                minHeight: 200,
                maxWidth: 100,
                maxHeight: 200,
              ),
              child: buildCover(data.images),
            ),
            SizedBox(width: 8.w),
            Expanded(child: buildCardInfo(data)),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (relations.isEmpty) {
      return ListTile(
        leading: Icon(FluentIcons.error),
        title: Text('暂无关联条目'),
        trailing: Tooltip(
          message: '刷新',
          child: IconButton(
            icon: Icon(FluentIcons.refresh),
            onPressed: load,
          ),
        ),
      );
    }
    return Container(
      margin: EdgeInsets.only(right: 12.w),
      child: Expander(
        leading: Icon(FluentIcons.link),
        header: Text('关联条目', style: TextStyle(fontSize: 24.sp)),
        trailing: Button(child: Text('刷新'), onPressed: load),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 600.h),
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: relations.map(buildRelationCard).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
