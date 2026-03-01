/// Aggregated run data for a single calendar day, produced by
/// [RunsRepositoryPowerSync.watchCalendarDays].
class RunCalendarDay {
  RunCalendarDay({
    required this.date,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.zone2Minutes,
    required this.hasHrData,
    required this.runCount,
  });

  final DateTime date;
  final double totalDistanceMeters;
  final int totalDurationSeconds;

  /// Total Zone 2 minutes across all runs that day.
  /// Zero when [hasHrData] is false.
  final int zone2Minutes;

  /// True if at least one run that day has heart rate samples stored.
  final bool hasHrData;

  final int runCount;

  bool get hasActivity => runCount > 0;
}
