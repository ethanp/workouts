/// Aggregated session data for a single calendar day.
class SessionCalendarDay {
  SessionCalendarDay({
    required this.date,
    required this.totalDurationSeconds,
    required this.zone2Minutes,
    required this.trimp,
    required this.sessionCount,
  });

  final DateTime date;
  final int totalDurationSeconds;

  /// Total Zone 2 minutes across all sessions that day.
  final int zone2Minutes;

  /// Sum of Banister TRIMP across all sessions that day.
  final double trimp;

  final int sessionCount;

  bool get hasActivity => sessionCount > 0;
}
