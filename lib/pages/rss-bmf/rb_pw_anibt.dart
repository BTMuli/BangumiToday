// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../models/rss/rss.dart';
import '../../request/rss/anibt_api.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/rss/rss_anibt_card_fluent.dart';

class RbpAnibtWidget extends StatefulWidget {
  const RbpAnibtWidget({super.key});

  @override
  State<RbpAnibtWidget> createState() => _RbpAnibtState();
}

class _RbpAnibtState extends State<RbpAnibtWidget>
    with AutomaticKeepAliveClientMixin {
  final AnibtAPI anibtAPI = AnibtAPI();
  List<RssItem> rssItems = [];
  bool _refreshing = false;
  bool _loaded = false;
  bool _loadFailed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.delayed(Duration.zero, () => refresh(notify: false)),
    );
  }

  Future<void> refresh({bool notify = true}) async {
    if (!mounted || _refreshing) return;
    setState(() => _refreshing = true);
    var resGet = await anibtAPI.getMagnetsRSS();
    if (!mounted) return;
    var success = resGet.code == 0 && resGet.data != null;
    setState(() {
      _refreshing = false;
      _loaded = true;
      _loadFailed = !success;
      if (success) rssItems = resGet.data!;
    });
    if (!success) {
      await showRespErr(resGet, context);
      return;
    }
    if (notify) await BtInfobar.success(context, '已刷新 AniBT 列表');
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
        SizedBox(width: 10),
        const Text('AniBT'),
        SizedBox(width: 10),
        Tooltip(
          message: '刷新 AniBT',
          child: IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: ProgressRing(strokeWidth: 2),
                  )
                : const Icon(FluentIcons.refresh),
            onPressed: _refreshing ? null : refresh,
          ),
        ),
      ],
    );
  }

  Widget buildContent() {
    if (rssItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_refreshing || !_loaded) ...[
              const ProgressRing(),
              SizedBox(height: 20),
              const Text('正在加载数据...'),
            ] else
              Text(_loadFailed ? '加载失败，请点击刷新重试' : '暂无 RSS 数据'),
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
            key: const PageStorageKey('anibt-rss'),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisExtent: mainAxisExtent,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
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
