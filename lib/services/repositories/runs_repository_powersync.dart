import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/fitness_run.dart';
import 'package:workouts/models/run_heart_rate_sample.dart';
import 'package:workouts/models/run_route_point.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';

part 'runs_repository_powersync.g.dart';

const _uuid = Uuid();
final _importedRunIdNamespace = Namespace.url.value;

class RunsRepositoryPowerSync {
  RunsRepositoryPowerSync(this._powerSyncDatabase);

  final PowerSyncDatabase _powerSyncDatabase;

  Stream<List<FitnessRun>> watchRuns() {
    return _powerSyncDatabase
        .watch('SELECT * FROM runs ORDER BY started_at DESC')
        .map((runRows) => runRows.map(_mapRunRow).toList());
  }

  Stream<List<RunRoutePoint>> watchRoutePoints(String runId) {
    return _powerSyncDatabase
        .watch(
          '''
          SELECT * FROM run_route_points
          WHERE run_id = ?
          ORDER BY point_index ASC
          ''',
          parameters: [runId],
        )
        .map((routePointRows) => routePointRows.map(_mapRoutePointRow).toList());
  }

  Stream<List<RunHeartRateSample>> watchHeartRateSamples(String runId) {
    return _powerSyncDatabase
        .watch(
          '''
          SELECT * FROM run_heart_rate_samples
          WHERE run_id = ?
          ORDER BY timestamp ASC
          ''',
          parameters: [runId],
        )
        .map(
          (heartRateRows) => heartRateRows.map(_mapHeartRateRow).toList(),
        );
  }

  Future<void> upsertImportedRuns(
    List<Map<String, dynamic>> importedRuns, {
    void Function(int processedRuns, int totalRuns)? onProgress,
  }) async {
    final totalRuns = importedRuns.length;
    var processedRuns = 0;
    for (final importedRunPayload in importedRuns) {
      await _upsertSingleRun(importedRunPayload);
      processedRuns += 1;
      onProgress?.call(processedRuns, totalRuns);
    }
  }

