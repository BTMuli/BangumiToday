// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../data/datasources/bangumi_local_data_source.dart';
import '../data/datasources/bangumi_local_data_source_impl.dart';
import '../data/datasources/bangumi_remote_data_source.dart';
import '../data/datasources/bangumi_remote_data_source_impl.dart';
import '../data/repositories/bangumi_repository_impl.dart';
import '../domain/repositories/bangumi_repository.dart';
import '../request/bangumi/bangumi_api.dart';

final bangumiApiProvider = Provider<BtrBangumiApi>((ref) {
  return BtrBangumiApi();
});

final bangumiRemoteDataSourceProvider = Provider<BTBangumiRemoteDataSource>((
  ref,
) {
  return BTBangumiRemoteDataSourceImpl(api: ref.watch(bangumiApiProvider));
});

final bangumiLocalDataSourceProvider = Provider<BTBangumiLocalDataSource>((
  ref,
) {
  return BTBangumiLocalDataSourceImpl();
});

final bangumiRepositoryProvider = Provider<BTBangumiRepository>((ref) {
  return BTBangumiRepositoryImpl(
    remoteDataSource: ref.watch(bangumiRemoteDataSourceProvider),
    localDataSource: ref.watch(bangumiLocalDataSourceProvider),
  );
});
