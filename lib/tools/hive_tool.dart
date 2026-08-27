// Package imports:
import 'package:hive/hive.dart';

// Project imports:
import '../models/hive/bgm_user_model.dart';
import '../models/hive/nav_model.dart';
import '../models/hive/tracker_model.dart';
import '../store/bgm_user_hive.dart';
import '../store/tracker_hive.dart';
import 'file_tool.dart';

/// 采用Hive来存储本地数据
class BTHiveTool {
  BTHiveTool._();

  static final BTHiveTool instance = BTHiveTool._();

  /// factory
  factory BTHiveTool() => instance;

  /// 文件工具
  final BTFileTool fileTool = BTFileTool();

  /// 获取应用数据目录
  static Future<String> getDataDir() async {
    return await instance.fileTool.getAppDataPath('hive');
  }

  /// 初始化
  static Future<void> init() async {
    var dir = await getDataDir();
    await instance.fileTool.createDir(dir);
    Hive.init(dir);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(BtmAppNavItemAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(BgmUserHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(TrackerHiveAdapter());
    }
    await Future.wait([
      Hive.openBox<BtmAppNavHive>('nav'),
      Hive.openBox<BgmUserHiveModel>('bgmUser'),
      Hive.openBox<TrackerHiveModel>('tracker'),
    ]);
    await BgmUserHive().initUser();
    await TrackerHive().init();
  }

  /// 初始化 navHiveBox
  static Future<void> initNavHiveBox() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(BtmAppNavItemAdapter());
    }
    await Hive.openBox<BtmAppNavHive>('nav');
  }

  /// 初始化 bgmUserHiveBox
  static Future<void> initBgmUserHiveBox() async {
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(BgmUserHiveAdapter());
    }
    await Hive.openBox<BgmUserHiveModel>('bgmUser');
    await BgmUserHive().initUser();
  }

  /// 初始化 trackerHiveBox
  static Future<void> initTrackerHiveBox() async {
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(TrackerHiveAdapter());
    }
    await Hive.openBox<TrackerHiveModel>('tracker');
    await TrackerHive().init();
  }
}
