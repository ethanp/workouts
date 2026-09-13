import 'package:ethan_utils/ethan_utils.dart';

import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/cardio_best_effort.dart';
import 'package:workouts/models/cardio_calendar_day.dart';
import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/cardio_quantity_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/cardio_workout_event.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/repositories/best_effort_store.dart';
import 'package:workouts/services/repositories/cardio_import.dart';
import 'package:workouts/services/repositories/cardio_metrics_store.dart';
import 'package:workouts/utils/run_formatting.dart';

part 'cardio_repository_powersync.g.dart';

const _log = ELogger('CardioRepository');

class CardioRepositoryPowerSync(final PowerSyncDatabase _powerSync) {
  late final CardioMetricsStore _metricsStore = CardioMetricsStore(_powerSync);
  late final BestEffortStore _bestEffortStore = BestEffortStore(_powerSync);
  late final CardioImporter _importer = CardioImporter(
    _powerSync,
    _metricsStore,
    _bestEffortStore,
  );

  Stream<List<CardioWorkout>> watchCardioWorkouts() => _powerSync
      .watch(
        '''
        SELECT
          w.*,
          COALESCE(m.zone1_seconds, 0) AS zone1_seconds,
          COALESCE(m.zone2_seconds, 0) AS zone2_seconds,
          COALESCE(m.zone3_seconds, 0) AS zone3_seconds,
          COALESCE(m.zone4_seconds, 0) AS zone4_seconds,
          COALESCE(m.zone5_seconds, 0) AS zone5_seconds,
          COALESCE(m.has_hr_samples, 0) AS has_hr_samples,
          m.pace_seconds_per_mile,
          m.meters_per_heartbeat,
          m.cardiac_drift_percent,
          COALESCE(m.has_distance_samples, 0) AS has_distance_samples,
          m.distance_origin,
          m.fitness_confidence
        FROM cardio_workouts w
        LEFT JOIN cardio_computed_metrics m ON m.id = w.id
        ORDER BY w.started_at DESC
        ''',
        triggerOnTables: const {'cardio_workouts', 'cardio_computed_metrics'},
      )
      .map((workoutRows) => workoutRows.mapL(CardioWorkout.fromRow));

  Stream<List<CardioRoutePoint>> watchRoutePoints(String workoutId) =>
      _powerSync
          .watch(
            'SELECT * FROM cardio_route_points WHERE workout_id = ? ORDER BY point_index ASC',
            parameters: [workoutId],
          )
          .map((pointRows) => pointRows.mapL(CardioRoutePoint.fromRow));

  Stream<List<CardioHeartRateSample>> watchHeartRateSamples(String workoutId) =>
      _powerSync
          .watch(
            'SELECT * FROM cardio_heart_rate_samples WHERE workout_id = ? ORDER BY timestamp ASC',
            parameters: [workoutId],
          )
          .map((sampleRows) => sampleRows.mapL(CardioHeartRateSample.fromRow));

  Stream<List<CardioQuantitySample>> watchDistanceSamples(String workoutId) =>
      _powerSync
          .watch(
            'SELECT * FROM cardio_distance_samples WHERE workout_id = ? ORDER BY started_at ASC',
            parameters: [workoutId],
          )
          .map((sampleRows) => sampleRows.mapL(CardioQuantitySample.fromRow));

  Stream<List<CardioWorkoutEvent>> watchWorkoutEvents(String workoutId) =>
      _powerSync
          .watch(
            'SELECT * FROM cardio_workout_events WHERE workout_id = ? ORDER BY occurred_at ASC',
            parameters: [workoutId],
          )
          .map((eventRows) => eventRows.mapL(CardioWorkoutEvent.fromRow));

  Stream<List<CardioBestEffort>> watchBestEfforts() => _powerSync
      .watch(
        '''
        SELECT be.distance_meters, be.elapsed_seconds, w.started_at, w.activity_type
        FROM cardio_best_efforts be
        JOIN cardio_workouts w ON w.id = be.workout_id
        ORDER BY w.started_at ASC
        ''',
        triggerOnTables: const {'cardio_best_efforts', 'cardio_workouts'},
      )
      .map((rows) {
        final bestEfforts = <CardioBestEffort>[];
        for (final row in rows) {
          final distanceMeters = (row['distance_meters'] as num).toDouble();
          if (DistanceBucket.fromMeters(distanceMeters) != null) {
            bestEfforts.add(CardioBestEffort.fromRow(row));
          }
        }
        return bestEfforts;
      });

