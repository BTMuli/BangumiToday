// Package imports:
import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:hive/hive.dart';

// Project imports:
import '../models/hive/tracker_model.dart';
import '../request/core/client.dart';

const trackerList = [
  'https://newtrackon.com/api/stable',
  'https://trackerslist.com/all.txt',
  'https://at.raxianch.moe/?type=AT-all',
  'https://cf.trackerslist.com/best.txt',
  'https://cdn.jsdelivr.net/gh/ngosang/trackerslist/trackers_all.txt',
];

/// torrent announce
class TrackerHive extends ChangeNotifier {
  /// 单实例
  TrackerHive._();

  static final TrackerHive instance = TrackerHive._();

  /// 获取实例
  factory TrackerHive() => instance;

  /// 获取box
  static Box<TrackerHiveModel> get box => Hive.box<TrackerHiveModel>('tracker');

  /// dio
  final BTRequestClient client = BTRequestClient();

  /// 获取所有tracker
  List<Uri> getTrackerList() {
    var list = <Uri>[];
    var items = box.values.toList();
    for (var item in items) {
      for (var url in item.trackerList) {
        try {
          var r = Uri.parse(url);
          if (!list.contains(r)) list.add(r);
        } catch (e) {
          //
        }
      }
    }
    return list;
  }

  /// 初始化
  Future<void> init() async {
    for (var url in trackerList) {
      if (box.get(url) == null) {
        await addTracker(url);
      }
    }
    var items = box.values.toList();
    for (var item in items) {
      if (!trackerList.contains(item.url)) {
        await box.delete(item.url);
      }
    }
  }

  /// 检测更新
  Future<void> checkUpdate() async {
    var list = box.values.toList();
    var today = DateTime.now().toString().substring(0, 10);
    for (var item in list) {
      if (item.updateTime != today) {
        await updateTracker(item, today);
      }
    }
  }

  /// 检测更新-单个
  Future<void> checkUpdateSingle(String url) async {
    var today = DateTime.now().toString().substring(0, 10);
    var item = box.get(url);
    if (item != null && item.updateTime != today) {
      await updateTracker(item, today);
    }
  }

  /// 添加tracker
  Future<void> addTracker(String url) async {
    var today = DateTime.now().toString().substring(0, 10);
    var item = TrackerHiveModel(url: url, trackerList: [], updateTime: today);
    await updateTracker(item, today);
  }

  /// 更新tracker
  Future<void> updateTracker(
    TrackerHiveModel item,
    String today, {
    int retry = 3,
  }) async {
    try {
      var resp = await client.dio.get(item.url);
      if (resp.statusCode == 200) {
        var data = resp.data;
        if (data is String) {
          var list = data.split('\n');
          var announceList = <String>[];
          for (var url in list) {
            if (url.isEmpty) continue;
            try {
              var r = Uri.parse(url);
              announceList.add(r.toString());
            } catch (e) {
              //
            }
          }
          item.trackerList = announceList;
          item.updateTime = today;
          await box.put(item.url, item);
          notifyListeners();
        }
      }
    } on DioException {
      if (retry > 0) {
        await Future.delayed(Duration(seconds: 15 * (4 - retry)));
        await updateTracker(item, today, retry: retry - 1);
      }
    }
  }
}
