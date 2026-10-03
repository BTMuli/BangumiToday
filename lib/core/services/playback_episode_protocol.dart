import '../../domain/repositories/episode_mark_gateway.dart';
import '../../models/playback/episode_mark_state.dart';
import 'episode_mark_service.dart';
import 'playback_window_protocol.dart';

Map<String, Object?> encodeEpisodeMarkState(
  EpisodeMarkState state, {
  required String? account,
  required int revision,
}) => {
  'revision': revision,
  'account': account,
  'enabled': state.enabled,
  'confirmingId': state.confirmingId,
  'prompts': [
    for (var prompt in state.prompts)
      {
        'completion': encodePlaybackCompletion(prompt.completion),
        'account': prompt.account,
        'message': prompt.message,
        'loading': prompt.loading,
        'retryable': prompt.retryable,
        'candidate': prompt.candidate == null
            ? null
            : {
                'id': prompt.candidate!.episode.id,
                'type': prompt.candidate!.episode.type,
                'sort': prompt.candidate!.episode.sort,
                'name': prompt.candidate!.episode.name,
                'withinSubject': prompt.candidate!.episode.withinSubject,
                'number': prompt.candidate!.number,
              },
      },
  ],
};

EpisodeMarkState decodeEpisodeMarkState(Map<String, Object?> value) {
  var prompts = <EpisodeMarkPrompt>[];
  for (var item in value['prompts'] as List) {
    var data = playbackMap(item);
    var completion = decodePlaybackCompletion(data['completion']);
    var account = playbackString(data, 'account');
    var candidateData = data['candidate'];
    EpisodeMarkCandidate? candidate;
    if (candidateData != null) {
      var episode = playbackMap(candidateData);
      candidate = EpisodeMarkCandidate(
        completion: completion,
        account: account,
        episode: EpisodeMarkEpisode(
          id: playbackInt(episode, 'id', minimum: 1),
          type: playbackInt(episode, 'type'),
          sort: (episode['sort'] as num).toDouble(),
          name: episode['name'] as String,
          withinSubject: (episode['withinSubject'] as num?)?.toDouble(),
        ),
        number: playbackInt(episode, 'number', minimum: 1),
      );
    }
    prompts.add(
      EpisodeMarkPrompt(
        completion: completion,
        account: account,
        candidate: candidate,
        message: data['message'] as String?,
        loading: data['loading'] as bool,
        retryable: data['retryable'] as bool,
      ),
    );
  }
  return EpisodeMarkState(
    enabled: value['enabled'] as bool,
    confirmingId: value['confirmingId'] as String?,
    prompts: List.unmodifiable(prompts),
  );
}
