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
import 'bangumi_providers.dart';

export '../models/playback/episode_mark_state.dart';

final episodeMarkProvider =
    NotifierProvider<EpisodeMarkController, EpisodeMarkState>(
      EpisodeMarkController.new,
    );

final episodeMarkRefreshProvider =
    StreamProvider.family<EpisodeMarkRefresh, int>((ref, subject) {
      return ref
          .watch(episodeMarkProvider.notifier)
          .service
          .refreshes
          .where((event) => event.subject == subject);
    });

/// Account-scoped chapter progress and explicit playlist actions. Playback and
/// auto-advance never wait for queries or writes.
class EpisodeMarkController extends Notifier<EpisodeMarkState> {
  late final EpisodeMarkService service;
  late final PlaybackStore _playback;
  int _accountGeneration = 0;
  (int?, String?) _observedAuthorization = (null, null);
  bool _closed = false;

  @override
  EpisodeMarkState build() {
    _playback = ref.read(playbackStoreProvider);
    var initialUser = ref.read(bgmUserStoreProvider);
    _observedAuthorization = (initialUser.user?.id, initialUser.accessToken);
    service = EpisodeMarkService(
      gateway: BangumiEpisodeMarkGateway(
        ref.read(bangumiRepositoryProvider),
        ref.read(bangumiLocalDataSourceProvider),
      ),
      accountSession: currentAccount,
    );
    var progressSubscription = service.progressChanges.listen((value) {
      if (!_closed && value.account == currentAccount()) {
        state = service.progressState;
      }
    });
    ref.listen<(int?, String?)>(
      bgmUserStoreProvider.select(
        (value) => (value.user?.id, value.accessToken),
      ),
      (_, authorization) {
        _observedAuthorization = authorization;
        discardWindowWork();
      },
    );
    ref.listen(playbackStoreProvider, (_, value) {
      if (value.isClosed) discardWindowWork();
    });
    ref.onDispose(() {
      _closed = true;
      unawaited(progressSubscription.cancel());
      service.close();
    });
    return EpisodeMarkState(account: currentAccount());
  }

  String? currentAccount() {
    if (_closed || _playback.isClosed) return null;
    var user = ref.read(bgmUserStoreProvider);
    var authorization = (user.user?.id, user.accessToken);
    // Read live authorization at every guard, including while page listeners
    // are paused. Only the generation crosses engines, never the token.
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
