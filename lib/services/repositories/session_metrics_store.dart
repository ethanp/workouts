import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/utils/training_load_calculator.dart';

final _log = Logger('SessionMetricsStore');

/// Manages the `session_computed_metrics` local-only table: computing, storing,
/// backfilling, and recomputing zone times and TRIMP for individual sessions.
class SessionMetricsStore {
  SessionMetricsStore(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<void> computeAndStore(
    String sessionId, {
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final result =
        await _loadAndCompute(sessionId, trainingLoad: trainingLoad);
    await _persistMetrics(sessionId, result,
        restingHr: trainingLoad.restingHeartRate);
  }

  Future<void> recomputeAllZones({
    required TrainingLoadCalculator trainingLoad,
    void Function(int done, int total)? onProgress,
  }) async {
    final List<Map<String, dynamic>> sessionRows = await _powerSync.execute(
      "SELECT id FROM sessions WHERE completed_at IS NOT NULL"
      " ORDER BY started_at DESC",
    );
    _log.info(
      'Recomputing session zones for ${sessionRows.length} sessions.',
    );
    for (var sessionIndex = 0;
        sessionIndex < sessionRows.length;
        sessionIndex++) {
      await _recomputeZones(
        sessionRows[sessionIndex]['id'] as String,
        trainingLoad: trainingLoad,
      );
      onProgress?.call(sessionIndex + 1, sessionRows.length);
    }
    _log.info('Session zone recompute complete.');
  }

  Future<void> backfillMissing({
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final List<Map<String, dynamic>> pendingRows =
        await _powerSync.execute('''
      SELECT s.id FROM sessions s
      LEFT JOIN session_computed_metrics m ON m.id = s.id
      WHERE s.completed_at IS NOT NULL
        AND (m.id IS NULL OR m.zone1_seconds IS NULL)
    ''');
    if (pendingRows.isEmpty) return;
    _log.info(
      'Backfilling session metrics for ${pendingRows.length} sessions.',
    );
    for (final pendingRow in pendingRows) {
      await computeAndStore(
        pendingRow['id'] as String,
        trainingLoad: trainingLoad,
      );
    }
    _log.info('Session metrics backfill complete.');
  }

  Future<List<TimestampedHeartRate>> loadHrSamples(String sessionId) async {
    final List<Map<String, dynamic>> sampleRows = await _powerSync.execute(
      'SELECT timestamp, bpm FROM heart_rate_samples'
      ' WHERE session_id = ? ORDER BY timestamp ASC',
      [sessionId],
    );
    return sampleRows
        .map(
          (sampleRow) => TimestampedHeartRate(
            timestamp: DateTime.parse(sampleRow['timestamp'] as String),
            bpm: sampleRow['bpm'] as int,
          ),
        )
        .toList();
  }

  Future<_ComputedMetrics> _loadAndCompute(
    String sessionId, {
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final hrSamples = await loadHrSamples(sessionId);
    if (hrSamples.isEmpty) {
      return const _ComputedMetrics(
        result: TrainingLoadResult(),
        hasHrSamples: false,
      );
    }
    return _ComputedMetrics(
      result: trainingLoad.compute(hrSamples),
      hasHrSamples: true,
    );
  }

  Future<void> _persistMetrics(
    String sessionId,
    _ComputedMetrics metrics, {
    required int restingHr,
  }) async {
    final zone = metrics.result.zoneTime;
    final computedAt = DateTime.now().toUtc().toIso8601String();
    final hasHr = metrics.hasHrSamples ? 1 : 0;

    final existing = await _powerSync.getOptional(
      'SELECT id FROM session_computed_metrics WHERE id = ?',
      [sessionId],
    );
    if (existing != null) {
      await _powerSync.execute(
        'UPDATE session_computed_metrics'
        ' SET zone1_seconds = ?, zone2_seconds = ?, zone3_seconds = ?,'
        '     zone4_seconds = ?, zone5_seconds = ?,'
        '     trimp = ?, has_hr_samples = ?, resting_hr = ?, computed_at = ?'
        ' WHERE id = ?',
        [
          zone.zone1, zone.zone2, zone.zone3,
          zone.zone4, zone.zone5,
          metrics.result.trimp, hasHr, restingHr, computedAt, sessionId,
        ],
      );
    } else {
      await _powerSync.execute(
        'INSERT INTO session_computed_metrics'
        '  (id, zone1_seconds, zone2_seconds, zone3_seconds,'
        '   zone4_seconds, zone5_seconds,'
        '   trimp, has_hr_samples, resting_hr, computed_at)'
        ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          sessionId,
          zone.zone1, zone.zone2, zone.zone3,
          zone.zone4, zone.zone5,
          metrics.result.trimp, hasHr, restingHr, computedAt,
        ],
      );
    }
  }

  /// Recomputes only zone times for a single session, preserving existing TRIMP.
  Future<void> _recomputeZones(
    String sessionId, {
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final hrSamples = await loadHrSamples(sessionId);

    final HrZoneTime zone;
    final int hasHr;
    if (hrSamples.isEmpty) {
      zone = HrZoneTime.zero;
      hasHr = 0;
    } else {
      zone = trainingLoad.compute(hrSamples).zoneTime;
      hasHr = 1;
    }

    final computedAt = DateTime.now().toUtc().toIso8601String();
    final existing = await _powerSync.getOptional(
      'SELECT id FROM session_computed_metrics WHERE id = ?',
      [sessionId],
    );
    if (existing != null) {
      await _powerSync.execute(
        'UPDATE session_computed_metrics'
        ' SET zone1_seconds = ?, zone2_seconds = ?, zone3_seconds = ?,'
        '     zone4_seconds = ?, zone5_seconds = ?,'
        '     has_hr_samples = ?, computed_at = ?'
        ' WHERE id = ?',
        [
          zone.zone1, zone.zone2, zone.zone3,
          zone.zone4, zone.zone5,
          hasHr, computedAt, sessionId,
        ],
      );
    } else {
      await _powerSync.execute(
        'INSERT INTO session_computed_metrics'
        '  (id, zone1_seconds, zone2_seconds, zone3_seconds,'
        '   zone4_seconds, zone5_seconds,'
        '   has_hr_samples, computed_at)'
        ' VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          sessionId,
          zone.zone1, zone.zone2, zone.zone3,
          zone.zone4, zone.zone5,
          hasHr, computedAt,
        ],
      );
    }
  }
}

class _ComputedMetrics {
  const _ComputedMetrics({required this.result, required this.hasHrSamples});

  final TrainingLoadResult result;
  final bool hasHrSamples;
}
