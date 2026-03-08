/// Unified calendar day aggregating runs and sessions.
class ActivityCalendarDay {
  ActivityCalendarDay({
    required this.date,
    required this.totalRunDistanceMeters,
    required this.totalRunDurationSeconds,
    required this.runZone2Minutes,
    required this.runTrimp,
    required this.runHasHrData,
    required this.runCount,
    required this.totalSessionDurationSeconds,
    required this.sessionZone2Minutes,
    required this.sessionTrimp,
    required this.sessionCount,
  });

  final DateTime date;
  final double totalRunDistanceMeters;
  final int totalRunDurationSeconds;
  final int runZone2Minutes;
  final double runTrimp;
  final bool runHasHrData;
  final int runCount;
  final int totalSessionDurationSeconds;
  final int sessionZone2Minutes;
  final double sessionTrimp;
  final int sessionCount;

  bool get hasActivity => runCount > 0 || sessionCount > 0;

  int get totalZone2Minutes => runZone2Minutes + sessionZone2Minutes;
  double get totalTrimp => runTrimp + sessionTrimp;
}
