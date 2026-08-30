import 'package:workouts/models/hr_zone_time.dart';

class const WeekZoneData({
  required final String label,
  required final DateTime weekStart,
  required final HrZoneTime zoneTime,
  final bool isCurrent = false,
  final bool includeInAverage = true,
});