  Future<void> _upsertSingleRun(Map<String, dynamic> importedRunPayload) async {
    final externalWorkoutId = importedRunPayload['externalWorkoutId'] as String?;
    if (externalWorkoutId == null || externalWorkoutId.isEmpty) {
      return;
    }

    final existingRunRow = await _powerSyncDatabase.getOptional(
      'SELECT id, created_at FROM runs WHERE external_workout_id = ? LIMIT 1',
      [externalWorkoutId],
    );
    final runId =
        (existingRunRow?['id'] as String?) ??
        _uuid.v5(_importedRunIdNamespace, 'apple-health-run:$externalWorkoutId');
    final nowIsoString = DateTime.now().toIso8601String();

    await _powerSyncDatabase.execute(
      '''
      INSERT OR REPLACE INTO runs (
        id,
        external_workout_id,
        started_at,
        ended_at,
        duration_seconds,
        distance_meters,
        energy_kcal,
        avg_heart_rate_bpm,
        max_heart_rate_bpm,
        is_indoor,
        route_available,
        source_name,
        source_bundle_id,
        device_model,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        runId,
        externalWorkoutId,
        importedRunPayload['startDate'] as String,
        importedRunPayload['endDate'] as String,
        importedRunPayload['durationSeconds'] as int? ?? 0,
        _toDouble(importedRunPayload['distanceMeters']) ?? 0,
        _toDouble(importedRunPayload['energyKcal']),
        _toDouble(importedRunPayload['avgHeartRateBpm']),
        _toDouble(importedRunPayload['maxHeartRateBpm']),
        (importedRunPayload['isIndoor'] == true) ? 1 : 0,
        (importedRunPayload['routeAvailable'] == true) ? 1 : 0,
        (importedRunPayload['sourceName'] as String?) ?? 'Apple Health',
        importedRunPayload['sourceBundleId'] as String?,
        importedRunPayload['deviceModel'] as String?,
        (existingRunRow?['created_at'] as String?) ?? nowIsoString,
        nowIsoString,
      ],
    );

    await _replaceRoutePointsForRun(runId, importedRunPayload);
    await _replaceHeartRateSamplesForRun(runId, importedRunPayload);
  }

  Future<void> _replaceRoutePointsForRun(
    String runId,
    Map<String, dynamic> importedRunPayload,
  ) async {
    await _powerSyncDatabase.execute(
      'DELETE FROM run_route_points WHERE run_id = ?',
      [runId],
    );
    final routePointsDynamic = importedRunPayload['routePoints'] as List<dynamic>?;
    if (routePointsDynamic == null || routePointsDynamic.isEmpty) {
      return;
    }

    final nowIsoString = DateTime.now().toIso8601String();
    for (var pointIndex = 0; pointIndex < routePointsDynamic.length; pointIndex++) {
      final rawRoutePoint = routePointsDynamic[pointIndex];
      if (rawRoutePoint is! Map) {
        continue;
      }
      final routePointMap = Map<String, dynamic>.from(rawRoutePoint);
      final latitude = _toDouble(routePointMap['lat']);
      final longitude = _toDouble(routePointMap['lng']);
      if (latitude == null || longitude == null) {
        continue;
      }
      await _powerSyncDatabase.execute(
        '''
        INSERT INTO run_route_points (
          id, run_id, point_index, lat, lng, altitude_meters, timestamp, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          _uuid.v4(),
          runId,
          pointIndex,
          latitude,
          longitude,
          _toDouble(routePointMap['altitudeMeters']),
          routePointMap['timestamp'] as String?,
          nowIsoString,
          nowIsoString,
        ],
      );
    }
  }

  Future<void> _replaceHeartRateSamplesForRun(
    String runId,
    Map<String, dynamic> importedRunPayload,
  ) async {
    await _powerSyncDatabase.execute(
      'DELETE FROM run_heart_rate_samples WHERE run_id = ?',
      [runId],
    );
    final heartRateSeriesDynamic =
        importedRunPayload['heartRateSeries'] as List<dynamic>?;
    if (heartRateSeriesDynamic == null || heartRateSeriesDynamic.isEmpty) {
      return;
    }

    final nowIsoString = DateTime.now().toIso8601String();
    for (final rawHeartRatePoint in heartRateSeriesDynamic) {
      if (rawHeartRatePoint is! Map) {
        continue;
      }
      final heartRatePointMap = Map<String, dynamic>.from(rawHeartRatePoint);
      final timestampIsoString = heartRatePointMap['timestamp'] as String?;
      final bpmValue = _toDouble(heartRatePointMap['bpm'])?.round();
      if (timestampIsoString == null || bpmValue == null) {
        continue;
      }
      await _powerSyncDatabase.execute(
        '''
        INSERT INTO run_heart_rate_samples (
          id, run_id, timestamp, bpm, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [_uuid.v4(), runId, timestampIsoString, bpmValue, nowIsoString, nowIsoString],
      );
    }
  }

  FitnessRun _mapRunRow(Map<String, dynamic> runRow) {
    return FitnessRun(
      id: runRow['id'] as String,
      externalWorkoutId: runRow['external_workout_id'] as String,
      startedAt: DateTime.parse(runRow['started_at'] as String),
      endedAt: DateTime.parse(runRow['ended_at'] as String),
      durationSeconds: (runRow['duration_seconds'] as int?) ?? 0,
      distanceMeters: _toDouble(runRow['distance_meters']) ?? 0,
      energyKcal: _toDouble(runRow['energy_kcal']),
      averageHeartRateBpm: _toDouble(runRow['avg_heart_rate_bpm']),
      maxHeartRateBpm: _toDouble(runRow['max_heart_rate_bpm']),
      isIndoor: (runRow['is_indoor'] as int?) == 1,
      routeAvailable: (runRow['route_available'] as int?) == 1,
      sourceName: (runRow['source_name'] as String?) ?? 'Apple Health',
      sourceBundleId: runRow['source_bundle_id'] as String?,
      deviceModel: runRow['device_model'] as String?,
      createdAt: _tryParseDateTime(runRow['created_at']),
      updatedAt: _tryParseDateTime(runRow['updated_at']),
    );
  }

  RunRoutePoint _mapRoutePointRow(Map<String, dynamic> routePointRow) {
    return RunRoutePoint(
      id: routePointRow['id'] as String,
      runId: routePointRow['run_id'] as String,
      pointIndex: (routePointRow['point_index'] as int?) ?? 0,
      latitude: _toDouble(routePointRow['lat']) ?? 0,
      longitude: _toDouble(routePointRow['lng']) ?? 0,
      altitudeMeters: _toDouble(routePointRow['altitude_meters']),
      recordedAt: _tryParseDateTime(routePointRow['timestamp']),
      createdAt: _tryParseDateTime(routePointRow['created_at']),
      updatedAt: _tryParseDateTime(routePointRow['updated_at']),
    );
  }

  RunHeartRateSample _mapHeartRateRow(Map<String, dynamic> heartRateRow) {
    return RunHeartRateSample(
      id: heartRateRow['id'] as String,
      runId: heartRateRow['run_id'] as String,
      timestamp: DateTime.parse(heartRateRow['timestamp'] as String),
      bpm: (heartRateRow['bpm'] as int?) ?? 0,
      createdAt: _tryParseDateTime(heartRateRow['created_at']),
      updatedAt: _tryParseDateTime(heartRateRow['updated_at']),
    );
  }

  DateTime? _tryParseDateTime(Object? rawValue) {
    final rawString = rawValue as String?;
    if (rawString == null) {
      return null;
    }
    return DateTime.tryParse(rawString);
  }

  double? _toDouble(Object? rawValue) {
    if (rawValue == null) {
      return null;
    }
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    return double.tryParse('$rawValue');
  }
}

@riverpod
RunsRepositoryPowerSync runsRepositoryPowerSync(Ref ref) {
  final databaseAsync = ref.watch(powerSyncDatabaseProvider);
  final powerSyncDatabase = databaseAsync.value;
  if (powerSyncDatabase == null) {
    throw StateError('PowerSync database not initialized');
  }
  return RunsRepositoryPowerSync(powerSyncDatabase);
}
