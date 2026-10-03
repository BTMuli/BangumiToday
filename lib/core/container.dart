// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 应用级 ProviderContainer。
///
/// 由 `main()` 在启动时创建，`UncontrolledProviderScope` 与需要在 Widget 树
/// 之外读取 provider 的层（数据库初始化、后台服务、通知回调）共用同一个实例。
/// 放在独立文件里，避免业务层为了拿容器而反向依赖 `main.dart`。
final globalContainer = ProviderContainer();
