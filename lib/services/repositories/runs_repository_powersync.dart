import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/fitness_run.dart';
import 'package:workouts/models/run_heart_rate_sample.dart';
import 'package:workouts/models/run_route_point.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';

part 'runs_repository_powersync.g.dart';

final _log = Logger('RunsRepository');

const _uuid = Uuid();
final _runIdNamespace = Namespace.url.value;

class RunsRepositoryPowerSync {
  RunsRepositoryPowerSync(this._db);

  final PowerSyncDatabase _db;

  Stream<List<FitnessRun>> watchRuns() => _db
      .watch('SELECT * FROM runs ORDER BY started_at DESC')
      .map((rows) => rows.map(_runFromRow).toList());

  Stream<List<RunRoutePoint>> watchRoutePoints(String runId) => _db
      .watch(
        'SELECT * FROM run_route_points WHERE run_id = ? ORDER BY point_index ASC',
        parameters: [runId],
      )
      .map((rows) => rows.map(_routePointFromRow).toList());

  Stream<List<RunHeartRateSample>> watchHeartRateSamples(String runId) => _db
      .watch(
        'SELECT * FROM run_heart_rate_samples WHERE run_id = ? ORDER BY timestamp ASC',
        parameters: [runId],
      )
      .map((rows) => rows.map(_heartRateSampleFromRow).toList());

  Future<void> upsertImportedRuns(
    List<Map<String, dynamic>> payloads, {
    void Function(int done, int total)? onProgress,
  }) async {
    _log.info('Starting import of ${payloads.length} runs.');
    for (var i = 0; i < payloads.length; i++) {
      final run = _RunImport.tryParse(payloads[i]);
      if (run != null) {
        await _upsert(run);
      } else {
        _log.warning('Skipping unparseable run payload at index $i.');
      }
      onProgress?.call(i + 1, payloads.length);
    }
    _log.info('Import complete.');
  }

  Future<void> _upsert(_RunImport run) async {
    _log.fine(
      'Upserting run ${run.externalWorkoutId} '
      '(${run.routePoints.length} pts, ${run.heartRateSamples.length} HR samples)',
    );
    final runId = await _resolveRunId(run.externalWorkoutId);
    final now = DateTime.now().toIso8601String();
    final createdAt = await _existingCreatedAt(runId) ?? now;
    await _saveRun(runId, run, createdAt: createdAt, updatedAt: now);
    await _saveRoutePoints(runId, run.routePoints, now: now);
    await _saveHeartRateSamples(runId, run.heartRateSamples, now: now);
  }

  /// Returns the deterministic UUID for [externalWorkoutId], deleting any
  /// locally-stored rows that used a different (non-deterministic) UUID for
  /// the same workout. The resulting DELETE CRUD entries propagate to the
  /// server through PowerSync's upload queue.
  Future<String> _resolveRunId(String externalWorkoutId) async {
    final deterministicId = _uuid.v5(
      _runIdNamespace,
      'apple-health-run:$externalWorkoutId',
    );
    final staleRows = await _db.execute(
      'SELECT id FROM runs WHERE external_workout_id = ? AND id != ?',
      [externalWorkoutId, deterministicId],
    );
    for (final row in staleRows) {
      await _db.execute('DELETE FROM runs WHERE id = ?', [row['id']]);
    }
    return deterministicId;
  }

  Future<String?> _existingCreatedAt(String runId) async {
    final row = await _db.getOptional(
      'SELECT created_at FROM runs WHERE id = ?',
      [runId],
    );
    return row?['created_at'] as String?;
  }

  Future<void> _saveRun(
    String runId,
    _RunImport run, {
    required String createdAt,
    required String updatedAt,
  }) => _db.execute(
    // ON CONFLICT DO UPDATE avoids a DELETE+INSERT pair (which INSERT OR REPLACE
    // would produce). A DELETE CRUD entry would be uploaded to the server and
    // temporarily remove the run, creating a window where a PowerSync checkpoint
    // could wipe the run on the next sync.
    '''
    INSERT INTO runs (
      id, external_workout_id, started_at, ended_at, duration_seconds,
      distance_meters, energy_kcal, avg_heart_rate_bpm, max_heart_rate_bpm,
      is_indoor, route_available, source_name, source_bundle_id, device_model,
      created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
      started_at      = excluded.started_at,
      ended_at        = excluded.ended_at,
      duration_seconds  = excluded.duration_seconds,
      distance_meters   = excluded.distance_meters,
      energy_kcal       = excluded.energy_kcal,
      avg_heart_rate_bpm  = excluded.avg_heart_rate_bpm,
      max_heart_rate_bpm  = excluded.max_heart_rate_bpm,
      is_indoor         = excluded.is_indoor,
      route_available   = excluded.route_available,
      source_name       = excluded.source_name,
      source_bundle_id  = excluded.source_bundle_id,
      device_model      = excluded.device_model,
      updated_at        = excluded.updated_at
    ''',
    [
      runId,
      run.externalWorkoutId,
      run.startedAt,
      run.endedAt,
      run.durationSeconds,
      run.distanceMeters,
      run.energyKcal,
      run.avgHeartRateBpm,
      run.maxHeartRateBpm,
      run.isIndoor ? 1 : 0,
      run.routeAvailable ? 1 : 0,
      run.sourceName,
      run.sourceBundleId,
      run.deviceModel,
      createdAt,
      updatedAt,
    ],
  );

