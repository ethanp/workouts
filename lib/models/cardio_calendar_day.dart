import 'package:workouts/models/hr_zone_time.dart';

/// Aggregated cardio workout data for a single calendar day, produced by
/// [CardioRepositoryPowerSync.watchCalendarDays].
class CardioCalendarDay {
  CardioCalendarDay({
    required this.date,
    required this.outdoorRunDistanceMeters,
    required this.totalDurationSeconds,
    required this.zoneTime,
    required this.trimp,
    required this.hasHrData,
    required this.workoutCount,
  });

  factory CardioCalendarDay.fromRow(Map<String, dynamic> dayRow) {
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
      trimp: _asDouble(dayRow['total_trimp']) ?? 0,
      hasHrData: (dayRow['has_hr_data'] as int? ?? 0) == 1,
      workoutCount: (dayRow['workout_count'] as int?) ?? 0,
    );
  }

  final DateTime date;
  final double outdoorRunDistanceMeters;
  final int totalDurationSeconds;

  final HrZoneTime zoneTime;

  /// Sum of Banister TRIMP across all cardio workouts that day.
  final double trimp;

  /// True if at least one workout that day has heart rate samples stored.
  final bool hasHrData;

  final int workoutCount;

  bool get hasActivity => workoutCount > 0;
}

double? _asDouble(Object? rawValue) {
  if (rawValue == null) return null;
  if (rawValue is num) return rawValue.toDouble();
  return double.tryParse('$rawValue');
}
