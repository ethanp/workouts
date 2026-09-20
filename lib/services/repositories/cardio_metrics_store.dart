import 'package:ethan_sync/ethan_sync.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/cardio_workout_series.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/models/indoor_fitness_signals.dart';
import 'package:workouts/models/timestamped_heart_rate.dart';

const _needsMetricsSql = '''
  m.id IS NULL
  OR m.zone1_seconds IS NULL
''';

/// Computes and stores zone times in `cardio_computed_metrics` from HealthKit
/// series when a workout is opened.
class CardioMetricsStore(final PowerSyncDatabase _powerSync) {
  Future<void> persistFromHealthKitSeries({
    required CardioWorkout workout,
    required CardioWorkoutSeries series,
  }) async {
    final hrSamples = [
      for (final sample in series.heartRateSamples)
        TimestampedHeartRate(timestamp: sample.timestamp, bpm: sample.bpm),
    ];
    await _persist(
      workout.id,
      hrSamples.isEmpty ? HrZoneTime.zero : HrZoneTime.fromSamples(hrSamples),
      hasHrSamples: hrSamples.isNotEmpty,
      fitnessSignals: workout.fitnessSignals(
        heartRateSamples: hrSamples,
        distanceSamples: series.distanceSamples,
      ),
    );
  }

  Stream<int> watchMissingCount() => _powerSync
      .watch('''
        SELECT COUNT(*) AS cnt FROM cardio_workouts w
        LEFT JOIN cardio_computed_metrics m ON m.id = w.id
        WHERE $_needsMetricsSql
      ''')
      .map((rows) => (rows.first['cnt'] as int?) ?? 0);

  Future<void> _persist(
    String workoutId,
    HrZoneTime zone, {
    required bool hasHrSamples,
    required IndoorFitnessSignals fitnessSignals,
  }) async {
    final computedAt = DateTime.now().toUtc().toIso8601String();
    await _powerSync.upsert('cardio_computed_metrics', {
      'id': workoutId,
      ...zone.toRow(),
      'has_hr_samples': hasHrSamples ? 1 : 0,
      'pace_seconds_per_mile': fitnessSignals.paceSecondsPerMile,
      'meters_per_heartbeat': fitnessSignals.metersPerHeartbeat,
      'cardiac_drift_percent': fitnessSignals.cardiacDriftPercent,
      'has_distance_samples': fitnessSignals.hasDistanceSamples ? 1 : 0,
      'distance_origin': fitnessSignals.distanceOrigin.dbKey,
      'fitness_confidence': fitnessSignals.confidence.dbKey,
      'computed_at': computedAt,
    });
  }
}
