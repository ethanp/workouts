/// Aggregated session data for a single calendar day.
/// Only tracks total duration (no Zone 2 for sessions).
class SessionCalendarDay {
  SessionCalendarDay({
    required this.date,
    required this.totalDurationSeconds,
    required this.sessionCount,
  });

  final DateTime date;
  final int totalDurationSeconds;
  final int sessionCount;

  bool get hasActivity => sessionCount > 0;
}
