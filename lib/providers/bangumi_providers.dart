// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../data/datasources/bangumi_local_data_source.dart';
import '../data/datasources/bangumi_local_data_source_impl.dart';
import '../data/datasources/bangumi_remote_data_source.dart';
import '../data/datasources/bangumi_remote_data_source_impl.dart';
import '../data/repositories/bangumi_repository_impl.dart';
import '../domain/repositories/bangumi_repository.dart';
import '../models/bangumi/bangumi_enum.dart';
import '../models/bangumi/bangumi_model.dart';
import '../request/bangumi/bangumi_api.dart';
import '../store/bgm_user_hive.dart';

final bangumiApiProvider = Provider<BtrBangumiApi>((ref) {
  var api = BtrBangumiApi(
    accountUsername: () => ref.read(bgmUserStoreProvider).user?.username,
    accountSession: () {
      var user = ref.read(bgmUserStoreProvider);
      return (userId: user.user?.id, generation: user.sessionGeneration);
    },
  );
  ref.onDispose(api.client.dispose);
  return api;
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
    requestSource: () => BtrBangumiApi.routingGeneration,
    remoteDataSource: ref.watch(bangumiRemoteDataSourceProvider),
    localDataSource: ref.watch(bangumiLocalDataSourceProvider),
    accountSession: () {
      var user = ref.read(bgmUserStoreProvider);
      return (
        // 收藏接口按 username 查询；本地缓存仍以数字 UID 绑定账号。
        username: user.user?.username,
        generation: user.sessionGeneration,
      );
    },
  );
});

/// 首页共用一份数据库快照，收藏筛选与封面状态随持久化写入同步。
final bangumiCollectionTypesProvider =
    StreamProvider.autoDispose<Map<int, BangumiCollectionType>>((ref) {
      var user = ref.watch(
        bgmUserStoreProvider.select(
          (state) => (state.user?.id, state.sessionGeneration),
        ),
      );
      if (user.$1 == null) return Stream.value(const {});
      return ref.watch(bangumiRepositoryProvider).watchLocalCollectionTypes();
    });

final bangumiCollectionsProvider = StreamProvider.autoDispose
    .family<List<BangumiUserSubjectCollection>, BangumiCollectionType>((
      ref,
      type,
    ) {
      var user = ref.watch(
        bgmUserStoreProvider.select(
          (state) => (state.user?.id, state.sessionGeneration),
        ),
      );
      if (user.$1 == null) return Stream.value(const []);
      return ref
          .watch(bangumiRepositoryProvider)
          .watchLocalCollections(type: type);
    });