  Future<void> _saveRoutePoints(
    String runId,
    List<_RoutePointImport> points, {
    required String now,
  }) async {
    // GPS data for a completed HealthKit run is immutable. Skip the write if
    // points already exist to avoid generating thousands of DELETE+INSERT CRUD
    // entries on every re-import, which floods the upload queue.
    final existing = await _db.getOptional(
      'SELECT COUNT(*) AS cnt FROM run_route_points WHERE run_id = ?',
      [runId],
    );
    if ((existing?['cnt'] as int? ?? 0) > 0) {
      _log.fine('Route points already exist for $runId — skipping.');
      return;
    }
    if (points.isEmpty) return;

    _log.fine('Inserting ${points.length} route points for $runId.');
    await _db.writeTransaction((tx) async {
      for (var i = 0; i < points.length; i++) {
        final p = points[i];
        await tx.execute(
          'INSERT INTO run_route_points'
          '  (id, run_id, point_index, lat, lng, altitude_meters, timestamp, created_at, updated_at)'
          ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [_uuid.v4(), runId, i, p.lat, p.lng, p.altitudeMeters, p.timestamp, now, now],
        );
      }
    });
  }

  Future<void> _saveHeartRateSamples(
    String runId,
    List<_HeartRateSampleImport> samples, {
    required String now,
  }) async {
    // Same rationale as _saveRoutePoints: skip if samples already exist.
    final existing = await _db.getOptional(
      'SELECT COUNT(*) AS cnt FROM run_heart_rate_samples WHERE run_id = ?',
      [runId],
    );
    if ((existing?['cnt'] as int? ?? 0) > 0) {
      _log.fine('HR samples already exist for $runId — skipping.');
      return;
    }
    if (samples.isEmpty) return;

    _log.fine('Inserting ${samples.length} HR samples for $runId.');
    await _db.writeTransaction((tx) async {
      for (final s in samples) {
        await tx.execute(
          'INSERT INTO run_heart_rate_samples'
          '  (id, run_id, timestamp, bpm, created_at, updated_at)'
          ' VALUES (?, ?, ?, ?, ?, ?)',
          [_uuid.v4(), runId, s.timestamp, s.bpm, now, now],
        );
      }
    });
  }

  FitnessRun _runFromRow(Map<String, dynamic> row) => FitnessRun(
    id: row['id'] as String,
    externalWorkoutId: row['external_workout_id'] as String,
    startedAt: DateTime.parse(row['started_at'] as String),
    endedAt: DateTime.parse(row['ended_at'] as String),
    durationSeconds: (row['duration_seconds'] as int?) ?? 0,
    distanceMeters: _asDouble(row['distance_meters']) ?? 0,
    energyKcal: _asDouble(row['energy_kcal']),
    averageHeartRateBpm: _asDouble(row['avg_heart_rate_bpm']),
    maxHeartRateBpm: _asDouble(row['max_heart_rate_bpm']),
    isIndoor: (row['is_indoor'] as int?) == 1,
    routeAvailable: (row['route_available'] as int?) == 1,
    sourceName: (row['source_name'] as String?) ?? 'Apple Health',
    sourceBundleId: row['source_bundle_id'] as String?,
    deviceModel: row['device_model'] as String?,
    createdAt: _asDateTime(row['created_at']),
    updatedAt: _asDateTime(row['updated_at']),
  );

  RunRoutePoint _routePointFromRow(Map<String, dynamic> row) => RunRoutePoint(
    id: row['id'] as String,
    runId: row['run_id'] as String,
    pointIndex: (row['point_index'] as int?) ?? 0,
    latitude: _asDouble(row['lat']) ?? 0,
    longitude: _asDouble(row['lng']) ?? 0,
    altitudeMeters: _asDouble(row['altitude_meters']),
    recordedAt: _asDateTime(row['timestamp']),
    createdAt: _asDateTime(row['created_at']),
    updatedAt: _asDateTime(row['updated_at']),
  );

