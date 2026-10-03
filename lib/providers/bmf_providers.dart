// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../data/repositories/bmf_repository_impl.dart';
import '../domain/repositories/bmf_repository.dart';

/// 组装 BMF 订阅仓储实现，生命周期跟随容器。
final bmfRepositoryProvider = Provider<BmfRepository>((ref) {
  var repository = BmfRepositoryImpl();
  ref.onDispose(repository.dispose);
  return repository;
});
