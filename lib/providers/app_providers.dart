import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/repositories/bangumi_repository_impl.dart';
import '../domain/repositories/bangumi_repository.dart';
import '../request/bangumi/bangumi_api.dart';
import '../store/app_store.dart';
import '../store/bgm_user_hive.dart';
import '../store/dtt_store.dart';
import '../store/nav_store.dart';
import '../store/tracker_hive.dart';

final appStoreProvider = ChangeNotifierProvider.autoDispose<BTAppStore>((ref) {
  return BTAppStore();
});

final navStoreProvider = ChangeNotifierProvider.autoDispose<BTNavStore>((ref) {
  var store = BTNavStore();
  return store;
});

final bgmUserHiveProvider = ChangeNotifierProvider.autoDispose<BgmUserHive>((
  ref,
) {
  return BgmUserHive();
});

final dttStoreProvider = ChangeNotifierProvider.autoDispose<DttHive>((ref) {
  return DttHive();
});

final trackerHiveProvider = ChangeNotifierProvider.autoDispose<TrackerHive>((
  ref,
) {
  return TrackerHive();
});

final bangumiApiProvider = Provider<BtrBangumiApi>((ref) {
  return BtrBangumiApi();
});

final bangumiRepositoryProvider = Provider<BTBangumiRepository>((ref) {
  var api = ref.watch(bangumiApiProvider);
  return BTBangumiRepositoryImpl(api: api);
});
