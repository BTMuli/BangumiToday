// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../components/app/app_infobar.dart';
import '../../components/base/base_theme_icon.dart';
import '../../models/hive/play_model.dart';
import '../../store/play_store.dart';
import '../core/source_base.dart';
import '../core/source_model.dart';

class SourceSearchResItem {
  final BtSourceBase source;
  final List<BtSourceFind> find;

  SourceSearchResItem(this.source, this.find);
}

/// 展示搜索结果的对话框
/// 并提供搜索结果的点击事件
Future<void> showSourceSearchDialog(
  BuildContext context,
  PlayHiveModel item,
  List<SourceSearchResItem> find,
  void Function() callback,
) async {
  await showDialog(
    barrierDismissible: true,
    context: context,
    builder: (context) {
      return ContentDialog(
        title: const Text('搜索结果'),
        constraints: BoxConstraints(maxWidth: 1000.w, maxHeight: 800.h),
        content: ListView.separated(
          padding: const EdgeInsets.only(right: 12),
          itemCount: find.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: 12, child: Center(child: Divider())),
          itemBuilder: (context, index) {
            return SourceSearchItem(
                item: item, data: find[index], callback: callback);
          },
        ),
        actions: [
          Button(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
        ],
      );
    },
  );
}

/// 组件
class SourceSearchItem extends StatefulWidget {
  final PlayHiveModel item;
  final SourceSearchResItem data;
  final void Function() callback;

  const SourceSearchItem({
    super.key,
    required this.item,
    required this.data,
    required this.callback,
  });

  @override
  State<SourceSearchItem> createState() => _SourceSearchItemState();
}

class _SourceSearchItemState extends State<SourceSearchItem> {
  PlayHiveModel get item => widget.item;

  BtSourceBase get source => widget.data.source;

  /// hive
  final PlayHive hive = PlayHive();

  /// 构建无封面的卡片
  Widget buildEmptyCover({String? err}) {
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

  /// 构建封面
  Widget buildCover(BtSourceFind find) {
    if (find.image == null || find.image!.isEmpty) return buildEmptyCover();
    return CachedNetworkImage(
      imageUrl: find.image!,
      fit: BoxFit.fitHeight,
      progressIndicatorBuilder: (context, url, dp) => Center(
        child: ProgressRing(
          value: dp.progress == null ? 0 : dp.progress! * 100,
        ),
      ),
      errorWidget: (context, url, error) => buildEmptyCover(
        err: error.toString(),
      ),
    );
  }

  /// 构建信息
  Widget buildInfo(BtSourceFind find) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.max,
      children: [
        Tooltip(
          message: find.anime,
          child: Text(
            find.anime,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        if (find.desc != null && find.desc!.isNotEmpty)
          Text(find.desc!, maxLines: 2, overflow: TextOverflow.ellipsis),
        const Spacer(),
        IconButton(
          icon: const BaseThemeIcon(FluentIcons.accept),
          onPressed: () async {
            var res = await source.load(find.series);
            if (res.isEmpty) {
              if (mounted) await BtInfobar.error(context, '未找到播放链接');
              return;
            }
            if (mounted) {
              await BtInfobar.success(context, '找到${res.length}个播放链接');
            }
            for (var sourceIdx = 0; sourceIdx < res.length; sourceIdx++) {
              var sourceEp = PlayHiveSource(
                source: '${source.name}_${find.series}(线路${sourceIdx + 1})',
                items: [],
              );
              for (var ep in res[sourceIdx].episodes) {
                if (ep.episode == null || ep.episode!.isEmpty) continue;
                var epItem = PlayHiveSourceItem(
                  link: ep.episode!,
                  index: ep.id.toInt(),
                );
                sourceEp.items.add(epItem);
              }
              if (sourceEp.items.isEmpty) continue;
              if (!item.sources.contains(sourceEp)) {
                item.sources.add(sourceEp);
              } else {
                var idx = item.sources.indexOf(sourceEp);
                item.sources[idx].items.addAll(sourceEp.items);
              }
            }
            await hive.updateItem(item);
            widget.callback();
          },
        ),
      ],
    );
  }

  /// buildCard
  Widget buildCard(BtSourceFind find) {
    return SizedBox(
      height: 150.h,
      child: Card(
        padding: EdgeInsets.zero,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 150.h, maxWidth: 200.w),
              child: buildCover(find),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(4.sp),
                child: buildInfo(find),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          source.name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        for (var find in widget.data.find) buildCard(find),
      ],
    );
  }
}
