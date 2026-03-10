import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/cardio_import_payload.dart';
import 'package:workouts/services/repositories/best_effort_store.dart';
import 'package:workouts/services/repositories/cardio_metrics_store.dart';
import 'package:workouts/utils/training_load_calculator.dart';

final _log = Logger('CardioImporter');
const _uuid = Uuid();
final _workoutIdNamespace = Namespace.url.value;

/// Orchestrates importing HealthKit cardio workouts into the local database.
class CardioImporter {
  CardioImporter(this._powerSync, this._metricsStore, this._bestEffortStore);

  final PowerSyncDatabase _powerSync;
  final CardioMetricsStore _metricsStore;
  final BestEffortStore _bestEffortStore;

  Future<int> upsertAll(
    List<Map<String, dynamic>> payloads, {
    void Function(int done, int total)? onProgress,
    required TrainingLoadCalculator trainingLoad,
  }) async {
    _log.info('Starting import of ${payloads.length} cardio workouts.');
    var inserted = 0;
    for (var payloadIndex = 0;
        payloadIndex < payloads.length;
        payloadIndex++) {
      final CardioImportPayload? workout =
          CardioImportPayload.tryParse(payloads[payloadIndex]);
      if (workout != null) {
        final bool wasNew =
            await _upsert(workout, trainingLoad: trainingLoad);
        if (wasNew) inserted++;
      } else {
        _log.warning(
          'Skipping unparseable workout payload at index $payloadIndex.',
        );
      }
      onProgress?.call(payloadIndex + 1, payloads.length);
    }
    _log.info(
      'Import complete: $inserted new, ${payloads.length - inserted} already stored.',
    );
    return inserted;
  }

  Future<bool> _upsert(
    CardioImportPayload workout, {
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final String workoutId =
        await _resolveWorkoutId(workout.externalWorkoutId);
    if (await _existingCreatedAt(workoutId) != null) {
      _log.fine(
          'Skipping workout ${workout.externalWorkoutId} (already stored).');
      return false;
    }
    _log.fine(
      'Inserting workout ${workout.externalWorkoutId} '
      '(${workout.routePoints.length} pts, ${workout.heartRateSamples.length} HR samples)',
    );
    final String now = DateTime.now().toIso8601String();
    await _saveWorkout(workoutId, workout, createdAt: now, updatedAt: now);
    await _saveRoutePoints(workoutId, workout.routePoints, now: now);
    await _saveHeartRateSamples(workoutId, workout.heartRateSamples, now: now);
    await _metricsStore.computeAndStore(
        workoutId, trainingLoad: trainingLoad);
    await _bestEffortStore.computeAndStore(workoutId);
    return true;
  }

  Future<void> _saveWorkout(
    String workoutId,
    CardioImportPayload workout, {
    required String createdAt,
    required String updatedAt,
  }) => _powerSync.execute(
    '''
    INSERT INTO cardio_workouts (
      id, external_workout_id, activity_type, started_at, ended_at,
      duration_seconds, distance_meters, energy_kcal, avg_heart_rate_bpm,
      max_heart_rate_bpm, route_available, source_name, source_bundle_id,
      device_model, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      workoutId,
      workout.externalWorkoutId,
      workout.activityType.dbKey,
      workout.startedAt,
      workout.endedAt,
      workout.durationSeconds,
      workout.distanceMeters,
      workout.energyKcal,
      workout.avgHeartRateBpm,
      workout.maxHeartRateBpm,
      workout.routeAvailable ? 1 : 0,
      workout.sourceName,
      workout.sourceBundleId,
      workout.deviceModel,
      createdAt,
      updatedAt,
    ],
  );

  Future<void> _saveRoutePoints(
    String workoutId,
    List<RoutePointPayload> points, {
    required String now,
  }) async {
    final Map<String, dynamic>? countRow = await _powerSync.getOptional(
      'SELECT COUNT(*) AS cnt FROM cardio_route_points WHERE workout_id = ?',
      [workoutId],
    );
    if ((countRow?['cnt'] as int? ?? 0) > 0) {
      _log.fine('Route points already exist for $workoutId — skipping.');
      return;
    }
    if (points.isEmpty) return;

    _log.fine('Inserting ${points.length} route points for $workoutId.');
    await _powerSync.writeTransaction((transaction) async {
      for (var pointIndex = 0; pointIndex < points.length; pointIndex++) {
        final RoutePointPayload point = points[pointIndex];
        await transaction.execute(
          'INSERT INTO cardio_route_points'
          '  (id, workout_id, point_index, lat, lng, altitude_meters, timestamp, created_at, updated_at)'
          ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            _uuid.v4(),
            workoutId,
            pointIndex,
            point.lat,
            point.lng,
            point.altitudeMeters,
            point.timestamp,
            now,
            now,
          ],
        );
      }
    });
  }

  Future<void> _saveHeartRateSamples(
    String workoutId,
    List<HeartRateSamplePayload> samples, {
    required String now,
  }) async {
    final Map<String, dynamic>? countRow = await _powerSync.getOptional(
      'SELECT COUNT(*) AS cnt FROM cardio_heart_rate_samples WHERE workout_id = ?',
      [workoutId],
    );
    if ((countRow?['cnt'] as int? ?? 0) > 0) {
      _log.fine('HR samples already exist for $workoutId — skipping.');
      return;
    }
    if (samples.isEmpty) return;

    _log.fine('Inserting ${samples.length} HR samples for $workoutId.');
    await _powerSync.writeTransaction((transaction) async {
      for (final HeartRateSamplePayload sample in samples) {
        await transaction.execute(
          'INSERT INTO cardio_heart_rate_samples'
          '  (id, workout_id, timestamp, bpm, created_at, updated_at)'
          ' VALUES (?, ?, ?, ?, ?, ?)',
          [_uuid.v4(), workoutId, sample.timestamp, sample.bpm, now, now],
        );
      }
    });
  }

  Future<String> _resolveWorkoutId(String externalWorkoutId) async {
    final String deterministicId = _uuid.v5(
      _workoutIdNamespace,
      'apple-health-cardio:$externalWorkoutId',
    );
    final List<Map<String, dynamic>> staleRows = await _powerSync.execute(
      'SELECT id FROM cardio_workouts WHERE external_workout_id = ? AND id != ?',
      [externalWorkoutId, deterministicId],
    );
    for (final staleRow in staleRows) {
      await _powerSync.execute(
        'DELETE FROM cardio_workouts WHERE id = ?',
        [staleRow['id']],
      );
    }
    return deterministicId;
  }

  Future<String?> _existingCreatedAt(String workoutId) async {
    final Map<String, dynamic>? workoutRow = await _powerSync.getOptional(
      'SELECT created_at FROM cardio_workouts WHERE id = ?',
      [workoutId],
    );
    return workoutRow?['created_at'] as String?;
  }
}
