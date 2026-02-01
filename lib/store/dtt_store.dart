// Package imports:
import 'package:dart_rss/dart_rss.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';

// Project imports:
import '../database/app/app_config.dart';
import '../models/hive/dtt_model.dart';

/// 下载状态提供者
final dttStoreProvider = ChangeNotifierProvider<DttHive>((ref) {
  /// 从hive中读取下载列表
  var items = Hive.box<DttHiveModel>('dtt');
  return DttHive().._list.addAll(items.values.toList());
});

/// 下载状态
class DttHive extends ChangeNotifier {
  /// 下载列表，这边只存储RssItem跟下载目录
  final List<DttHiveModel> _list = [];

  final BtsAppConfig sqlite = BtsAppConfig();

  /// 获取下载列表
  List<DttHiveModel> get list => _list;

  /// 添加下载任务
  Future<bool> addTask(RssItem item, String dir) async {
    var mikanUrl = await sqlite.readMikanUrl();
    var urlReal = item.enclosure?.url;
    if (mikanUrl != null && mikanUrl.isNotEmpty) {
      var url = Uri.parse(urlReal!);
      var urlDomain = '${url.scheme}://${url.host}';
      urlReal = urlReal.replaceFirst(urlDomain, mikanUrl);
    }
    var miniItem = MiniRssItem(item.title ?? '', urlReal ?? '');

    /// 判断是否已经存在
    var find = _list.indexWhere((e) => e.item == miniItem);
    if (find != -1) return false;
    var dttHiveItem = DttHiveModel(miniItem, dir, index: _list.length);
    _list.add(dttHiveItem);
    await Hive.box<DttHiveModel>('dtt').put(dttHiveItem.index, dttHiveItem);
    notifyListeners();
    return true;
  }

  /// 移除下载任务
  Future<void> removeTask(MiniRssItem item) async {
    _list.remove(_list.firstWhere((e) => e.item == item));
    var hiveItem = Hive.box<DttHiveModel>(
      'dtt',
    ).values.firstWhere((e) => e.item.link == item.link);
    await Hive.box<DttHiveModel>('dtt').delete(hiveItem.index);
    notifyListeners();
  }
}
