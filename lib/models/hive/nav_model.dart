// Package imports:
import 'package:hive_ce/hive_ce.dart';

/// 侧边栏项的类型枚举
enum BtmAppNavItemType {
  /// 应用，应用页面，标题固定
  app,

  /// Bangumi条目详情，标题会根据条目名称动态生成
  subject,
}

/// 动态导航路由描述（可序列化语义，不含 Widget）。
///
/// [type]/[title]/[param]/[subjectId] 描述「打开哪一页」；
/// [bodyEpoch] 仅用于 app 类动态页在标题不变时强制刷新 body 缓存。
class NavRouteDescriptor {
  /// 类型
  final BtmAppNavItemType type;

  /// 标题
  final String title;

  /// 参数，用于辨别不同的页面
  /// 当 [type] 为 [BtmAppNavItemType.app] 时，[param] 可为 null
  /// 当 [type] 为 [BtmAppNavItemType.subject] 时，[param] 为
  /// `subjectDetail_<id>`
  final String? param;

  /// 条目标题对应的 Bangumi subject id；非条目页为 null
  final int? subjectId;

  /// App 页 body 换新时递增；条目页恒为 0
  final int bodyEpoch;

  /// 构造函数
  const NavRouteDescriptor({
    required this.type,
    required this.title,
    this.param,
    this.subjectId,
    this.bodyEpoch = 0,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NavRouteDescriptor &&
        type == other.type &&
        title == other.title &&
        param == other.param &&
        subjectId == other.subjectId &&
        bodyEpoch == other.bodyEpoch;
  }

  @override
  int get hashCode => Object.hash(type, title, param, subjectId, bodyEpoch);
}

/// 侧边栏项的Hive模型，只用于存储subjectDetail
class BtmAppNavHive {
  /// 标题
  final String title;

  /// subject Id
  final int subjectId;

  /// 构造函数
  const BtmAppNavHive({required this.title, required this.subjectId});
}

/// 侧边栏项的适配器
class BtmAppNavItemAdapter extends TypeAdapter<BtmAppNavHive> {
  @override
  final int typeId = 0;

  @override
  BtmAppNavHive read(BinaryReader reader) {
    var title = reader.readString();
    var subjectId = reader.readInt();
    return BtmAppNavHive(title: title, subjectId: subjectId);
  }

  @override
  void write(BinaryWriter writer, BtmAppNavHive obj) {
    writer.writeString(obj.title);
    writer.writeInt(obj.subjectId);
  }
}
