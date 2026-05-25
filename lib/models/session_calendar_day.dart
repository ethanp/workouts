import 'package:workouts/models/hr_zone_time.dart';

/// Aggregated session data for a single calendar day.
class SessionCalendarDay {
  SessionCalendarDay({
    required this.date,
    required this.totalDurationSeconds,
    required this.zoneTime,
    required this.sessionCount,
  });

  factory SessionCalendarDay.fromRow(Map<String, dynamic> dayRow) {
    final String dayString = dayRow['day'] as String;
    final List<String> dateParts = dayString.split('-');
    return SessionCalendarDay(
      date: DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      ),
      totalDurationSeconds: (dayRow['total_duration_seconds'] as int?) ?? 0,
      zoneTime: HrZoneTime.fromRow(dayRow),
      sessionCount: (dayRow['session_count'] as int?) ?? 0,
    );
  }

  final DateTime date;
  final int totalDurationSeconds;
  final HrZoneTime zoneTime;
  final int sessionCount;

  bool get hasActivity => sessionCount > 0;
}
