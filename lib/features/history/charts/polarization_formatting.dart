import 'package:workouts/models/hr_zone_time.dart';

String formatPolarizationMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
}

/// Formats a zone range label, e.g. `formatPolarizationZoneRange(1, 2)` → `"Z1–2 · 93–145"`.
String formatPolarizationZoneRange(int fromZone, [int? toZone]) {
  toZone ??= fromZone;
  final lower = HrZone.values[fromZone - 1].lowerBpm;
  final upper = HrZone.values[toZone - 1].upperBpm;
  final zoneLabel = fromZone == toZone ? 'Z$fromZone' : 'Z$fromZone–$toZone';
  return '$zoneLabel · $lower–$upper';
}
