/// Aggregated run data for a single calendar day, produced by
/// [RunsRepositoryPowerSync.watchCalendarDays].
class RunCalendarDay {
  RunCalendarDay({
    required this.date,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.zone1Minutes,
    required this.zone2Minutes,
    required this.zone3Minutes,
    required this.zone4Minutes,
    required this.zone5Minutes,
    required this.trimp,
    required this.hasHrData,
    required this.runCount,
  });

  final DateTime date;
  final double totalDistanceMeters;
  final int totalDurationSeconds;

  final int zone1Minutes;
  final int zone2Minutes;
  final int zone3Minutes;
  final int zone4Minutes;
  final int zone5Minutes;

  int get gteZone2Minutes =>
      zone2Minutes + zone3Minutes + zone4Minutes + zone5Minutes;

  /// Sum of Banister TRIMP across all runs that day.
  final double trimp;

  /// True if at least one run that day has heart rate samples stored.
  final bool hasHrData;

  final int runCount;

  bool get hasActivity => runCount > 0;
}
