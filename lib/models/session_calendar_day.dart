import 'package:workouts/models/hr_zone_time.dart';

/// Aggregated session data for a single calendar day.
class SessionCalendarDay {
  SessionCalendarDay({
    required this.date,
    required this.totalDurationSeconds,
    required this.zoneTime,
    required this.trimp,
    required this.sessionCount,
  });

  final DateTime date;
  final int totalDurationSeconds;

  final HrZoneTime zoneTime;

  /// Sum of Banister TRIMP across all sessions that day.
  final double trimp;

  final int sessionCount;

  bool get hasActivity => sessionCount > 0;
}
