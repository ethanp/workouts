import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/cardio_import_payload.dart';
import 'package:workouts/services/repositories/best_effort_store.dart';
import 'package:workouts/services/repositories/cardio_metrics_store.dart';

const _log = ELogger('CardioImporter');
const _uuid = Uuid();
final _workoutIdNamespace = Namespace.url.value;

const _cardioUploadTables = [
  'cardio_route_points',
  'cardio_heart_rate_samples',
  'cardio_best_efforts',
  'cardio_distance_samples',
  'cardio_step_samples',
  'cardio_workout_events',
  'cardio_workouts',
];

/// Orchestrates importing HealthKit cardio workouts into the local database.
class CardioImporter(
  final PowerSyncDatabase _powerSync,
  final CardioMetricsStore _metricsStore,
  final BestEffortStore _bestEffortStore,
) {
  Future<void> wipeStoredCardio() async {
    await _wipeLocalCardio();
    await _purgeCardioUploads();
  }

  Future<bool> insertRawWorkout(Map<String, dynamic> payload) async {
    final CardioImportPayload? workout = CardioImportPayload.tryParse(payload);
    if (workout == null) {
      _log.warn('Skipping unparseable Apple Health workout.');
      return false;
    }
    await _insert(workout);
    return true;
  }

  Future<int> replaceAll(
    List<Map<String, dynamic>> payloads, {
    void Function(int done, int total)? onProgress,
  }) async {
    _log.log('Replacing cardio with ${payloads.length} Apple Health workouts.');
    await wipeStoredCardio();
    var inserted = 0;
    Object? firstImportError;
    StackTrace? firstImportStack;
    for (var payloadIndex = 0; payloadIndex < payloads.length; payloadIndex++) {
      final CardioImportPayload? workout = CardioImportPayload.tryParse(
        payloads[payloadIndex],
      );
      if (workout != null) {
        try {
          await _insert(workout);
          inserted++;
        } catch (error, stackTrace) {
          _log.error(
            'Failed to import workout ${workout.externalWorkoutId}.',
            error,
            stackTrace,
          );
          firstImportError ??= error;
          firstImportStack ??= stackTrace;
        }
      } else {
        _log.warn(
          'Skipping unparseable workout payload at index $payloadIndex.',
        );
      }
      onProgress?.call(payloadIndex + 1, payloads.length);
    }
    _log.log('Import complete: $inserted workouts written.');
    if (firstImportError != null) {
      Error.throwWithStackTrace(firstImportError, firstImportStack!);
    }
    return inserted;
  }

  Future<void> _wipeLocalCardio() async {
    await _powerSync.writeTransaction((transaction) async {
      for (final table in _cardioUploadTables) {
        if (table == 'cardio_workouts') continue;
        await transaction.execute('DELETE FROM $table');
      }
      await transaction.execute('DELETE FROM cardio_computed_metrics');
      await transaction.execute('DELETE FROM cardio_workouts');
    });
  }

  Future<void> _purgeCardioUploads() async {
    final tableList = _cardioUploadTables.map((table) => "'$table'").join(', ');
    await _powerSync.execute(
      "DELETE FROM ps_crud WHERE json_extract(data, '\$.type') IN ($tableList)",
    );
  }

  Future<void> _insert(CardioImportPayload workout) async {
    final String workoutId = await _resolveWorkoutId(workout.externalWorkoutId);
    final String now = DateTime.now().toIso8601String();
    _log.fine(
      'Inserting workout ${workout.externalWorkoutId} '
      '(${workout.routePoints.length} pts, ${workout.heartRateSamples.length} HR samples)',
    );
    await _saveWorkout(workoutId, workout, createdAt: now, updatedAt: now);
    await _saveHeartRateSamples(workoutId, workout.heartRateSamples, now: now);
    await _saveQuantitySamples(
      table: 'cardio_distance_samples',
      workoutId: workoutId,
      samples: workout.distanceSamples,
      now: now,
    );
    await _saveQuantitySamples(
      table: 'cardio_step_samples',
      workoutId: workoutId,
      samples: workout.stepSamples,
      now: now,
    );
    await _saveEvents(workoutId, workout.events, now: now);
    await _metricsStore.computeAndStore(workoutId);
    await _saveRoutePoints(workoutId, workout.routePoints, now: now);
    await _bestEffortStore.computeAndStore(workoutId);
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
      device_model, device_name, elevation_ascended_meters, recovery_bpm,
      effort_score, estimated_effort_score, machine_linked, average_mets,
      fitness_machine_duration_seconds, cross_trainer_distance_meters,
      indoor_bike_distance_meters, basal_energy_kcal, step_count,
      flights_climbed, min_heart_rate_bpm, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    _workoutValues(workoutId, workout, createdAt: createdAt, updatedAt: updatedAt),
  );

  List<Object?> _workoutValues(
    String workoutId,
    CardioImportPayload workout, {
    required String createdAt,
    required String updatedAt,
  }) => [
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
    workout.deviceName,
    workout.elevationAscendedMeters,
    workout.recoveryBpm,
    workout.effortScore,
    workout.estimatedEffortScore,
    workout.machineLinked ? 1 : 0,
    workout.averageMets,
    workout.fitnessMachineDurationSeconds,
    workout.crossTrainerDistanceMeters,
    workout.indoorBikeDistanceMeters,
    workout.basalEnergyKcal,
    workout.stepCount,
    workout.flightsClimbed,
    workout.minHeartRateBpm,
    createdAt,
    updatedAt,
  ];

  Future<void> _saveRoutePoints(
    String workoutId,
    List<RoutePointPayload> points, {
    required String now,
  }) async {
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

  Future<void> _saveQuantitySamples({
    required String table,
    required String workoutId,
    required List<QuantitySamplePayload> samples,
    required String now,
  }) async {
    if (samples.isEmpty) return;
    _log.fine('Inserting ${samples.length} $table rows for $workoutId.');
    await _powerSync.writeTransaction((transaction) async {
      for (final QuantitySamplePayload sample in samples) {
        await transaction.execute(
          'INSERT INTO $table'
          '  (id, workout_id, started_at, ended_at, value, created_at, updated_at)'
          ' VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            _uuid.v4(),
            workoutId,
            sample.startedAt,
            sample.endedAt,
            sample.value,
            now,
            now,
          ],
        );
      }
    });
  }

  Future<void> _saveEvents(
    String workoutId,
    List<WorkoutEventPayload> events, {
    required String now,
  }) async {
    if (events.isEmpty) return;
    await _powerSync.writeTransaction((transaction) async {
      for (final WorkoutEventPayload event in events) {
        await transaction.execute(
          'INSERT INTO cardio_workout_events'
          '  (id, workout_id, event_type, occurred_at, ended_at, created_at, updated_at)'
          ' VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            _uuid.v4(),
            workoutId,
            event.eventType,
            event.occurredAt,
            event.endedAt,
            now,
            now,
          ],
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
      await _powerSync.execute('DELETE FROM cardio_workouts WHERE id = ?', [
        staleRow['id'],
      ]);
    }
    return deterministicId;
  }
}
