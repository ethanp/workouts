import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/services/repositories/run_metrics_store.dart';
import 'package:workouts/utils/training_load_calculator.dart';

final _log = Logger('RunImporter');
const _uuid = Uuid();
final _runIdNamespace = Namespace.url.value;

/// Orchestrates importing HealthKit running workouts into the local database.
class RunImporter {
  RunImporter(this._powerSync, this._metricsStore);

  final PowerSyncDatabase _powerSync;
  final RunMetricsStore _metricsStore;

  /// Returns the number of newly inserted runs (skipped ones not counted).
  Future<int> upsertAll(
    List<Map<String, dynamic>> payloads, {
    void Function(int done, int total)? onProgress,
    required TrainingLoadCalculator trainingLoad,
  }) async {
    _log.info('Starting import of ${payloads.length} runs.');
    var inserted = 0;
    for (var payloadIndex = 0; payloadIndex < payloads.length; payloadIndex++) {
      final RunImportPayload? run =
          RunImportPayload.tryParse(payloads[payloadIndex]);
      if (run != null) {
        final bool wasNew = await _upsert(run, trainingLoad: trainingLoad);
        if (wasNew) inserted++;
      } else {
        _log.warning(
          'Skipping unparseable run payload at index $payloadIndex.',
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
    RunImportPayload run, {
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final String runId = await _resolveRunId(run.externalWorkoutId);
    if (await _existingCreatedAt(runId) != null) {
      _log.fine('Skipping run ${run.externalWorkoutId} (already stored).');
      return false;
    }
    _log.fine(
      'Inserting run ${run.externalWorkoutId} '
      '(${run.routePoints.length} pts, ${run.heartRateSamples.length} HR samples)',
    );
    final String now = DateTime.now().toIso8601String();
    await _saveRun(runId, run, createdAt: now, updatedAt: now);
    await _saveRoutePoints(runId, run.routePoints, now: now);
    await _saveHeartRateSamples(runId, run.heartRateSamples, now: now);
    await _metricsStore.computeAndStore(runId, trainingLoad: trainingLoad);
    return true;
  }

  Future<void> _saveRun(
    String runId,
    RunImportPayload run, {
    required String createdAt,
    required String updatedAt,
  }) => _powerSync.execute(
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
    List<RoutePointPayload> points, {
    required String now,
  }) async {
    // GPS data for a completed HealthKit run is immutable — skip if already stored
    // to avoid generating thousands of DELETE+INSERT CRUD entries on re-import.
    final Map<String, dynamic>? countRow = await _powerSync.getOptional(
      'SELECT COUNT(*) AS cnt FROM run_route_points WHERE run_id = ?',
      [runId],
    );
    if ((countRow?['cnt'] as int? ?? 0) > 0) {
      _log.fine('Route points already exist for $runId — skipping.');
      return;
    }
    if (points.isEmpty) return;

    _log.fine('Inserting ${points.length} route points for $runId.');
    await _powerSync.writeTransaction((transaction) async {
      for (var pointIndex = 0; pointIndex < points.length; pointIndex++) {
        final RoutePointPayload point = points[pointIndex];
        await transaction.execute(
          'INSERT INTO run_route_points'
          '  (id, run_id, point_index, lat, lng, altitude_meters, timestamp, created_at, updated_at)'
          ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            _uuid.v4(),
            runId,
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
    String runId,
    List<HeartRateSamplePayload> samples, {
    required String now,
  }) async {
    // Same rationale as _saveRoutePoints: skip if samples already exist.
    final Map<String, dynamic>? countRow = await _powerSync.getOptional(
      'SELECT COUNT(*) AS cnt FROM run_heart_rate_samples WHERE run_id = ?',
      [runId],
    );
    if ((countRow?['cnt'] as int? ?? 0) > 0) {
      _log.fine('HR samples already exist for $runId — skipping.');
      return;
    }
    if (samples.isEmpty) return;

    _log.fine('Inserting ${samples.length} HR samples for $runId.');
    await _powerSync.writeTransaction((transaction) async {
      for (final HeartRateSamplePayload sample in samples) {
        await transaction.execute(
          'INSERT INTO run_heart_rate_samples'
          '  (id, run_id, timestamp, bpm, created_at, updated_at)'
          ' VALUES (?, ?, ?, ?, ?, ?)',
          [_uuid.v4(), runId, sample.timestamp, sample.bpm, now, now],
        );
      }
    });
  }

  /// Returns the deterministic UUID for [externalWorkoutId], deleting any
  /// locally-stored rows that used a different (non-deterministic) UUID for
  /// the same workout.
  Future<String> _resolveRunId(String externalWorkoutId) async {
    final String deterministicId = _uuid.v5(
      _runIdNamespace,
      'apple-health-run:$externalWorkoutId',
    );
    final List<Map<String, dynamic>> staleRows = await _powerSync.execute(
      'SELECT id FROM runs WHERE external_workout_id = ? AND id != ?',
      [externalWorkoutId, deterministicId],
    );
    for (final staleRow in staleRows) {
      await _powerSync.execute(
        'DELETE FROM runs WHERE id = ?',
        [staleRow['id']],
      );
    }
    return deterministicId;
  }

  Future<String?> _existingCreatedAt(String runId) async {
    final Map<String, dynamic>? runRow = await _powerSync.getOptional(
      'SELECT created_at FROM runs WHERE id = ?',
      [runId],
    );
    return runRow?['created_at'] as String?;
  }
}

class RunImportPayload {
  const RunImportPayload({
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
  final List<RoutePointPayload> routePoints;
  final List<HeartRateSamplePayload> heartRateSamples;

  static RunImportPayload? tryParse(Map<String, dynamic> payload) {
    final String? externalWorkoutId = payload['externalWorkoutId'] as String?;
    final String? startedAt = payload['startDate'] as String?;
    final String? endedAt = payload['endDate'] as String?;
    if (externalWorkoutId == null ||
        externalWorkoutId.isEmpty ||
        startedAt == null ||
        endedAt == null) {
      return null;
    }
    return RunImportPayload(
      externalWorkoutId: externalWorkoutId,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: payload['durationSeconds'] as int? ?? 0,
      distanceMeters: _asDouble(payload['distanceMeters']) ?? 0,
      energyKcal: _asDouble(payload['energyKcal']),
      avgHeartRateBpm: _asDouble(payload['avgHeartRateBpm']),
      maxHeartRateBpm: _asDouble(payload['maxHeartRateBpm']),
      isIndoor: payload['isIndoor'] == true,
      routeAvailable: payload['routeAvailable'] == true,
      sourceName: (payload['sourceName'] as String?) ?? 'Apple Health',
      sourceBundleId: payload['sourceBundleId'] as String?,
      deviceModel: payload['deviceModel'] as String?,
      routePoints: RoutePointPayload.parseList(payload['routePoints']),
      heartRateSamples:
          HeartRateSamplePayload.parseList(payload['heartRateSeries']),
    );
  }
}

class RoutePointPayload {
  const RoutePointPayload({
    required this.lat,
    required this.lng,
    required this.altitudeMeters,
    required this.timestamp,
  });

  final double lat;
  final double lng;
  final double? altitudeMeters;
  final String? timestamp;

  static List<RoutePointPayload> parseList(Object? raw) {
    if (raw is! List) return const [];
    final parsedPoints = <RoutePointPayload>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final Map<String, dynamic> pointMap = Map<String, dynamic>.from(item);
      final double? lat = _asDouble(pointMap['lat']);
      final double? lng = _asDouble(pointMap['lng']);
      if (lat == null || lng == null) continue;
      parsedPoints.add(
        RoutePointPayload(
          lat: lat,
          lng: lng,
          altitudeMeters: _asDouble(pointMap['altitudeMeters']),
          timestamp: pointMap['timestamp'] as String?,
        ),
      );
    }
    return parsedPoints;
  }
}

class HeartRateSamplePayload {
  const HeartRateSamplePayload({required this.timestamp, required this.bpm});

  final String timestamp;
  final int bpm;

  static List<HeartRateSamplePayload> parseList(Object? raw) {
    if (raw is! List) return const [];
    final parsedSamples = <HeartRateSamplePayload>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final Map<String, dynamic> sampleMap = Map<String, dynamic>.from(item);
      final String? timestamp = sampleMap['timestamp'] as String?;
      final int? bpm = _asDouble(sampleMap['bpm'])?.round();
      if (timestamp == null || bpm == null) continue;
      parsedSamples.add(
        HeartRateSamplePayload(timestamp: timestamp, bpm: bpm),
      );
    }
    return parsedSamples;
  }
}

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}
