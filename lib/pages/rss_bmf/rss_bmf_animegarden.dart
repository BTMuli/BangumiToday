// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../widgets/rss/animegarden_browser.dart';

class RssBmfAnimeGarden extends StatefulWidget {
  const RssBmfAnimeGarden({super.key});

  @override
  State<RssBmfAnimeGarden> createState() => _RssBmfAnimeGardenState();
}

class _RssBmfAnimeGardenState extends State<RssBmfAnimeGarden>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const AnimeGardenBrowser();
  }
}
