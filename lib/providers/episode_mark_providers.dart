// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../core/services/episode_mark_service.dart';
import '../data/repositories/episode_mark_gateway_impl.dart';
import '../models/bangumi/bangumi_model.dart';
import '../models/playback/episode_mark_state.dart';
import '../models/playback/playback_item.dart';
import '../store/bgm_user_hive.dart';
import '../store/playback_store.dart';
import '../tools/log_tool.dart';
import 'bangumi_providers.dart';
import 'playback_episode_link_providers.dart';

export '../models/playback/episode_mark_state.dart';

final episodeMarkProvider =
    NotifierProvider<EpisodeMarkController, EpisodeMarkState>(
      EpisodeMarkController.new,
    );

/// Account-scoped chapter progress and playlist actions. Playback and
/// auto-advance never wait for queries or writes.
class EpisodeMarkController extends Notifier<EpisodeMarkState> {
  late final EpisodeMarkService service;
  late final PlaybackStore _playback;
  int _accountGeneration = 0;
  (int?, int, bool) _observedAuthorization = (null, 0, false);
  bool _closed = false;

  @override
  EpisodeMarkState build() {
    _playback = ref.read(playbackStoreProvider);
    var initialUser = ref.read(bgmUserStoreProvider);
    _observedAuthorization = (
      initialUser.user?.id,
      initialUser.sessionGeneration,
      initialUser.accessToken != null,
    );
    service = EpisodeMarkService(
      gateway: BangumiEpisodeMarkGateway(ref.read(bangumiRepositoryProvider)),
      accountSession: currentAccount,
      links: ref.read(playbackEpisodeLinksProvider),
    );
    var progressSubscription = service.progressChanges.listen((value) {
      if (!_closed && value.account == currentAccount()) {
        state = service.progressState;
      }
    });
    ref.listen<(int?, int, bool)>(
      bgmUserStoreProvider.select(
        (value) => (
          value.user?.id,
          value.sessionGeneration,
          value.accessToken != null,
        ),
      ),
      (_, authorization) {
        _observedAuthorization = authorization;
        discardWindowWork();
      },
    );
    // Playback reads this controller to reuse chapter metadata. Listening to
    // its provider would make that read circular; only the session's close
    // notification is needed, so subscribe to the captured object directly.
    void onPlaybackChanged() {
      if (_playback.isClosed) discardWindowWork();
    }

    _playback.addListener(onPlaybackChanged);
    listenForPlaybackCompletions(_playback);
    ref.onDispose(() {
      _closed = true;
      _playback.removeListener(onPlaybackChanged);
      unawaited(progressSubscription.cancel());
      service.close();
    });
    return EpisodeMarkState(account: currentAccount());
  }

  /// Subscribe once per engine, independently of sidebars and fullscreen UI.
  /// The immutable EOF item remains the target even after automatic advance.
  void listenForPlaybackCompletions(PlaybackStore playback) {
    var subscription = playback.completions.listen((completion) {
      var account = currentAccount();
      var item = completion.item;
      if (account == null ||
          account != state.account ||
          !playback.autoMarkWatched ||
          (item.subject ?? 0) <= 0 ||
          state.marked.contains(EpisodeMarkState.itemKey(item))) {
        return;
      }
      // Resolve again in markItem: the playlist may be hidden, its progress
      // may still be loading, or a file association may have just changed.
      unawaited(_markCompletedItem(item));
    });
    ref.onDispose(() => unawaited(subscription.cancel()));
  }

  Future<void> _markCompletedItem(PlaybackItem item) async {
    try {
      var result = await markItem(item);
      if (result.status == EpisodeMarkWriteStatus.failed ||
          result.message != null) {
        BTLogTool.warn('自动标记章节看过失败：${item.title}：${result.message}');
      }
    } catch (error) {
      BTLogTool.warn('自动标记章节看过失败：${item.title}：$error');
    }
  }

  String? currentAccount() {
    if (_closed || _playback.isClosed) return null;
    var user = ref.read(bgmUserStoreProvider);
    var authorization = (
      user.user?.id,
      user.sessionGeneration,
      user.accessToken != null,
    );
    // Read live authorization at every guard, including while page listeners
    // are paused. Token renewal keeps pending work in the same login session.
    // Only the generation crosses engines, never the token.
    if (authorization != _observedAuthorization) {
      _observedAuthorization = authorization;
      _accountGeneration++;
    }
    if (user.user == null || user.accessToken == null) return null;
    return '${user.user!.id}:$_accountGeneration';
  }

  void discardWindowWork() {
    if (_closed) return;
    _accountGeneration++;
    service.resetProgress();
    state = EpisodeMarkState(account: currentAccount());
  }

  Future<void> syncItems(
    List<PlaybackItem> items, {
    bool refresh = false,
  }) async {
    var account = currentAccount();
    if (_closed || account == null) return;
    try {
      await service.syncItems(items, refresh: refresh);
    } catch (_) {
      if (_closed || account != currentAccount()) return;
      rethrow;
    }
    if (!_closed && account == currentAccount()) state = service.progressState;
  }

  void receiveSubjectProgress(
    int subject,
    Iterable<BangumiUserEpisodeCollection> episodes, {
    required String? account,
    int? since,
  }) {
    if (_closed) return;
    service.observeProgress(
      subject,
      episodes.map(episodeMarkProgress),
      account: account,
      since: since,
    );
  }

  int get progressVersion => service.progressVersion;

  Future<EpisodeMarkWriteResult> markItem(PlaybackItem item) async {
    var account = currentAccount();
    if (state.account != account) {
      state = EpisodeMarkState(account: account);
    }
    var result = await service.mark(item);
    if (_closed || account != currentAccount()) {
      return const EpisodeMarkWriteResult(EpisodeMarkWriteStatus.expired);
    }
    if (result.status == EpisodeMarkWriteStatus.marked ||
        result.status == EpisodeMarkWriteStatus.alreadyDone) {
      state = service.progressState;
    }
    return result;
  }
}
