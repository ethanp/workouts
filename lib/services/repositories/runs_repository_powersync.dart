import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/fitness_run.dart';
import 'package:workouts/models/run_calendar_day.dart';
import 'package:workouts/models/run_heart_rate_sample.dart';
import 'package:workouts/models/run_route_point.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/utils/zone2_calculator.dart';

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

  Stream<List<RunCalendarDay>> watchCalendarDays() => _db
      .watch(
        '''
        SELECT
          DATE(r.started_at, 'localtime') AS day,
          SUM(r.distance_meters)          AS total_distance_meters,
          SUM(r.duration_seconds)         AS total_duration_seconds,
          COALESCE(SUM(m.zone2_seconds), 0) AS total_zone2_seconds,
          MAX(COALESCE(m.has_hr_samples, 0)) AS has_hr_data,
          COUNT(r.id)                     AS run_count
        FROM runs r
        LEFT JOIN run_computed_metrics m ON m.id = r.id
        GROUP BY day
        ORDER BY day ASC
        ''',
        // Trigger on both tables so the stream updates when metrics are written.
        triggerOnTables: const {'runs', 'run_computed_metrics'},
      )
      .map((rows) => rows.map(_calendarDayFromRow).toList());

  Future<List<FitnessRun>> getRunsForDate(DateTime localDate) async {
    final dayString =
        '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
    final runRows = await _db.execute(
      "SELECT * FROM runs WHERE DATE(started_at, 'localtime') = ? ORDER BY started_at ASC",
      [dayString],
    );
    return runRows.map(_runFromRow).toList();
  }

  Future<void> deleteRun(String runId) async {
    await _db.writeTransaction((tx) async {
      await tx.execute('DELETE FROM run_route_points WHERE run_id = ?', [
        runId,
      ]);
      await tx.execute('DELETE FROM run_heart_rate_samples WHERE run_id = ?', [
        runId,
      ]);
      await tx.execute('DELETE FROM run_computed_metrics WHERE id = ?', [
        runId,
      ]);
      await tx.execute('DELETE FROM runs WHERE id = ?', [runId]);
    });
    _log.info('Deleted run $runId (queued for upload).');
  }

  /// Returns the number of newly inserted runs (skipped ones not counted).
  Future<int> upsertImportedRuns(
    List<Map<String, dynamic>> payloads, {
    void Function(int done, int total)? onProgress,
    required Zone2Calculator zone2,
  }) async {
    _log.info('Starting import of ${payloads.length} runs.');
    var inserted = 0;
    for (var i = 0; i < payloads.length; i++) {
      final run = _RunImport.tryParse(payloads[i]);
      if (run != null) {
        final wasNew = await _upsert(run, zone2: zone2);
        if (wasNew) inserted++;
      } else {
        _log.warning('Skipping unparseable run payload at index $i.');
      }
      onProgress?.call(i + 1, payloads.length);
    }
    _log.info(
      'Import complete: $inserted new, ${payloads.length - inserted} already stored.',
    );
    return inserted;
  }

  Future<void> recomputeAllZone2({
    required Zone2Calculator zone2,
    void Function(int done, int total)? onProgress,
  }) async {
    final runRows = await _db.execute(
      'SELECT id FROM runs ORDER BY started_at DESC',
    );
    _log.info('Recomputing Zone 2 for ${runRows.length} runs.');
    for (var i = 0; i < runRows.length; i++) {
      await _computeAndStoreMetrics(runRows[i]['id'] as String, zone2: zone2);
      onProgress?.call(i + 1, runRows.length);
    }
    _log.info('Zone 2 recompute complete.');
  }

  /// Computes Zone 2 metrics for any runs missing a `run_computed_metrics`
  /// row, or for runs whose existing row has no HR lower bound (meaning the
  /// computation ran before HR samples arrived).
  Future<void> backfillMissingMetrics({required Zone2Calculator zone2}) async {
    final pendingRows = await _db.execute('''
      SELECT r.id FROM runs r
      LEFT JOIN run_computed_metrics m ON m.id = r.id
      WHERE m.id IS NULL OR m.zone2_hr_lower IS NULL
    ''');
    if (pendingRows.isEmpty) return;
    _log.info('Backfilling Zone 2 metrics for ${pendingRows.length} runs.');
    for (final row in pendingRows) {
      await _computeAndStoreMetrics(row['id'] as String, zone2: zone2);
    }
    _log.info('Backfill complete.');
  }

  /// Returns true if the run was newly inserted, false if already stored.
  Future<bool> _upsert(
    _RunImport run, {
    required Zone2Calculator zone2,
  }) async {
    final runId = await _resolveRunId(run.externalWorkoutId);
    if (await _existingCreatedAt(runId) != null) {
      _log.fine('Skipping run ${run.externalWorkoutId} (already stored).');
      return false;
    }
    _log.fine(
      'Inserting run ${run.externalWorkoutId} '
      '(${run.routePoints.length} pts, ${run.heartRateSamples.length} HR samples)',
    );
    final now = DateTime.now().toIso8601String();
    await _saveRun(runId, run, createdAt: now, updatedAt: now);
    await _saveRoutePoints(runId, run.routePoints, now: now);
    await _saveHeartRateSamples(runId, run.heartRateSamples, now: now);
    await _computeAndStoreMetrics(runId, zone2: zone2);
    return true;
  }

  Future<void> _computeAndStoreMetrics(
    String runId, {
    required Zone2Calculator zone2,
  }) async {
    final sampleRows = await _db.execute(
      'SELECT timestamp, bpm FROM run_heart_rate_samples'
      ' WHERE run_id = ? ORDER BY timestamp ASC',
      [runId],
    );

    final int zone2Seconds;
    final int hasHrSamples;
    final int? storedLower;
    final int? storedUpper;

    if (sampleRows.isEmpty) {
      zone2Seconds = 0;
      hasHrSamples = 0;
      storedLower = null;
      storedUpper = null;
    } else {
      final typedSamples = sampleRows
          .map(
            (r) => TimestampedHeartRate(
              timestamp: DateTime.parse(r['timestamp'] as String),
              bpm: r['bpm'] as int,
            ),
          )
          .toList();
      zone2Seconds = zone2.seconds(typedSamples);
      hasHrSamples = 1;
      storedLower = zone2.lowerBpm;
      storedUpper = zone2.upperBpm;
    }

    final computedAt = DateTime.now().toUtc().toIso8601String();
    final existing = await _db.getOptional(
      'SELECT id FROM run_computed_metrics WHERE id = ?',
      [runId],
    );
    if (existing != null) {
      await _db.execute(
        'UPDATE run_computed_metrics'
        ' SET zone2_seconds = ?, has_hr_samples = ?,'
        '     zone2_hr_lower = ?, zone2_hr_upper = ?, computed_at = ?'
        ' WHERE id = ?',
        [
          zone2Seconds,
          hasHrSamples,
          storedLower,
          storedUpper,
          computedAt,
          runId,
        ],
      );
    } else {
      await _db.execute(
        'INSERT INTO run_computed_metrics'
        '  (id, zone2_seconds, has_hr_samples, zone2_hr_lower, zone2_hr_upper, computed_at)'
        ' VALUES (?, ?, ?, ?, ?, ?)',
        [
          runId,
          zone2Seconds,
          hasHrSamples,
          storedLower,
          storedUpper,
          computedAt,
        ],
      );
    }
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
    '''
    INSERT INTO runs (
      id, external_workout_id, started_at, ended_at, duration_seconds,
      distance_meters, energy_kcal, avg_heart_rate_bpm, max_heart_rate_bpm,
      is_indoor, route_available, source_name, source_bundle_id, device_model,
      created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
          [
            _uuid.v4(),
            runId,
            i,
            p.lat,
            p.lng,
            p.altitudeMeters,
            p.timestamp,
            now,
            now,
          ],
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

  RunCalendarDay _calendarDayFromRow(Map<String, dynamic> row) {
    final dayString = row['day'] as String;
    final parts = dayString.split('-');
    return RunCalendarDay(
      date: DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
      totalDistanceMeters: _asDouble(row['total_distance_meters']) ?? 0,
      totalDurationSeconds: (row['total_duration_seconds'] as int?) ?? 0,
      zone2Minutes: ((row['total_zone2_seconds'] as int? ?? 0) ~/ 60),
      hasHrData: (row['has_hr_data'] as int? ?? 0) == 1,
      runCount: (row['run_count'] as int?) ?? 0,
    );
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
