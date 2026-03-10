import 'package:workouts/models/hr_zone_time.dart';

/// Unified calendar day aggregating cardio workouts and sessions.
class ActivityCalendarDay {
  ActivityCalendarDay({
    required this.date,
    required this.totalCardioDistanceMeters,
    required this.totalCardioDurationSeconds,
    required this.cardioZoneTime,
    required this.cardioTrimp,
    required this.cardioHasHrData,
    required this.cardioCount,
    required this.totalSessionDurationSeconds,
    required this.sessionZoneTime,
    required this.sessionTrimp,
    required this.sessionCount,
  });

  final DateTime date;
  final double totalCardioDistanceMeters;
  final int totalCardioDurationSeconds;

  final HrZoneTime cardioZoneTime;
  final double cardioTrimp;
  final bool cardioHasHrData;
  final int cardioCount;

  final int totalSessionDurationSeconds;

  final HrZoneTime sessionZoneTime;
  final double sessionTrimp;
  final int sessionCount;

  bool get hasActivity => cardioCount > 0 || sessionCount > 0;

  HrZoneTime get totalZoneTime => cardioZoneTime + sessionZoneTime;
  double get totalTrimp => cardioTrimp + sessionTrimp;
}
