import 'package:workouts/models/hr_zone_time.dart';

/// Unified calendar day aggregating cardio workouts and sessions.
class ActivityCalendarDay({
  required final DateTime date,
  required final double outdoorRunDistanceMeters,
  required final int totalCardioDurationSeconds,
  required final HrZoneTime cardioZoneTime,
  required final bool cardioHasHrData,
  required final int cardioCount,
  required final int totalSessionDurationSeconds,
  required final HrZoneTime sessionZoneTime,
  required final int sessionCount,
}) {
  bool get hasActivity => cardioCount > 0 || sessionCount > 0;

  HrZoneTime get totalZoneTime => cardioZoneTime + sessionZoneTime;
}