  Stream<List<CardioCalendarDay>> watchCalendarDays() => _powerSync
      .watch(
        '''
        SELECT
          DATE(w.started_at, 'localtime') AS day,
          COALESCE(SUM(CASE WHEN w.activity_type = 'outdoorRun' THEN w.distance_meters END), 0) AS outdoor_run_distance_meters,
          SUM(w.duration_seconds)           AS total_duration_seconds,
          COALESCE(SUM(m.zone1_seconds), 0) AS total_zone1_seconds,
          COALESCE(SUM(m.zone2_seconds), 0) AS total_zone2_seconds,
          COALESCE(SUM(m.zone3_seconds), 0) AS total_zone3_seconds,
          COALESCE(SUM(m.zone4_seconds), 0) AS total_zone4_seconds,
          COALESCE(SUM(m.zone5_seconds), 0) AS total_zone5_seconds,
          MAX(COALESCE(m.has_hr_samples, 0)) AS has_hr_data,
          COUNT(w.id)                       AS workout_count
        FROM cardio_workouts w
        LEFT JOIN cardio_computed_metrics m ON m.id = w.id
        GROUP BY day
        ORDER BY day ASC
        ''',
        triggerOnTables: const {'cardio_workouts', 'cardio_computed_metrics'},
      )
      .map((dayRows) => dayRows.mapL(CardioCalendarDay.fromRow));

  Future<List<CardioWorkout>> getWorkoutsForDate(DateTime localDate) async {
    final String dayString =
        '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
    final List<Map<String, dynamic>> workoutRows = await _powerSync.execute(
      '''
      SELECT
        w.*,
        COALESCE(m.zone1_seconds, 0) AS zone1_seconds,
        COALESCE(m.zone2_seconds, 0) AS zone2_seconds,
        COALESCE(m.zone3_seconds, 0) AS zone3_seconds,
        COALESCE(m.zone4_seconds, 0) AS zone4_seconds,
        COALESCE(m.zone5_seconds, 0) AS zone5_seconds,
        COALESCE(m.has_hr_samples, 0) AS has_hr_samples,
        m.pace_seconds_per_mile,
        m.meters_per_heartbeat,
        m.cardiac_drift_percent,
        COALESCE(m.has_distance_samples, 0) AS has_distance_samples,
        m.distance_origin,
        m.fitness_confidence
      FROM cardio_workouts w
      LEFT JOIN cardio_computed_metrics m ON m.id = w.id
      WHERE DATE(w.started_at, 'localtime') = ?
      ORDER BY w.started_at ASC
      ''',
      [dayString],
    );
    return workoutRows.mapL(CardioWorkout.fromRow);
  }

  Future<void> deleteWorkout(String workoutId) async {
    await _powerSync.writeTransaction((transaction) async {
      await transaction.execute(
        'DELETE FROM cardio_route_points WHERE workout_id = ?',
        [workoutId],
      );
      await transaction.execute(
        'DELETE FROM cardio_heart_rate_samples WHERE workout_id = ?',
        [workoutId],
      );
      await transaction.execute(
        'DELETE FROM cardio_best_efforts WHERE workout_id = ?',
        [workoutId],
      );
      await transaction.execute(
        'DELETE FROM cardio_distance_samples WHERE workout_id = ?',
        [workoutId],
      );
      await transaction.execute(
        'DELETE FROM cardio_step_samples WHERE workout_id = ?',
        [workoutId],
      );
      await transaction.execute(
        'DELETE FROM cardio_workout_events WHERE workout_id = ?',
        [workoutId],
      );
      await transaction.execute(
        'DELETE FROM cardio_computed_metrics WHERE id = ?',
        [workoutId],
      );
      await transaction.execute('DELETE FROM cardio_workouts WHERE id = ?', [
        workoutId,
      ]);
    });
    _log.log('Deleted workout $workoutId (queued for upload).');
  }

  Future<void> wipeImportedCardio() => _importer.wipeStoredCardio();

  Future<bool> insertImportedWorkout(Map<String, dynamic> payload) =>
      _importer.insertRawWorkout(payload);

  Future<int> replaceImportedWorkouts(
    List<Map<String, dynamic>> payloads, {
    void Function(int done, int total)? onProgress,
  }) => _importer.replaceAll(payloads, onProgress: onProgress);

  Future<void> recomputeZones({
    void Function(int done, int total)? onProgress,
  }) => _metricsStore.recomputeAllZones(onProgress: onProgress);

  Future<void> backfillMissingMetrics() => _metricsStore.backfillMissing();

  Stream<int> watchWorkoutsMissingMetricsCount() =>
      _metricsStore.watchMissingCount();

  Future<void> backfillMissingBestEfforts({
    void Function(int done, int total)? onProgress,
  }) => _bestEffortStore.backfillAll(onProgress: onProgress);
}

@riverpod
CardioRepositoryPowerSync cardioRepositoryPowerSync(Ref ref) {
  final PowerSyncDatabase? powerSync = ref
      .watch(powerSyncDatabaseProvider)
      .value;
  if (powerSync == null) {
    throw StateError('PowerSync database not initialized');
  }
  return CardioRepositoryPowerSync(powerSync);
}
