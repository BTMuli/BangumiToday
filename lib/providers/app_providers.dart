// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../store/app_store.dart';
import '../store/bgm_user_hive.dart';

export '../store/app_store.dart'
    show BTAppSettings, BTAppStore, appStoreProvider;
export '../store/bgm_user_hive.dart'
    show BgmUserState, BgmUserStore, bgmUserStoreProvider;
export '../store/tracker_hive.dart'
    show TrackerState, TrackerStore, trackerStoreProvider;
export '../domain/repositories/bmf_repository.dart';
export '../store/bmf_store.dart';
export '../store/nav_store.dart';
export 'bangumi_providers.dart';
export 'bmf_providers.dart';

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(bgmUserStoreProvider).loggedIn;
});

final currentUsernameProvider = Provider<String?>((ref) {
  return ref.watch(bgmUserStoreProvider).user?.nickname;
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(appStoreProvider).themeMode;
});

final accentColorProvider = Provider<Color>((ref) {
  return ref.watch(appStoreProvider).effectiveAccentColor;
});
