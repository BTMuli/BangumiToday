class RssRequestFailure {
  const RssRequestFailure({required this.retryable, this.retryAfter});

  final bool retryable;
  final Duration? retryAfter;
}
