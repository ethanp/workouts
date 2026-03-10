import 'package:workouts/models/hr_zone_time.dart';

/// Aggregated cardio workout data for a single calendar day, produced by
/// [CardioRepositoryPowerSync.watchCalendarDays].
class CardioCalendarDay {
  CardioCalendarDay({
    required this.date,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.zoneTime,
    required this.trimp,
    required this.hasHrData,
    required this.workoutCount,
  });

  final DateTime date;
  final double totalDistanceMeters;
  final int totalDurationSeconds;

  final HrZoneTime zoneTime;

  /// Sum of Banister TRIMP across all cardio workouts that day.
  final double trimp;

  /// True if at least one workout that day has heart rate samples stored.
  final bool hasHrData;

  final int workoutCount;

  bool get hasActivity => workoutCount > 0;
}
