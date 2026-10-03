// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../core/services/episode_mark_service.dart';
import '../data/repositories/episode_mark_gateway_impl.dart';
import '../models/playback/playback_completion.dart';
import '../models/playback/episode_mark_state.dart';
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

/// In-memory prompts only. Account changes, disabling and shutdown discard
/// unconfirmed work; periodic saves and auto-advance do not wait for this queue.
class EpisodeMarkController extends Notifier<EpisodeMarkState> {
  late final EpisodeMarkService service;
  late final PlaybackStore _playback;
  int _accountGeneration = 0;
  (int?, String?) _observedAuthorization = (null, null);
  int _settingsRevision = 0;
  bool _closed = false;
  final _seen = <String>{};
  Future<void> _settingsOperation = Future.value();

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
    var subscription = _playback.completions.listen(_onCompletion);
    ref.listen<(int?, String?)>(
      bgmUserStoreProvider.select(
        (value) => (value.user?.id, value.accessToken),
      ),
      (_, authorization) {
        _observedAuthorization = authorization;
        _accountGeneration++;
        _clear();
      },
    );
    ref.listen(playbackStoreProvider, (_, value) {
      if (value.isClosed) _clear();
    });
    ref.onDispose(() {
      _closed = true;
      service.close();
      unawaited(subscription.cancel());
    });
    unawaited(Future.microtask(_loadSetting));
    return const EpisodeMarkState();
  }

  String? currentAccount() {
    if (_closed || !state.enabled || _playback.isClosed) return null;
    var user = ref.read(bgmUserStoreProvider);
    var authorization = (user.user?.id, user.accessToken);
    // Offstage listeners can pause, and OAuth can replace the token before the
    // user ID. Read live authorization at every guard; expose only a generation.
    if (authorization != _observedAuthorization) {
      _observedAuthorization = authorization;
      _accountGeneration++;
    }
    if (user.user == null || user.accessToken == null) return null;
    return '${user.user!.id}:$_accountGeneration';
  }

  Future<void> _loadSetting() async {
    var revision = _settingsRevision;
    try {
      var value = await _playback.settingsStore.read(
        'playbackPromptMarkWatched',
      );
      if (_closed || revision != _settingsRevision) return;
      state = EpisodeMarkState(enabled: value == 'true');
    } catch (_) {
      // A missing/unreadable preference stays off. Explicit writes report their
      // errors to the caller instead of pretending to persist successfully.
    }
  }

  Future<void> setEnabled(bool enabled) {
    _settingsRevision++;
    var operation = _settingsOperation.then((_) async {
      if (_closed) return;
      await _playback.settingsStore.write(
        'playbackPromptMarkWatched',
        enabled.toString(),
      );
      if (_closed) return;
      if (!enabled) _accountGeneration++;
      state = EpisodeMarkState(
        enabled: enabled,
        prompts: enabled ? state.prompts : const [],
        confirmingId: enabled ? state.confirmingId : null,
      );
    });
    _settingsOperation = operation.catchError((Object _) {});
    return operation;
  }

  void _clear() {
    if (_closed) return;
    _seen.clear();
    state = EpisodeMarkState(enabled: state.enabled);
  }

  void acceptCompletion(PlaybackCompletion completion) =>
      _onCompletion(completion);

  void discardWindowPrompts() {
    _accountGeneration++;
    _clear();
  }

  void _onCompletion(PlaybackCompletion completion) {
    var account = currentAccount();
    if (account == null ||
        (completion.item.subject ?? 0) <= 0 ||
        !_seen.add(completion.eventId))
      return;
    if (_seen.length > 512) _seen.remove(_seen.first);
    var prompt = EpisodeMarkPrompt(completion: completion, account: account);
    var prompts = [...state.prompts, prompt];
    // Keep recent notices bounded. No abandoned notice becomes a durable job.
    if (prompts.length > 20) {
      var discarded = prompts.indexWhere(
        (item) => item.id != state.confirmingId,
      );
      prompts.removeAt(discarded);
    }
    _publish(prompts);
    unawaited(_resolve(prompt));
  }

  bool _valid(EpisodeMarkPrompt prompt) =>
      !_closed &&
      prompt.account == currentAccount() &&
      state.prompts.any((item) => item.id == prompt.id);

  void _publish(List<EpisodeMarkPrompt> prompts, {String? confirmingId}) {
    if (_closed) return;
    state = EpisodeMarkState(
      enabled: state.enabled,
      prompts: List.unmodifiable(prompts),
      confirmingId: confirmingId ?? state.confirmingId,
    );
  }

  Future<void> _resolve(EpisodeMarkPrompt prompt) async {
    var result = await service.prepare(prompt.completion);
    if (!_valid(prompt)) return;
    if (result.alreadyDone ||
        result.message == null && result.candidate == null) {
      dismiss(prompt.id);
      return;
    }
    var candidate = result.candidate;
    if (candidate != null &&
        state.prompts.any(
          (other) =>
              other.id != prompt.id &&
              other.candidate?.episode.id == candidate.episode.id,
        )) {
      dismiss(prompt.id);
      return;
    }
    _publish([
      for (var item in state.prompts)
        if (item.id == prompt.id)
          EpisodeMarkPrompt(
            completion: prompt.completion,
            account: prompt.account,
            candidate: candidate,
            message: result.message,
            loading: false,
            retryable: result.retryable,
          )
        else
          item,
    ]);
  }

  void retry(EpisodeMarkPrompt prompt) {
    if (!_valid(prompt) || prompt.loading || state.confirmingId != null) return;
    _publish([
      for (var item in state.prompts)
        if (item.id == prompt.id)
          EpisodeMarkPrompt(
            completion: prompt.completion,
            account: prompt.account,
          )
        else
          item,
    ]);
    unawaited(_resolve(prompt));
  }

  Future<EpisodeMarkCandidate?> beginConfirmation(
    EpisodeMarkPrompt prompt,
  ) async {
    if (!_valid(prompt) || state.confirmingId != null) return null;
    var candidate = prompt.candidate;
    if (candidate == null) return null;
    _publish(state.prompts, confirmingId: prompt.id);
    return candidate;
  }

  Future<EpisodeMarkWriteResult> confirm(EpisodeMarkPrompt prompt) async {
    if (!_valid(prompt) ||
        state.confirmingId != prompt.id ||
        prompt.candidate == null) {
      return const EpisodeMarkWriteResult(EpisodeMarkWriteStatus.expired);
    }
    var result = await service.confirm(prompt.candidate!);
    if (!_valid(prompt)) return result;
    if (result.status != EpisodeMarkWriteStatus.failed) {
      dismiss(prompt.id);
    } else {
      state = EpisodeMarkState(
        enabled: state.enabled,
        prompts: List.unmodifiable([
          for (var item in state.prompts)
            if (item.id == prompt.id)
              EpisodeMarkPrompt(
                completion: prompt.completion,
                account: prompt.account,
                candidate: prompt.candidate,
                loading: false,
                retryable: true,
                message: result.message,
              )
            else
              item,
        ]),
      );
    }
    return result;
  }

  void dismiss(String id) {
    if (_closed) return;
    state = EpisodeMarkState(
      enabled: state.enabled,
      prompts: List.unmodifiable(state.prompts.where((item) => item.id != id)),
      confirmingId: state.confirmingId == id ? null : state.confirmingId,
    );
  }
}
