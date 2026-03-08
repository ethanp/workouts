import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/fitness_run.dart';
import 'package:workouts/models/run_calendar_day.dart';
import 'package:workouts/models/run_heart_rate_sample.dart';
import 'package:workouts/models/run_route_point.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/repositories/run_import.dart';
import 'package:workouts/services/repositories/run_metrics_store.dart';
import 'package:workouts/utils/training_load_calculator.dart';

part 'runs_repository_powersync.g.dart';

final _log = Logger('RunsRepository');

class RunsRepositoryPowerSync {
  RunsRepositoryPowerSync(this._powerSync);

  final PowerSyncDatabase _powerSync;
  late final RunMetricsStore _metricsStore = RunMetricsStore(_powerSync);
  late final RunImporter _importer = RunImporter(_powerSync, _metricsStore);

  Stream<List<FitnessRun>> watchRuns() => _powerSync
      .watch('SELECT * FROM runs ORDER BY started_at DESC')
      .map((runRows) => runRows.map(_runFromRow).toList());

  Stream<List<RunRoutePoint>> watchRoutePoints(String runId) => _powerSync
      .watch(
        'SELECT * FROM run_route_points WHERE run_id = ? ORDER BY point_index ASC',
        parameters: [runId],
      )
      .map((pointRows) => pointRows.map(_routePointFromRow).toList());

  Stream<List<RunHeartRateSample>> watchHeartRateSamples(String runId) =>
      _powerSync
          .watch(
            'SELECT * FROM run_heart_rate_samples WHERE run_id = ? ORDER BY timestamp ASC',
            parameters: [runId],
          )
          .map(
            (sampleRows) => sampleRows.map(_heartRateSampleFromRow).toList(),
          );

  Stream<List<RunCalendarDay>> watchCalendarDays() => _powerSync
      .watch(
        '''
        SELECT
          DATE(r.started_at, 'localtime') AS day,
          SUM(r.distance_meters)            AS total_distance_meters,
          SUM(r.duration_seconds)           AS total_duration_seconds,
          COALESCE(SUM(m.zone2_seconds), 0) AS total_zone2_seconds,
          COALESCE(SUM(m.trimp), 0.0)       AS total_trimp,
          MAX(COALESCE(m.has_hr_samples, 0)) AS has_hr_data,
          COUNT(r.id)                       AS run_count
        FROM runs r
        LEFT JOIN run_computed_metrics m ON m.id = r.id
        GROUP BY day
        ORDER BY day ASC
        ''',
        triggerOnTables: const {'runs', 'run_computed_metrics'},
      )
      .map((dayRows) => dayRows.map(_calendarDayFromRow).toList());

  Future<List<FitnessRun>> getRunsForDate(DateTime localDate) async {
    final String dayString =
        '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
    final List<Map<String, dynamic>> runRows = await _powerSync.execute(
      "SELECT * FROM runs WHERE DATE(started_at, 'localtime') = ? ORDER BY started_at ASC",
      [dayString],
    );
    return runRows.map(_runFromRow).toList();
  }

  Future<void> deleteRun(String runId) async {
    await _powerSync.writeTransaction((transaction) async {
      await transaction.execute(
        'DELETE FROM run_route_points WHERE run_id = ?',
        [runId],
      );
      await transaction.execute(
        'DELETE FROM run_heart_rate_samples WHERE run_id = ?',
        [runId],
      );
      await transaction.execute(
        'DELETE FROM run_computed_metrics WHERE id = ?',
        [runId],
      );
      await transaction.execute('DELETE FROM runs WHERE id = ?', [runId]);
    });
    _log.info('Deleted run $runId (queued for upload).');
  }

  /// Returns the number of newly inserted runs (skipped ones not counted).
  Future<int> upsertImportedRuns(
    List<Map<String, dynamic>> payloads, {
    void Function(int done, int total)? onProgress,
    required TrainingLoadCalculator trainingLoad,
  }) => _importer.upsertAll(
    payloads,
    onProgress: onProgress,
    trainingLoad: trainingLoad,
  );

