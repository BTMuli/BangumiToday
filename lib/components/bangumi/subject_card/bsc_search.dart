// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../../models/bangumi/bangumi_enum_extension.dart';
import '../../../models/bangumi/request_subject.dart';
import '../../../store/nav_store.dart';
import '../../../utils/bangumi_utils.dart';
import '../../base/base_theme_icon.dart';

/// Bangumi 条目卡片-搜索结果
class BscSearch extends ConsumerStatefulWidget {
  /// 结果
  final BangumiSubjectSearchData data;

  /// 构造
  const BscSearch(this.data, {super.key});

  @override
  ConsumerState<BscSearch> createState() => _BscSearchState();
}

/// Bangumi 条目卡片-搜索结果状态
class _BscSearchState extends ConsumerState<BscSearch> {
  /// 数据
  BangumiSubjectSearchData get subject => widget.data;

  /// label
  String get label => subject.type?.label ?? '条目';

  /// 构建无封面的卡片
  Widget buildCoverEmpty({String? err}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            BaseThemeIcon.darkest(FluentIcons.photo_error, size: 28.sp),
            Text(
              err ?? '无封面',
              style: TextStyle(
                color: FluentTheme.of(context).accentColor.darkest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建卡片封面
  Widget buildCover(String img) {
    if (img.isEmpty) return buildCoverEmpty();
    // bangumi 在线切图 https://github.com/bangumi/img-proxy
    var pathGet = Uri.parse(img).path;
    return CachedNetworkImage(
      imageUrl: 'https://lain.bgm.tv/r/0x600$pathGet',
      fit: BoxFit.cover,
      progressIndicatorBuilder: (context, url, dp) => Center(
        child: ProgressRing(
          value: dp.progress == null ? 0 : dp.progress! * 100,
        ),
      ),
      errorWidget: (context, url, error) => buildCoverEmpty(
        err: error.toString(),
      ),
    );
  }

  /// 构建单个标签
  Widget buildTag(String name, int count) {
    return Tooltip(
      message: count.toString(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: FluentTheme.of(context).accentColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(name),
        ),
      ),
    );
  }

  /// 构建卡片标签
  Widget buildTags() {
    var maxNum = 12;
    var tags = subject.tags;
    tags.sort((a, b) => b.count.compareTo(a.count));
    if (tags.length > maxNum) {
      tags = tags.sublist(0, maxNum);
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: tags.map((e) => buildTag(e.name, e.count)).toList(),
    );
  }

  /// 构建卡片操作
  /// 左侧是评分/排名，右侧是相关操作
  Widget buildAction() {
    var scoreLabel = getBangumiRateLabel(subject.score);
    return Row(children: [
      Tooltip(
        message: '查看$label详情',
        child: IconButton(
          icon: const BaseThemeIcon(FluentIcons.info),
          onPressed: () {
            ref
                .read(navStoreProvider)
                .addNavItemB(type: label, subject: subject.id);
          },
        ),
      ),
      if (subject.rank != 0) ...[
        const SizedBox(width: 4),
        Text('#${subject.rank}'),
      ],
      const Spacer(),
      Text('${subject.score}($scoreLabel)'),
    ]);
  }

  /// 构建卡片信息
  Widget buildInfo() {
    var name = subject.nameCn == '' ? subject.name : subject.nameCn;
    var subTitle = subject.nameCn == '' ? '' : subject.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: name,
          child: Text(
            label == '条目' ? name : '[$label] $name',
            style: FluentTheme.of(context).typography.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (subTitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Tooltip(
            message: subTitle,
            child: Text(
              subTitle,
              style: FluentTheme.of(context).typography.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        ],
        const SizedBox(height: 4),
        buildTags(),
        const Spacer(),
        buildAction(),
      ],
    );
  }

  /// 构建
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Card(
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 150,
              child: buildCover(subject.image),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: buildInfo(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
