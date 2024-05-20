// Package imports:
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// Project imports:
import '../../core/source_base.dart';
import '../../core/source_model.dart';
import 'giri_api.dart';

/// 资源：GiriGiriLove
/// 站点：https://anime.girigirilove.com
class GiriSource extends BtSourceBase {
  /// 请求
  final GiriApi api = GiriApi();

  GiriSource() : super('GiriGiriLove');

  @override
  Future<List<BtSourceFind>> search(String title, String keyword) async {
    var res = <BtSourceFind>[];
    status = SourceMatchStat.matching;
    var str = <String>[];
    if (title == keyword && title.isNotEmpty) {
      str.add(title);
    } else {
      if (title.isNotEmpty) {
        str.add(title);
      }
      if (keyword.isNotEmpty) {
        str.add(keyword);
      }
    }
    try {
      for (var s in str) {
        var resp = await api.search(s);
        res.addAll(resp);
      }
      status = SourceMatchStat.matched;
    } catch (e) {
      status = SourceMatchStat.failed;
      rethrow;
    }
    return res;
  }

  @override
  Future<List<BtSource>> load(String series) async {
    var res = <BtSource>[];
    try {
      var resp = await api.load(series);
      res.addAll(resp);
    } catch (e) {
      rethrow;
    }
    return res;
  }

  @override
  Future<void> play(String episode, VideoController controller) async {
    var media = await api.play(episode);
    await controller.player.open(Media(media));
  }
}
