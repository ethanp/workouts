import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/cardio_best_effort.dart';
import 'package:workouts/models/cardio_calendar_day.dart';
import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/repositories/best_effort_store.dart';
import 'package:workouts/services/repositories/cardio_import.dart';
import 'package:workouts/services/repositories/cardio_metrics_store.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/utils/training_load_calculator.dart';

part 'cardio_repository_powersync.g.dart';

final _log = Logger('CardioRepository');

class CardioRepositoryPowerSync {
  CardioRepositoryPowerSync(this._powerSync);

  final PowerSyncDatabase _powerSync;
  late final CardioMetricsStore _metricsStore =
      CardioMetricsStore(_powerSync);
  late final BestEffortStore _bestEffortStore =
      BestEffortStore(_powerSync);
  late final CardioImporter _importer =
      CardioImporter(_powerSync, _metricsStore, _bestEffortStore);

  Stream<List<CardioWorkout>> watchCardioWorkouts() => _powerSync
      .watch('SELECT * FROM cardio_workouts ORDER BY started_at DESC')
      .map((workoutRows) => workoutRows.map(_workoutFromRow).toList());

  Stream<List<CardioRoutePoint>> watchRoutePoints(String workoutId) =>
      _powerSync
          .watch(
            'SELECT * FROM cardio_route_points WHERE workout_id = ? ORDER BY point_index ASC',
            parameters: [workoutId],
          )
          .map((pointRows) => pointRows.map(_routePointFromRow).toList());

  Stream<List<CardioHeartRateSample>> watchHeartRateSamples(
          String workoutId) =>
      _powerSync
          .watch(
            'SELECT * FROM cardio_heart_rate_samples WHERE workout_id = ? ORDER BY timestamp ASC',
            parameters: [workoutId],
          )
          .map(
            (sampleRows) =>
                sampleRows.map(_heartRateSampleFromRow).toList(),
          );

  Stream<List<CardioBestEffort>> watchBestEfforts() => _powerSync
      .watch(
        '''
        SELECT be.distance_meters, be.elapsed_seconds, w.started_at
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
          SUM(w.distance_meters)            AS total_distance_meters,
          SUM(w.duration_seconds)           AS total_duration_seconds,
          COALESCE(SUM(m.zone1_seconds), 0) AS total_zone1_seconds,
          COALESCE(SUM(m.zone2_seconds), 0) AS total_zone2_seconds,
          COALESCE(SUM(m.zone3_seconds), 0) AS total_zone3_seconds,
          COALESCE(SUM(m.zone4_seconds), 0) AS total_zone4_seconds,
          COALESCE(SUM(m.zone5_seconds), 0) AS total_zone5_seconds,
          COALESCE(SUM(m.trimp), 0.0)       AS total_trimp,
          MAX(COALESCE(m.has_hr_samples, 0)) AS has_hr_data,
          COUNT(w.id)                       AS workout_count
        FROM cardio_workouts w
        LEFT JOIN cardio_computed_metrics m ON m.id = w.id
        GROUP BY day
        ORDER BY day ASC
        ''',
        triggerOnTables: const {'cardio_workouts', 'cardio_computed_metrics'},
      )
      .map((dayRows) => dayRows.map(_calendarDayFromRow).toList());

