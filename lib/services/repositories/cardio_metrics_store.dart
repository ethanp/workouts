import 'package:ethan_sync/ethan_sync.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/cardio_workout_series.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/models/indoor_fitness_signals.dart';
import 'package:workouts/models/timestamped_heart_rate.dart';
import 'package:workouts/models/workout_history.dart';

/// Zone rows in `cardio_computed_metrics`.
///
/// `hr_sample_count` is written only after an expanded Apple Health series is
/// read. Null means the calendar minute is not finished yet. A later read
/// replaces that minute when it has at least as many samples and the zones differ.
class CardioMetricsStore(final PowerSyncDatabase _powerSync) {
  static String get workoutsSinceFirstDayWhere =>
      '''
    w.external_workout_id IS NOT NULL
    AND TRIM(w.external_workout_id) != ''
    AND DATE(w.started_at, 'localtime') >= '${WorkoutHistory.firstDayKey}'
  ''';

  static String get workoutsNeedingZoneComputeWhere =>
      '''
    $workoutsSinceFirstDayWhere
    AND (m.id IS NULL OR m.hr_sample_count IS NULL)
  ''';

  Future<void> persistFromHealthKitSeries({
    required CardioWorkout workout,
    required CardioWorkoutSeries series,
  }) async {
    final hrSamples = _timestamped(series.heartRateSamples);
    final fitnessSignals = workout.fitnessSignals(
      heartRateSamples: hrSamples,
      distanceSamples: series.distanceSamples,
    );
    final existingMetrics = await _powerSync.getOptional(
      'SELECT id FROM cardio_computed_metrics WHERE id = ?',
      [workout.id],
    );
    if (existingMetrics == null) return;
    final computedAt = DateTime.now().toUtc().toIso8601String();
    await _powerSync.upsert('cardio_computed_metrics', {
      'id': workout.id,
      'pace_seconds_per_mile': fitnessSignals.paceSecondsPerMile,
      'meters_per_heartbeat': fitnessSignals.metersPerHeartbeat,
      'cardiac_drift_percent': fitnessSignals.cardiacDriftPercent,
      'has_distance_samples': fitnessSignals.hasDistanceSamples ? 1 : 0,
      'distance_origin': fitnessSignals.distanceOrigin.dbKey,
      'fitness_confidence': fitnessSignals.confidence.dbKey,
      'computed_at': computedAt,
    });
  }

  /// Replaces stored zone time when [heartRateSamples] is at least as complete
  /// as the read already stored and the zone columns differ.
  Future<void> correctZoneTimeFromHeartRate({
    required String workoutId,
    required List<CardioHeartRateSample> heartRateSamples,
  }) async {
    final zoneColumns = _zoneColumns(_timestamped(heartRateSamples));
    final existingMetrics = await _powerSync.getOptional(
      '''
      SELECT zone1_seconds, zone2_seconds, zone3_seconds, zone4_seconds,
             zone5_seconds, has_hr_samples, hr_sample_count
      FROM cardio_computed_metrics WHERE id = ?
      ''',
      [workoutId],
    );
    final storedSampleCount = existingMetrics?['hr_sample_count'] as int?;
    if (storedSampleCount != null &&
        heartRateSamples.length < storedSampleCount) {
      return;
    }
    if (existingMetrics != null &&
        zoneColumns.entries.every(
          (column) => existingMetrics[column.key] == column.value,
        )) {
      return;
    }
    await persistZoneTimeFromHeartRate(
      workoutId: workoutId,
      heartRateSamples: heartRateSamples,
    );
  }

  /// Zone columns only, so a catalog pass does not clear pace or drift.
  Future<void> persistZoneTimeFromHeartRate({
    required String workoutId,
    required List<CardioHeartRateSample> heartRateSamples,
  }) async {
    final hrSamples = _timestamped(heartRateSamples);
    await _powerSync.upsert('cardio_computed_metrics', {
      'id': workoutId,
      ..._zoneColumns(hrSamples),
      'computed_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Stream<int> watchMissingCount() => _powerSync
      .watch('''
        SELECT COUNT(*) AS cnt FROM cardio_workouts w
        LEFT JOIN cardio_computed_metrics m ON m.id = w.id
        WHERE $workoutsNeedingZoneComputeWhere
      ''')
      .map((rows) => (rows.first['cnt'] as int?) ?? 0);

  List<TimestampedHeartRate> _timestamped(
    List<CardioHeartRateSample> heartRateSamples,
  ) => [
    for (final sample in heartRateSamples)
      TimestampedHeartRate(timestamp: sample.timestamp, bpm: sample.bpm),
  ];

  Map<String, Object?> _zoneColumns(List<TimestampedHeartRate> hrSamples) => {
    ..._zoneTime(hrSamples).toRow(),
    'has_hr_samples': hrSamples.isNotEmpty ? 1 : 0,
    'hr_sample_count': hrSamples.length,
  };

  HrZoneTime _zoneTime(List<TimestampedHeartRate> hrSamples) =>
      hrSamples.isEmpty ? HrZoneTime.zero : HrZoneTime.fromSamples(hrSamples);
}
