/// Unified calendar day aggregating runs and sessions.
/// Sessions only contribute duration (no Zone 2).
class ActivityCalendarDay {
  ActivityCalendarDay({
    required this.date,
    required this.totalRunDistanceMeters,
    required this.totalRunDurationSeconds,
    required this.runZone2Minutes,
    required this.runHasHrData,
    required this.runCount,
    required this.totalSessionDurationSeconds,
    required this.sessionCount,
  });

  final DateTime date;
  final double totalRunDistanceMeters;
  final int totalRunDurationSeconds;
  final int runZone2Minutes;
  final bool runHasHrData;
  final int runCount;
  final int totalSessionDurationSeconds;
  final int sessionCount;

  bool get hasActivity => runCount > 0 || sessionCount > 0;
}
