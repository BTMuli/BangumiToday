// Package imports:
import 'package:hive/hive.dart';

// Project imports:
import '../models/hive/bgm_user_model.dart';
import '../models/hive/dtt_model.dart';
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
    await initBgmUserHiveBox();
    await initNavHiveBox();
    await initTrackerHiveBox();
    await initDttHiveBox();
  }

  /// 初始化 navHiveBox
  static Future<void> initNavHiveBox() async {
    Hive.registerAdapter(BtmAppNavItemAdapter());
    await Hive.openBox<BtmAppNavHive>('nav');
  }

  /// 初始化 bgmUserHiveBox
  static Future<void> initBgmUserHiveBox() async {
    Hive.registerAdapter(BgmUserHiveAdapter());
    await Hive.openBox<BgmUserHiveModel>('bgmUser');
    await BgmUserHive().initUser();
  }

  /// 初始化 trackerHiveBox
  static Future<void> initTrackerHiveBox() async {
    Hive.registerAdapter(TrackerHiveAdapter());
    await Hive.openBox<TrackerHiveModel>('tracker');
    await TrackerHive().init();
  }

  /// 初始化 dttHiveBox
  static Future<void> initDttHiveBox() async {
    Hive.registerAdapter(RssItemAdapter());
    Hive.registerAdapter(DttItemAdapter());
    await Hive.openBox<DttHiveModel>('dtt');
  }
}
