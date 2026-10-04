import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/episode_mark_service.dart';
import '../core/services/playback_episode_protocol.dart';
import '../core/services/playback_window_protocol.dart';
import '../data/repositories/playback_window_remote.dart';
import '../models/playback/playback_item.dart';
import '../store/nav_store.dart';
import '../store/playback_store.dart';
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
  RemoteEpisodeMarkController(this.call);
  final PlaybackWindowCall call;
  int _revision = -1;
  bool _remoteClosed = false;

  @override
  EpisodeMarkState build() {
    ref.onDispose(() => _remoteClosed = true);
    return const EpisodeMarkState();
  }

  void receive(Object? value) {
    if (_remoteClosed) return;
    var data = playbackMap(value);
    var revision = playbackInt(data, 'revision');
    if (revision <= _revision) return;
    var next = decodeEpisodeMarkState(data);
    _revision = revision;
    state = next;
  }

  @override
  String? currentAccount() => _remoteClosed ? null : state.account;

  void invalidate() {
    state = const EpisodeMarkState();
    _remoteClosed = true;
  }

  @override
  Future<void> syncItems(
    List<PlaybackItem> items, {
    bool refresh = false,
  }) async {
    var account = currentAccount();
    if (_remoteClosed || account == null) return;
    try {
      var response = playbackMap(
        await call('episodes.syncItems', {
          'account': account,
          'items': [for (var item in items) item.toRow()],
          'refresh': refresh,
        }),
      );
      if (!_remoteClosed && currentAccount() == account) {
        receive(response['state']);
      }
    } catch (_) {
      if (_remoteClosed || currentAccount() != account) return;
      rethrow;
    }
  }

  @override
  Future<EpisodeMarkWriteResult> markItem(PlaybackItem item) async {
    if (_remoteClosed) {
      return const EpisodeMarkWriteResult(EpisodeMarkWriteStatus.expired);
    }
    var response = playbackMap(
      await call('episodes.markItem', {
        'account': currentAccount(),
        'item': item.toRow(),
      }),
    );
    receive(response['state']);
    var result = playbackMap(response['result']);
    return EpisodeMarkWriteResult(
      EpisodeMarkWriteStatus.values.byName(result['status'] as String),
      message: result['message'] as String?,
    );
  }
}
