import '../../core/services/episode_mark_service.dart';
import 'playback_completion.dart';

class EpisodeMarkPrompt {
  const EpisodeMarkPrompt({
    required this.completion,
    required this.account,
    this.candidate,
    this.message,
    this.loading = true,
    this.retryable = false,
  });

  final PlaybackCompletion completion;
  final String account;
  final EpisodeMarkCandidate? candidate;
  final String? message;
  final bool loading;
  final bool retryable;
  String get id => completion.eventId;
}

class EpisodeMarkState {
  const EpisodeMarkState({
    this.enabled = false,
    this.prompts = const [],
    this.confirmingId,
  });
  final bool enabled;
  final List<EpisodeMarkPrompt> prompts;
  final String? confirmingId;
}
