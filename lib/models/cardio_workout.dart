import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/hr_zone_time.dart';

class const CardioWorkout({
  required final String id,
  required final String externalWorkoutId,
  required final CardioType activityType,
  required final DateTime startedAt,
  required final DateTime endedAt,
  required final int durationSeconds,
  required final double distanceMeters,
  final double? energyKcal,
  final double? averageHeartRateBpm,
  final double? maxHeartRateBpm,
  final HrZoneTime zoneTime = HrZoneTime.zero,
  final bool hasHrSamples = false,
  required final bool routeAvailable,
  required final String sourceName,
  final String? sourceBundleId,
  final String? deviceModel,
  final DateTime? createdAt,
  final DateTime? updatedAt,
}) {
  factory fromRow(Map<String, dynamic> workoutRow) {
    return CardioWorkout(
      id: workoutRow['id'] as String,
      externalWorkoutId: workoutRow['external_workout_id'] as String,
      activityType: CardioType.fromDbKey(
        (workoutRow['activity_type'] as String?) ?? CardioType.outdoorRun.dbKey,
      ),
      startedAt: DateTime.parse(workoutRow['started_at'] as String),
      endedAt: DateTime.parse(workoutRow['ended_at'] as String),
      durationSeconds: (workoutRow['duration_seconds'] as int?) ?? 0,
      distanceMeters: _asDouble(workoutRow['distance_meters']) ?? 0,
      energyKcal: _asDouble(workoutRow['energy_kcal']),
      averageHeartRateBpm: _asDouble(workoutRow['avg_heart_rate_bpm']),
      maxHeartRateBpm: _asDouble(workoutRow['max_heart_rate_bpm']),
      zoneTime: HrZoneTime.fromRow(workoutRow, prefix: 'zone'),
      hasHrSamples: (workoutRow['has_hr_samples'] as int?) == 1,
      routeAvailable: (workoutRow['route_available'] as int?) == 1,
      sourceName: (workoutRow['source_name'] as String?) ?? 'Apple Health',
      sourceBundleId: workoutRow['source_bundle_id'] as String?,
      deviceModel: workoutRow['device_model'] as String?,
      createdAt: _asDateTime(workoutRow['created_at']),
      updatedAt: _asDateTime(workoutRow['updated_at']),
    );
  }
}

double? _asDouble(Object? rawValue) {
  if (rawValue == null) return null;
  if (rawValue is num) return rawValue.toDouble();
  return double.tryParse('$rawValue');
}

DateTime? _asDateTime(Object? rawValue) {
  final String? maybeDateTime = rawValue as String?;
  return maybeDateTime == null ? null : DateTime.tryParse(maybeDateTime);
}
