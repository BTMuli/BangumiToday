import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/episode_mark_service.dart';
import '../core/services/playback_episode_protocol.dart';
import '../core/services/playback_window_protocol.dart';
import '../data/repositories/playback_window_remote.dart';
import '../models/playback/playback_completion.dart';
import '../store/nav_store.dart';
import '../store/playback_store.dart';
import '../tools/log_tool.dart';
import 'episode_mark_providers.dart';

final isPlaybackWindowProvider = Provider<bool>((ref) => false);
final playbackSubjectNavigationProvider = Provider<Future<void> Function(int)>(
  (ref) => (subject) async {
    var name = ref.read(playbackStoreProvider).nameFor(subject);
    ref
        .read(navStoreProvider.notifier)
        .addNavItemB(subject: subject, paneTitle: name);
  },
);

/// The child holds presentation only. All authorization checks and API writes
/// run in the main engine's EpisodeMarkController.
class RemoteEpisodeMarkController extends EpisodeMarkController {
  RemoteEpisodeMarkController(this.call, this.completions);
  final PlaybackWindowCall call;
  final Stream<PlaybackCompletion> completions;
  String? _account;
  int _revision = -1;
  bool _remoteClosed = false;

  @override
  EpisodeMarkState build() {
    var subscription = completions.listen((event) {
      _send('episodes.completed', encodePlaybackCompletion(event));
    });
    ref.onDispose(() {
      _remoteClosed = true;
      unawaited(subscription.cancel());
    });
    return const EpisodeMarkState();
  }

  void receive(Object? value) {
    if (_remoteClosed) return;
    var data = playbackMap(value);
    var revision = playbackInt(data, 'revision');
    if (revision <= _revision) return;
    var next = decodeEpisodeMarkState(data);
    _revision = revision;
    _account = data['account'] as String?;
    state = next;
  }

  @override
  String? currentAccount() => _remoteClosed ? null : _account;

  void invalidate() {
    _account = null;
    state = const EpisodeMarkState();
    _remoteClosed = true;
  }

  Future<Object?> _request(String method, Map<String, Object?> body) async {
    var result = playbackMap(await call(method, body));
    receive(result['state']);
    return result['result'];
  }

  void _send(String method, Map<String, Object?> body) {
    if (_remoteClosed) return;
    unawaited(
      _request(method, body).catchError((Object error) {
        BTLogTool.warn('播放器章节请求失败：$error');
        return null;
      }),
    );
  }

  Map<String, Object?> _prompt(EpisodeMarkPrompt prompt) => {
    'id': prompt.id,
    'account': prompt.account,
  };

  @override
  Future<void> setEnabled(bool enabled) async {
    await _request('episodes.enabled', {'enabled': enabled});
  }

  @override
  void retry(EpisodeMarkPrompt prompt) =>
      _send('episodes.retry', _prompt(prompt));

  @override
  Future<EpisodeMarkCandidate?> beginConfirmation(
    EpisodeMarkPrompt prompt,
  ) async {
    var accepted = await _request('episodes.begin', _prompt(prompt));
    if (accepted != true || state.confirmingId != prompt.id) return null;
    for (var item in state.prompts) {
      if (item.id == prompt.id && item.account == currentAccount()) {
        return item.candidate;
      }
    }
    return null;
  }

  @override
  Future<EpisodeMarkWriteResult> confirm(EpisodeMarkPrompt prompt) async {
    var data = playbackMap(await _request('episodes.confirm', _prompt(prompt)));
    return EpisodeMarkWriteResult(
      EpisodeMarkWriteStatus.values.byName(data['status'] as String),
      message: data['message'] as String?,
    );
  }

  @override
  void dismiss(String id) => _send('episodes.dismiss', {'id': id});
}