  RunHeartRateSample _heartRateSampleFromRow(Map<String, dynamic> row) =>
      RunHeartRateSample(
        id: row['id'] as String,
        runId: row['run_id'] as String,
        timestamp: DateTime.parse(row['timestamp'] as String),
        bpm: (row['bpm'] as int?) ?? 0,
        createdAt: _asDateTime(row['created_at']),
        updatedAt: _asDateTime(row['updated_at']),
      );
}

// Import value types — parse the untyped HealthKit payload once at the
// boundary. Everything below this point works with typed fields only.

class _RunImport {
  const _RunImport({
    required this.externalWorkoutId,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.energyKcal,
    required this.avgHeartRateBpm,
    required this.maxHeartRateBpm,
    required this.isIndoor,
    required this.routeAvailable,
    required this.sourceName,
    required this.sourceBundleId,
    required this.deviceModel,
    required this.routePoints,
    required this.heartRateSamples,
  });

  final String externalWorkoutId;
  final String startedAt;
  final String endedAt;
  final int durationSeconds;
  final double distanceMeters;
  final double? energyKcal;
  final double? avgHeartRateBpm;
  final double? maxHeartRateBpm;
  final bool isIndoor;
  final bool routeAvailable;
  final String sourceName;
  final String? sourceBundleId;
  final String? deviceModel;
  final List<_RoutePointImport> routePoints;
  final List<_HeartRateSampleImport> heartRateSamples;

  static _RunImport? tryParse(Map<String, dynamic> p) {
    final externalWorkoutId = p['externalWorkoutId'] as String?;
    final startedAt = p['startDate'] as String?;
    final endedAt = p['endDate'] as String?;
    if (externalWorkoutId == null ||
        externalWorkoutId.isEmpty ||
        startedAt == null ||
        endedAt == null) {
      return null;
    }
    return _RunImport(
      externalWorkoutId: externalWorkoutId,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: p['durationSeconds'] as int? ?? 0,
      distanceMeters: _asDouble(p['distanceMeters']) ?? 0,
      energyKcal: _asDouble(p['energyKcal']),
      avgHeartRateBpm: _asDouble(p['avgHeartRateBpm']),
      maxHeartRateBpm: _asDouble(p['maxHeartRateBpm']),
      isIndoor: p['isIndoor'] == true,
      routeAvailable: p['routeAvailable'] == true,
      sourceName: (p['sourceName'] as String?) ?? 'Apple Health',
      sourceBundleId: p['sourceBundleId'] as String?,
      deviceModel: p['deviceModel'] as String?,
      routePoints: _RoutePointImport.parseList(p['routePoints']),
      heartRateSamples: _HeartRateSampleImport.parseList(p['heartRateSeries']),
    );
  }
}

class _RoutePointImport {
  const _RoutePointImport({
    required this.lat,
    required this.lng,
    required this.altitudeMeters,
    required this.timestamp,
  });

  final double lat;
  final double lng;
  final double? altitudeMeters;
  final String? timestamp;

  static List<_RoutePointImport> parseList(Object? raw) {
    if (raw is! List) return const [];
    final points = <_RoutePointImport>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final p = Map<String, dynamic>.from(item);
      final lat = _asDouble(p['lat']);
      final lng = _asDouble(p['lng']);
      if (lat == null || lng == null) continue;
      points.add(
        _RoutePointImport(
          lat: lat,
          lng: lng,
          altitudeMeters: _asDouble(p['altitudeMeters']),
          timestamp: p['timestamp'] as String?,
        ),
      );
    }
    return points;
  }
}

class _HeartRateSampleImport {
  const _HeartRateSampleImport({required this.timestamp, required this.bpm});

  final String timestamp;
  final int bpm;

  static List<_HeartRateSampleImport> parseList(Object? raw) {
    if (raw is! List) return const [];
    final samples = <_HeartRateSampleImport>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final p = Map<String, dynamic>.from(item);
      final timestamp = p['timestamp'] as String?;
      final bpm = _asDouble(p['bpm'])?.round();
      if (timestamp == null || bpm == null) continue;
      samples.add(_HeartRateSampleImport(timestamp: timestamp, bpm: bpm));
    }
    return samples;
  }
}

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

DateTime? _asDateTime(Object? value) {
  final string = value as String?;
  return string == null ? null : DateTime.tryParse(string);
}

@riverpod
RunsRepositoryPowerSync runsRepositoryPowerSync(Ref ref) {
  final db = ref.watch(powerSyncDatabaseProvider).value;
  if (db == null) throw StateError('PowerSync database not initialized');
  return RunsRepositoryPowerSync(db);
}
