import 'package:workouts/models/cardio_type.dart';

class CardioWorkout {
  const CardioWorkout({
    required this.id,
    required this.externalWorkoutId,
    required this.activityType,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    this.energyKcal,
    this.averageHeartRateBpm,
    this.maxHeartRateBpm,
    required this.routeAvailable,
    required this.sourceName,
    this.sourceBundleId,
    this.deviceModel,
    this.createdAt,
    this.updatedAt,
  });

  factory CardioWorkout.fromRow(Map<String, dynamic> workoutRow) {
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
      routeAvailable: (workoutRow['route_available'] as int?) == 1,
      sourceName: (workoutRow['source_name'] as String?) ?? 'Apple Health',
      sourceBundleId: workoutRow['source_bundle_id'] as String?,
      deviceModel: workoutRow['device_model'] as String?,
      createdAt: _asDateTime(workoutRow['created_at']),
      updatedAt: _asDateTime(workoutRow['updated_at']),
    );
  }

  final String id;
  final String externalWorkoutId;
  final CardioType activityType;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final double distanceMeters;
  final double? energyKcal;
  final double? averageHeartRateBpm;
  final double? maxHeartRateBpm;
  final bool routeAvailable;
  final String sourceName;
  final String? sourceBundleId;
  final String? deviceModel;
  final DateTime? createdAt;
  final DateTime? updatedAt;
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
