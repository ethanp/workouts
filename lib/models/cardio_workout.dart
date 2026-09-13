import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/distance_origin.dart';
import 'package:workouts/models/fitness_signal_confidence.dart';
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
  final String? deviceName,
  final double? elevationAscendedMeters,
  final double? recoveryBpm,
  final double? effortScore,
  final double? estimatedEffortScore,
  final bool machineLinked = false,
  final double? averageMets,
  final double? fitnessMachineDurationSeconds,
  final double? crossTrainerDistanceMeters,
  final double? indoorBikeDistanceMeters,
  final double? basalEnergyKcal,
  final double? stepCount,
  final double? flightsClimbed,
  final double? minHeartRateBpm,
  final double? paceSecondsPerMile,
  final double? metersPerHeartbeat,
  final double? cardiacDriftPercent,
  final bool hasDistanceSamples = false,
  final DistanceOrigin distanceOrigin = DistanceOrigin.unknown,
  final FitnessSignalConfidence fitnessConfidence =
      FitnessSignalConfidence.insufficient,
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
      deviceName: workoutRow['device_name'] as String?,
      elevationAscendedMeters: _asDouble(workoutRow['elevation_ascended_meters']),
      recoveryBpm: _asDouble(workoutRow['recovery_bpm']),
      effortScore: _asDouble(workoutRow['effort_score']),
      estimatedEffortScore: _asDouble(workoutRow['estimated_effort_score']),
      machineLinked: (workoutRow['machine_linked'] as int?) == 1,
      averageMets: _asDouble(workoutRow['average_mets']),
      fitnessMachineDurationSeconds: _asDouble(
        workoutRow['fitness_machine_duration_seconds'],
      ),
      crossTrainerDistanceMeters: _asDouble(
        workoutRow['cross_trainer_distance_meters'],
      ),
      indoorBikeDistanceMeters: _asDouble(
        workoutRow['indoor_bike_distance_meters'],
      ),
      basalEnergyKcal: _asDouble(workoutRow['basal_energy_kcal']),
      stepCount: _asDouble(workoutRow['step_count']),
      flightsClimbed: _asDouble(workoutRow['flights_climbed']),
      minHeartRateBpm: _asDouble(workoutRow['min_heart_rate_bpm']),
      paceSecondsPerMile: _asDouble(workoutRow['pace_seconds_per_mile']),
      metersPerHeartbeat: _asDouble(workoutRow['meters_per_heartbeat']),
      cardiacDriftPercent: _asDouble(workoutRow['cardiac_drift_percent']),
      hasDistanceSamples: (workoutRow['has_distance_samples'] as int?) == 1,
      distanceOrigin: DistanceOrigin.fromDbKey(
        workoutRow['distance_origin'] as String?,
      ),
      fitnessConfidence: FitnessSignalConfidence.fromDbKey(
        workoutRow['fitness_confidence'] as String?,
      ),
      createdAt: _asDateTime(workoutRow['created_at']),
      updatedAt: _asDateTime(workoutRow['updated_at']),
    );
  }

  double get displayDistanceMeters {
    if (distanceMeters > 0) return distanceMeters;
    return crossTrainerDistanceMeters ?? indoorBikeDistanceMeters ?? 0;
  }

  String get sourceCaption {
    final machineCaption = machineLinked ? 'Machine-linked' : 'Watch estimate';
    final namedDevice = deviceName;
    if (namedDevice == null || namedDevice.isEmpty) {
      return '$sourceName · $machineCaption';
    }
    return '$sourceName · $namedDevice · $machineCaption';
  }

  String get shortProvenanceCaption {
    final machineCaption = machineLinked ? 'machine-linked' : 'Watch estimate';
    final namedDevice = deviceName;
    if (namedDevice == null || namedDevice.isEmpty) return machineCaption;
    return '$namedDevice · $machineCaption';
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
