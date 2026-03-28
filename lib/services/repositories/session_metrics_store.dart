import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/services/powersync/powersync_extensions.dart';
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

    await _powerSync.upsert('session_computed_metrics', {
      'id': sessionId,
      ...zone.toRow(),
      'trimp': metrics.result.trimp,
      'has_hr_samples': hasHr,
      'resting_hr': restingHr,
      'computed_at': computedAt,
    });
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
    await _powerSync.upsert('session_computed_metrics', {
      'id': sessionId,
      ...zone.toRow(),
      'has_hr_samples': hasHr,
      'computed_at': computedAt,
    });
  }
}

class _ComputedMetrics {
  const _ComputedMetrics({required this.result, required this.hasHrSamples});

  final TrainingLoadResult result;
  final bool hasHrSamples;
}
