import 'package:workouts/models/hr_zone_time.dart';

class WeekZoneData {
  const WeekZoneData({
    required this.label,
    required this.weekStart,
    required this.zoneTime,
    this.isCurrent = false,
    this.includeInAverage = true,
  });

  final String label;
  final DateTime weekStart;
  final HrZoneTime zoneTime;
  final bool isCurrent;
  final bool includeInAverage;
}
