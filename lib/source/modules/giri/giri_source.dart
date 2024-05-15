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
    try {
      if (title.isNotEmpty) {
        var resp = await api.search(title);
        res.addAll(resp);
      }
      if (keyword.isNotEmpty) {
        var resp = await api.search(keyword);
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
