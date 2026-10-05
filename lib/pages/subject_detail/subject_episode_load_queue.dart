// Dart imports:
import 'dart:async';

/// Serializes chapter pagination and refreshes for one details-page instance.
/// Repeated page loads share a request; updates during a refresh require a
/// trailing refresh so a newer watched state is not lost.
class SubjectEpisodeLoadQueue {
  SubjectEpisodeLoadQueue({required this.loadPage, required this.refreshList});

  final Future<void> Function(bool reportError) loadPage;
  final Future<void> Function() refreshList;
  Future<void>? _inFlight;
  bool _refreshPending = false;

  Future<void> load({bool reportError = false}) =>
      _inFlight ??= _run(() => loadPage(reportError));

  Future<void> refresh() {
    _refreshPending = true;
    return _inFlight ??= _run(null);
  }

  // Defer callbacks until _inFlight is assigned, including reentrant requests.
  Future<void> _run(Future<void> Function()? action) =>
      Future<void>.microtask(() async {
        Object? lastError;
        StackTrace? lastStackTrace;
        try {
          do {
            if (action == null) {
              _refreshPending = false;
              action = refreshList;
            }
            try {
              await action!();
              lastError = null;
              lastStackTrace = null;
            } catch (error, stackTrace) {
              lastError = error;
              lastStackTrace = stackTrace;
            }
            action = null;
          } while (_refreshPending);
          if (lastError != null) {
            Error.throwWithStackTrace(lastError, lastStackTrace!);
          }
        } finally {
          _inFlight = null;
        }
      });
}