  /// Recomputes zone2 for all runs (triggered by max HR change).
  /// Preserves existing TRIMP values computed with their original resting HR.
  Future<void> recomputeZone2({
    required TrainingLoadCalculator trainingLoad,
    void Function(int done, int total)? onProgress,
  }) => _metricsStore.recomputeAllZone2(
    trainingLoad: trainingLoad,
    onProgress: onProgress,
  );

  /// Backfills metrics for runs missing a `run_computed_metrics` row,
  /// or whose row has no HR lower bound (HR samples arrived late).
  Future<void> backfillMissingMetrics({
    required TrainingLoadCalculator trainingLoad,
  }) => _metricsStore.backfillMissing(trainingLoad: trainingLoad);

  RunCalendarDay _calendarDayFromRow(Map<String, dynamic> dayRow) {
    final String dayString = dayRow['day'] as String;
    final List<String> parts = dayString.split('-');
    return RunCalendarDay(
      date: DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
      totalDistanceMeters: _asDouble(dayRow['total_distance_meters']) ?? 0,
      totalDurationSeconds: (dayRow['total_duration_seconds'] as int?) ?? 0,
      zone2Minutes: ((dayRow['total_zone2_seconds'] as int? ?? 0) ~/ 60),
      trimp: _asDouble(dayRow['total_trimp']) ?? 0,
      hasHrData: (dayRow['has_hr_data'] as int? ?? 0) == 1,
      runCount: (dayRow['run_count'] as int?) ?? 0,
    );
  }

  FitnessRun _runFromRow(Map<String, dynamic> runRow) => FitnessRun(
    id: runRow['id'] as String,
    externalWorkoutId: runRow['external_workout_id'] as String,
    startedAt: DateTime.parse(runRow['started_at'] as String),
    endedAt: DateTime.parse(runRow['ended_at'] as String),
    durationSeconds: (runRow['duration_seconds'] as int?) ?? 0,
    distanceMeters: _asDouble(runRow['distance_meters']) ?? 0,
    energyKcal: _asDouble(runRow['energy_kcal']),
    averageHeartRateBpm: _asDouble(runRow['avg_heart_rate_bpm']),
    maxHeartRateBpm: _asDouble(runRow['max_heart_rate_bpm']),
    isIndoor: (runRow['is_indoor'] as int?) == 1,
    routeAvailable: (runRow['route_available'] as int?) == 1,
    sourceName: (runRow['source_name'] as String?) ?? 'Apple Health',
    sourceBundleId: runRow['source_bundle_id'] as String?,
    deviceModel: runRow['device_model'] as String?,
    createdAt: _asDateTime(runRow['created_at']),
    updatedAt: _asDateTime(runRow['updated_at']),
  );

  RunRoutePoint _routePointFromRow(Map<String, dynamic> pointRow) =>
      RunRoutePoint(
        id: pointRow['id'] as String,
        runId: pointRow['run_id'] as String,
        pointIndex: (pointRow['point_index'] as int?) ?? 0,
        latitude: _asDouble(pointRow['lat']) ?? 0,
        longitude: _asDouble(pointRow['lng']) ?? 0,
        altitudeMeters: _asDouble(pointRow['altitude_meters']),
        recordedAt: _asDateTime(pointRow['timestamp']),
        createdAt: _asDateTime(pointRow['created_at']),
        updatedAt: _asDateTime(pointRow['updated_at']),
      );

  RunHeartRateSample _heartRateSampleFromRow(Map<String, dynamic> sampleRow) =>
      RunHeartRateSample(
        id: sampleRow['id'] as String,
        runId: sampleRow['run_id'] as String,
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
RunsRepositoryPowerSync runsRepositoryPowerSync(Ref ref) {
  final PowerSyncDatabase? powerSync =
      ref.watch(powerSyncDatabaseProvider).value;
  if (powerSync == null) throw StateError('PowerSync database not initialized');
  return RunsRepositoryPowerSync(powerSync);
}
