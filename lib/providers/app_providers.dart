import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/providers/repository_providers.dart';
import '../domain/repositories/bangumi_repository.dart';
import '../request/bangumi/bangumi_api.dart';
import '../store/app_store.dart';
import '../store/bgm_user_hive.dart';
import '../store/dtt_store.dart';
import '../store/tracker_hive.dart';

export '../domain/repositories/bmf_repository.dart';
export '../store/bmf_store.dart';
export '../store/nav_store.dart';

final appStoreProvider = ChangeNotifierProvider<BTAppStore>((ref) {
  return BTAppStore();
});

final bgmUserHiveProvider = ChangeNotifierProvider<BgmUserHive>((ref) {
  return BgmUserHive();
});

final dttStoreProvider = ChangeNotifierProvider<DttHive>((ref) {
  return DttHive();
});

final trackerHiveProvider = ChangeNotifierProvider<TrackerHive>((ref) {
  return TrackerHive();
});

final bangumiApiProvider = Provider<BtrBangumiApi>((ref) {
  return BtrBangumiApi();
});

final bangumiRepositoryProvider = Provider<BTBangumiRepository>((ref) {
  return BTRepositoryProviders.provideBangumiRepository();
});

final isLoggedInProvider = Provider<bool>((ref) {
  var user = ref.watch(bgmUserHiveProvider).user;
  return user != null;
});

final currentUsernameProvider = Provider<String?>((ref) {
  var user = ref.watch(bgmUserHiveProvider).user;
  return user?.nickname;
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(appStoreProvider).themeMode;
});

final accentColorProvider = Provider<Color>((ref) {
  return ref.watch(appStoreProvider).accentColor;
});
