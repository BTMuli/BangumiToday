import '../../models/playback/episode_mark_state.dart';

Map<String, Object?> encodeEpisodeMarkState(
  EpisodeMarkState state, {
  required String? account,
  required int revision,
}) => {
  'revision': revision,
  'account': account,
  'marked': state.account == account ? state.marked.toList() : <String>[],
  'checked': state.account == account ? state.checked.toList() : <String>[],
  'loading': state.account == account ? state.loading.toList() : <String>[],
};

EpisodeMarkState decodeEpisodeMarkState(Map<String, Object?> value) =>
    EpisodeMarkState(
      account: value['account'] as String?,
      marked: Set.unmodifiable((value['marked'] as List).cast<String>()),
      checked: Set.unmodifiable((value['checked'] as List).cast<String>()),
      loading: Set.unmodifiable((value['loading'] as List).cast<String>()),
    );