  Future<List<CardioWorkout>> getWorkoutsForDate(
      DateTime localDate) async {
    final String dayString =
        '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
    final List<Map<String, dynamic>> workoutRows = await _powerSync.execute(
      "SELECT * FROM cardio_workouts WHERE DATE(started_at, 'localtime') = ? ORDER BY started_at ASC",
      [dayString],
    );
    return workoutRows.map(_workoutFromRow).toList();
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
        'DELETE FROM cardio_computed_metrics WHERE id = ?',
        [workoutId],
      );
      await transaction.execute(
          'DELETE FROM cardio_workouts WHERE id = ?', [workoutId]);
    });
    _log.info('Deleted workout $workoutId (queued for upload).');
  }

  Future<int> upsertImportedWorkouts(
    List<Map<String, dynamic>> payloads, {
    void Function(int done, int total)? onProgress,
    required TrainingLoadCalculator trainingLoad,
  }) => _importer.upsertAll(
    payloads,
    onProgress: onProgress,
    trainingLoad: trainingLoad,
  );

  Future<void> recomputeZones({
    required TrainingLoadCalculator trainingLoad,
    void Function(int done, int total)? onProgress,
  }) => _metricsStore.recomputeAllZones(
    trainingLoad: trainingLoad,
    onProgress: onProgress,
  );

  Future<void> backfillMissingMetrics({
    required TrainingLoadCalculator trainingLoad,
  }) => _metricsStore.backfillMissing(trainingLoad: trainingLoad);

  Future<void> backfillMissingBestEfforts({
    void Function(int done, int total)? onProgress,
  }) => _bestEffortStore.backfillAll(onProgress: onProgress);

  CardioCalendarDay _calendarDayFromRow(Map<String, dynamic> dayRow) {
    final String dayString = dayRow['day'] as String;
    final List<String> parts = dayString.split('-');
    return CardioCalendarDay(
      date: DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
      totalDistanceMeters: _asDouble(dayRow['total_distance_meters']) ?? 0,
      totalDurationSeconds:
          (dayRow['total_duration_seconds'] as int?) ?? 0,
      zoneTime: HrZoneTime.fromRow(dayRow),
      trimp: _asDouble(dayRow['total_trimp']) ?? 0,
      hasHrData: (dayRow['has_hr_data'] as int? ?? 0) == 1,
      workoutCount: (dayRow['workout_count'] as int?) ?? 0,
    );
  }

  CardioWorkout _workoutFromRow(Map<String, dynamic> workoutRow) =>
      CardioWorkout(
        id: workoutRow['id'] as String,
        externalWorkoutId:
            workoutRow['external_workout_id'] as String,
        activityType: CardioType.fromDbKey(
            (workoutRow['activity_type'] as String?) ?? 'outdoorRun'),
        startedAt: DateTime.parse(workoutRow['started_at'] as String),
        endedAt: DateTime.parse(workoutRow['ended_at'] as String),
        durationSeconds:
            (workoutRow['duration_seconds'] as int?) ?? 0,
        distanceMeters:
            _asDouble(workoutRow['distance_meters']) ?? 0,
        energyKcal: _asDouble(workoutRow['energy_kcal']),
        averageHeartRateBpm:
            _asDouble(workoutRow['avg_heart_rate_bpm']),
        maxHeartRateBpm:
            _asDouble(workoutRow['max_heart_rate_bpm']),
        routeAvailable:
            (workoutRow['route_available'] as int?) == 1,
        sourceName: (workoutRow['source_name'] as String?) ??
            'Apple Health',
        sourceBundleId:
            workoutRow['source_bundle_id'] as String?,
        deviceModel: workoutRow['device_model'] as String?,
        createdAt: _asDateTime(workoutRow['created_at']),
        updatedAt: _asDateTime(workoutRow['updated_at']),
      );

  CardioRoutePoint _routePointFromRow(Map<String, dynamic> pointRow) =>
      CardioRoutePoint(
        id: pointRow['id'] as String,
        workoutId: pointRow['workout_id'] as String,
        pointIndex: (pointRow['point_index'] as int?) ?? 0,
        latitude: _asDouble(pointRow['lat']) ?? 0,
        longitude: _asDouble(pointRow['lng']) ?? 0,
        altitudeMeters: _asDouble(pointRow['altitude_meters']),
        recordedAt: _asDateTime(pointRow['timestamp']),
        createdAt: _asDateTime(pointRow['created_at']),
        updatedAt: _asDateTime(pointRow['updated_at']),
      );

  CardioHeartRateSample _heartRateSampleFromRow(
          Map<String, dynamic> sampleRow) =>
      CardioHeartRateSample(
        id: sampleRow['id'] as String,
        workoutId: sampleRow['workout_id'] as String,
        timestamp: DateTime.parse(sampleRow['timestamp'] as String),
        bpm: (sampleRow['bpm'] as int?) ?? 0,
        createdAt: _asDateTime(sampleRow['created_at']),
        updatedAt: _asDateTime(sampleRow['updated_at']),
      );
}

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

DateTime? _asDateTime(Object? value) {
  final String? string = value as String?;
  return string == null ? null : DateTime.tryParse(string);
}

@riverpod
CardioRepositoryPowerSync cardioRepositoryPowerSync(Ref ref) {
  final PowerSyncDatabase? powerSync =
      ref.watch(powerSyncDatabaseProvider).value;
  if (powerSync == null) {
    throw StateError('PowerSync database not initialized');
  }
  return CardioRepositoryPowerSync(powerSync);
}
