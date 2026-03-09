/// Aggregated session data for a single calendar day.
class SessionCalendarDay {
  SessionCalendarDay({
    required this.date,
    required this.totalDurationSeconds,
    required this.zone1Minutes,
    required this.zone2Minutes,
    required this.zone3Minutes,
    required this.zone4Minutes,
    required this.zone5Minutes,
    required this.trimp,
    required this.sessionCount,
  });

  final DateTime date;
  final int totalDurationSeconds;

  final int zone1Minutes;
  final int zone2Minutes;
  final int zone3Minutes;
  final int zone4Minutes;
  final int zone5Minutes;

  int get gteZone2Minutes =>
      zone2Minutes + zone3Minutes + zone4Minutes + zone5Minutes;

  /// Sum of Banister TRIMP across all sessions that day.
  final double trimp;

  final int sessionCount;

  bool get hasActivity => sessionCount > 0;
}
