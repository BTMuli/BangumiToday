// Package imports:
import 'package:hive_ce/hive_ce.dart';

// Project imports:
import '../core/services/file_service.dart';
import '../models/hive/bgm_user_model.dart';
import '../models/hive/nav_model.dart';
import '../models/hive/tracker_model.dart';
import '../store/bgm_user_hive.dart';

/// 采用Hive来存储本地数据
class BTHiveTool {
  BTHiveTool._();

  static final BTHiveTool instance = BTHiveTool._();

  /// factory
  factory BTHiveTool() => instance;

  /// 文件工具
  final BTFileTool fileTool = BTFileTool();

  static Future<void>? _satelliteReady;
  static bool _hiveRootReady = false;

  /// 获取应用数据目录
  static Future<String> getDataDir() async {
    return await instance.fileTool.getAppDataPath('hive');
  }

  /// Flush and close all boxes before native application teardown begins.
  static Future<void> close() => Hive.close();

  static Future<void> _ensureHiveRoot() async {
    if (_hiveRootReady) return;
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
    _hiveRootReady = true;
  }

  /// 首屏必需：只打开导航盒，供 `navStore` 恢复动态标签。
  static Future<void> initNav() async {
    await _ensureHiveRoot();
    if (!Hive.isBoxOpen('nav')) {
      await Hive.openBox<BtmAppNavHive>('nav');
    }
  }

  /// 首帧后打开用户与 tracker 盒并恢复用户；幂等。
  static Future<void> initSatelliteBoxes() {
    return _satelliteReady ??= _openSatelliteBoxes();
  }

  static Future<void> _openSatelliteBoxes() async {
    await _ensureHiveRoot();
    await Future.wait([
      if (!Hive.isBoxOpen('bgmUser')) Hive.openBox<BgmUserHiveModel>('bgmUser'),
      if (!Hive.isBoxOpen('tracker')) Hive.openBox<TrackerHiveModel>('tracker'),
    ]);
    await BgmUserHive.initUser();
  }

  /// 兼容旧调用：打开全部盒并初始化用户。
  static Future<void> init() async {
    await initNav();
    await initSatelliteBoxes();
  }

  /// 初始化 navHiveBox
  static Future<void> initNavHiveBox() => initNav();

  /// 初始化 bgmUserHiveBox
  static Future<void> initBgmUserHiveBox() async {
    await initSatelliteBoxes();
  }

  /// 初始化 trackerHiveBox；调用方自行 init Tracker store。
  static Future<void> initTrackerHiveBox() async {
    await _ensureHiveRoot();
    if (!Hive.isBoxOpen('tracker')) {
      await Hive.openBox<TrackerHiveModel>('tracker');
    }
  }
}
