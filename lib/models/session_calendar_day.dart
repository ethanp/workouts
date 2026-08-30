import 'package:workouts/models/hr_zone_time.dart';

/// Aggregated session data for a single calendar day.
class SessionCalendarDay({
  required final DateTime date,
  required final int totalDurationSeconds,
  required final HrZoneTime zoneTime,
  required final int sessionCount,
}) {
  factory fromRow(Map<String, dynamic> dayRow) {
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

  bool get hasActivity => sessionCount > 0;
}
