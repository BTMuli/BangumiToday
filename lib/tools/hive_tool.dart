// Package imports:
import 'package:hive/hive.dart';

// Project imports:
import '../models/hive/bgm_user_model.dart';
import '../models/hive/danmaku_model.dart';
import '../models/hive/nav_model.dart';
import '../models/hive/play_model.dart';
import '../models/hive/tracker_model.dart';
import '../store/bgm_user_hive.dart';
import '../store/play_store.dart';
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
  Future<String> getDataDir() async {
    return await instance.fileTool.getAppDataPath('hive');
  }

  /// 初始化
  Future<void> init() async {
    var dir = await getDataDir();
    await instance.fileTool.createDir(dir);
    Hive.init(dir);
    await initBgmUserHiveBox();
    await initPlayHiveBox();
    await initNavHiveBox();
    await initTrackerHiveBox();
    await initDanmakuHiveBox();
  }

  /// 初始化 navHiveBox
  Future<void> initNavHiveBox() async {
    Hive.registerAdapter(BtmAppNavItemAdapter());
    await Hive.openBox<BtmAppNavHive>('nav');
  }

  /// 初始化 bgmUserHiveBox
  Future<void> initBgmUserHiveBox() async {
    Hive.registerAdapter(BgmUserHiveAdapter());
    await Hive.openBox<BgmUserHiveModel>('bgmUser');
    await BgmUserHive().initUser();
  }

  /// 初始化 trackerHiveBox
  Future<void> initTrackerHiveBox() async {
    Hive.registerAdapter(TrackerHiveAdapter());
    await Hive.openBox<TrackerHiveModel>('tracker');
    await TrackerHive().init();
  }

  /// 初始化 playHiveBox
  Future<void> initPlayHiveBox() async {
    Hive.registerAdapter(PlayHiveAdapter());
    Hive.registerAdapter(PlayHiveItemAdapter());
    Hive.registerAdapter(PlayHiveSourceAdapter());
    Hive.registerAdapter(PlayHiveSourceItemAdapter());
    await Hive.openBox<PlayHiveModel>('play');
    PlayHive().init();
  }

  /// 初始化 danmakuHiveBox
  Future<void> initDanmakuHiveBox() async {
    Hive.registerAdapter(DanmakuHiveAdapter());
    await Hive.openBox<DanmakuHiveModel>('danmaku');
  }
}
