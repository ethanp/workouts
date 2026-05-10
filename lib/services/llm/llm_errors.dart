class RateLimitedException implements Exception {
  final Duration retryAfter;

  RateLimitedException({this.retryAfter = const Duration(minutes: 5)});

  @override
  String toString() =>
      'Rate limited. Try again in ${retryAfter.inMinutes} minutes.';
}

class LlmException implements Exception {
  final String message;

  LlmException(this.message);

  @override
  String toString() => message;
}
