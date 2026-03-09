/// Unified calendar day aggregating runs and sessions.
class ActivityCalendarDay {
  ActivityCalendarDay({
    required this.date,
    required this.totalRunDistanceMeters,
    required this.totalRunDurationSeconds,
    required this.runZone1Minutes,
    required this.runZone2Minutes,
    required this.runZone3Minutes,
    required this.runZone4Minutes,
    required this.runZone5Minutes,
    required this.runTrimp,
    required this.runHasHrData,
    required this.runCount,
    required this.totalSessionDurationSeconds,
    required this.sessionZone1Minutes,
    required this.sessionZone2Minutes,
    required this.sessionZone3Minutes,
    required this.sessionZone4Minutes,
    required this.sessionZone5Minutes,
    required this.sessionTrimp,
    required this.sessionCount,
  });

  final DateTime date;
  final double totalRunDistanceMeters;
  final int totalRunDurationSeconds;

  final int runZone1Minutes;
  final int runZone2Minutes;
  final int runZone3Minutes;
  final int runZone4Minutes;
  final int runZone5Minutes;

  int get runGteZone2Minutes =>
      runZone2Minutes + runZone3Minutes + runZone4Minutes + runZone5Minutes;

  final double runTrimp;
  final bool runHasHrData;
  final int runCount;

  final int totalSessionDurationSeconds;

  final int sessionZone1Minutes;
  final int sessionZone2Minutes;
  final int sessionZone3Minutes;
  final int sessionZone4Minutes;
  final int sessionZone5Minutes;

  int get sessionGteZone2Minutes =>
      sessionZone2Minutes +
      sessionZone3Minutes +
      sessionZone4Minutes +
      sessionZone5Minutes;

  final double sessionTrimp;
  final int sessionCount;

  bool get hasActivity => runCount > 0 || sessionCount > 0;

  int get totalZone1Minutes => runZone1Minutes + sessionZone1Minutes;
  int get totalZone2Minutes => runZone2Minutes + sessionZone2Minutes;
  int get totalZone3Minutes => runZone3Minutes + sessionZone3Minutes;
  int get totalZone4Minutes => runZone4Minutes + sessionZone4Minutes;
  int get totalZone5Minutes => runZone5Minutes + sessionZone5Minutes;

  int get totalGteZone2Minutes => runGteZone2Minutes + sessionGteZone2Minutes;
  double get totalTrimp => runTrimp + sessionTrimp;
}
