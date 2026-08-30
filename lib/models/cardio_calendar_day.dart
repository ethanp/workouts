import 'package:workouts/models/hr_zone_time.dart';

/// Aggregated cardio workout data for a single calendar day, produced by
/// [CardioRepositoryPowerSync.watchCalendarDays].
class CardioCalendarDay({
  required final DateTime date,
  required final double outdoorRunDistanceMeters,
  required final int totalDurationSeconds,
  required final HrZoneTime zoneTime,

  /// True if at least one workout that day has heart rate samples stored.
  required final bool hasHrData,
  required final int workoutCount,
}) {
  factory fromRow(Map<String, dynamic> dayRow) {
    final String dayString = dayRow['day'] as String;
    final List<String> dateParts = dayString.split('-');
    return CardioCalendarDay(
      date: DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      ),
      outdoorRunDistanceMeters:
          _asDouble(dayRow['outdoor_run_distance_meters']) ?? 0,
      totalDurationSeconds: (dayRow['total_duration_seconds'] as int?) ?? 0,
      zoneTime: HrZoneTime.fromRow(dayRow),
      hasHrData: (dayRow['has_hr_data'] as int? ?? 0) == 1,
      workoutCount: (dayRow['workout_count'] as int?) ?? 0,
    );
  }

  bool get hasActivity => workoutCount > 0;
}

double? _asDouble(Object? rawValue) {
  if (rawValue == null) return null;
  if (rawValue is num) return rawValue.toDouble();
  return double.tryParse('$rawValue');
}
