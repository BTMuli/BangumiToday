// Package imports:
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// Project imports:
import '../../core/source_base.dart';
import '../../core/source_model.dart';
import 'bimi_api.dart';

/// 资源：哔咪动漫
/// 站点：https://www.bimiacg4.net
class BimiSource extends BtSourceBase {
  /// 请求
  final BimiApi api = BimiApi();

  /// 构造
  BimiSource() : super('哔咪动漫');

  /// 查找
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

  /// 加载
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

  /// 播放
  /// todo 待完善
  @override
  Future<void> play(String episodeId, VideoController controller) async {
    try {
      var url = await api.play(episodeId);
      await controller.player.open(Media(url));
    } catch (e) {
      rethrow;
    }
  }
}
