// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
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
  int _epoch = 0;
  bool _remoteClosed = false;
  bool _suspended = false;

  @override
  EpisodeMarkState build() {
    ref.onDispose(() => _remoteClosed = true);
    return const EpisodeMarkState();
  }

  void receive(Object? value) {
    if (_remoteClosed || _suspended) return;
    var data = playbackMap(value);
    var revision = playbackInt(data, 'revision');
    if (revision <= _revision) return;
    var next = decodeEpisodeMarkState(data);
    _revision = revision;
    state = next;
  }

  @override
  String? currentAccount() =>
      _remoteClosed || _suspended ? null : state.account;

  void suspend() {
    _epoch++;
    _suspended = true;
    state = const EpisodeMarkState();
  }

  void resume() {
    if (!_remoteClosed) _suspended = false;
  }

  void invalidate() {
    suspend();
    _remoteClosed = true;
  }

  @override
  Future<void> syncItems(
    List<PlaybackItem> items, {
    bool refresh = false,
  }) async {
    var account = currentAccount();
    var epoch = _epoch;
    if (_remoteClosed || _suspended || account == null) return;
    try {
      var response = playbackMap(
        await call('episodes.syncItems', {
          'account': account,
          'items': [for (var item in items) item.toRow()],
          'refresh': refresh,
        }),
      );
      if (!_remoteClosed && epoch == _epoch && currentAccount() == account) {
        receive(response['state']);
      }
    } catch (_) {
      if (_remoteClosed || epoch != _epoch || currentAccount() != account) {
        return;
      }
      rethrow;
    }
  }

  @override
  Future<EpisodeMarkWriteResult> markItem(PlaybackItem item) async {
    if (_remoteClosed || _suspended) {
      return const EpisodeMarkWriteResult(EpisodeMarkWriteStatus.expired);
    }
    var epoch = _epoch;
    var account = currentAccount();
    Map<String, Object?> response;
    try {
      response = playbackMap(
        await call('episodes.markItem', {
          'account': account,
          'item': item.toRow(),
        }),
      );
    } catch (_) {
      if (_remoteClosed || epoch != _epoch || currentAccount() != account) {
        return const EpisodeMarkWriteResult(EpisodeMarkWriteStatus.expired);
      }
      rethrow;
    }
    if (_remoteClosed || epoch != _epoch || currentAccount() != account) {
      return const EpisodeMarkWriteResult(EpisodeMarkWriteStatus.expired);
    }
    receive(response['state']);
    var result = playbackMap(response['result']);
    return EpisodeMarkWriteResult(
      EpisodeMarkWriteStatus.values.byName(result['status'] as String),
      message: result['message'] as String?,
    );
  }
}
