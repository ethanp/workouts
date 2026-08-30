class RateLimitedException({
  final Duration retryAfter = const Duration(minutes: 5),
}) implements Exception {
  @override
  String toString() =>
      'Rate limited. Try again in ${retryAfter.inMinutes} minutes.';
}

class LlmException(final String message) implements Exception {
  @override
  String toString() => message;
}
