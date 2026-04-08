import 'package:dart_rss/domain/rss_item.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../request/rss/anibt_api.dart';
import '../../ui/bt_dialog.dart';
import '../../widgets/rss/rss_anibt_card_fluent.dart';

class RbpAnibtWidget extends StatefulWidget {
  const RbpAnibtWidget({super.key});

  @override
  State<RbpAnibtWidget> createState() => _RbpAnibtState();
}

class _RbpAnibtState extends State<RbpAnibtWidget>
    with AutomaticKeepAliveClientMixin {
  final AnibtAPI anibtAPI = AnibtAPI();
  late List<RssItem> rssItems = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      await refresh();
    });
  }

  Future<void> refresh() async {
    setState(rssItems.clear);
    var resGet = await anibtAPI.getMagnetsRSS();
    if (resGet.code != 0 || resGet.data == null) {
      if (mounted) await showRespErr(resGet, context);
      return;
    }
    setState(() => rssItems = resGet.data!);
  }

  Widget buildTitle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        IconButton(
          icon: const Icon(FluentIcons.play_solid, size: 20),
          onPressed: () async {
            await launchUrlString('https://anibt.net');
          },
        ),
        SizedBox(width: 10.w),
        const Text('AniBT'),
        SizedBox(width: 10.w),
        IconButton(icon: const Icon(FluentIcons.refresh), onPressed: refresh),
      ],
    );
  }

  Widget buildContent() {
    if (rssItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ProgressRing(),
            SizedBox(height: 20.h),
            const Text('正在加载数据...'),
          ],
        ),
      );
    } else {
      return LayoutBuilder(
        builder: (context, constraints) {
          var cardWidth = 320.0;
          var crossAxisCount = (constraints.maxWidth / cardWidth).floor().clamp(
            1,
            6,
          );
          var mainAxisExtent = 200.0;

          return GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisExtent: mainAxisExtent,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
            ),
            itemCount: rssItems.length,
            itemBuilder: (context, index) {
              return RssAnibtCardFluent(item: rssItems[index]);
            },
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage.withPadding(
      padding: EdgeInsets.zero,
      header: Padding(padding: EdgeInsets.all(8), child: buildTitle()),
      content: buildContent(),
    );
  }
}
