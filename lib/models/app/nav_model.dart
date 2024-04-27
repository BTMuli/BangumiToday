// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

/// 侧边栏项的类型枚举
enum BtmAppNavItemType {
  /// 应用，应用页面，标题固定
  app,

  /// Bangumi条目详情，标题会根据条目名称动态生成
  bangumiSubject,
}

/// 侧边栏项的数据模型
/// 用于动态生成侧边栏
class BtmAppNavItem {
  /// 类型
  final BtmAppNavItemType type;

  /// 标题
  final String title;

  /// 参数，用于辨别不同的页面
  /// 当[type]为[NavItemType.app]时，[param]为null
  /// 当[type]为[NavItemType.bangumiSubject]时，[param]为条目ID
  final String? param;

  /// panelItem
  final PaneItem body;

  /// 构造函数
  const BtmAppNavItem({
    required this.type,
    required this.title,
    this.param,
    required this.body,
  });
}
