import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/utils/training_load_calculator.dart';

final _log = Logger('RunMetricsStore');

/// Manages the `run_computed_metrics` local-only table: computing, storing,
/// backfilling, and recomputing zone times and TRIMP for individual runs.
class RunMetricsStore {
  RunMetricsStore(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<void> computeAndStore(
    String runId, {
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final result = await _loadAndCompute(runId, trainingLoad: trainingLoad);
    await _persistMetrics(runId, result,
        restingHr: trainingLoad.restingHeartRate);
  }

  Future<void> recomputeAllZones({
    required TrainingLoadCalculator trainingLoad,
    void Function(int done, int total)? onProgress,
  }) async {
    final List<Map<String, dynamic>> runRows = await _powerSync.execute(
      'SELECT id FROM runs ORDER BY started_at DESC',
    );
    _log.info('Recomputing zones for ${runRows.length} runs.');
    for (var runIndex = 0; runIndex < runRows.length; runIndex++) {
      await _recomputeZones(
        runRows[runIndex]['id'] as String,
        trainingLoad: trainingLoad,
      );
      onProgress?.call(runIndex + 1, runRows.length);
    }
    _log.info('Zone recompute complete.');
  }

  Future<void> backfillMissing({
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final List<Map<String, dynamic>> pendingRows = await _powerSync.execute('''
      SELECT r.id FROM runs r
      LEFT JOIN run_computed_metrics m ON m.id = r.id
      WHERE m.id IS NULL OR m.zone1_seconds IS NULL
    ''');
    if (pendingRows.isEmpty) return;
    _log.info('Backfilling metrics for ${pendingRows.length} runs.');
    for (final pendingRow in pendingRows) {
      await computeAndStore(
        pendingRow['id'] as String,
        trainingLoad: trainingLoad,
      );
    }
    _log.info('Backfill complete.');
  }

  Future<List<TimestampedHeartRate>> loadHrSamples(String runId) async {
    final List<Map<String, dynamic>> sampleRows = await _powerSync.execute(
      'SELECT timestamp, bpm FROM run_heart_rate_samples'
      ' WHERE run_id = ? ORDER BY timestamp ASC',
      [runId],
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
    String runId, {
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final hrSamples = await loadHrSamples(runId);
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
    String runId,
    _ComputedMetrics metrics, {
    required int restingHr,
  }) async {
    final zone = metrics.result.zoneTime;
    final computedAt = DateTime.now().toUtc().toIso8601String();
    final hasHr = metrics.hasHrSamples ? 1 : 0;

    final existing = await _powerSync.getOptional(
      'SELECT id FROM run_computed_metrics WHERE id = ?',
      [runId],
    );
    if (existing != null) {
      await _powerSync.execute(
        'UPDATE run_computed_metrics'
        ' SET zone1_seconds = ?, zone2_seconds = ?, zone3_seconds = ?,'
        '     zone4_seconds = ?, zone5_seconds = ?,'
        '     trimp = ?, has_hr_samples = ?, resting_hr = ?, computed_at = ?'
        ' WHERE id = ?',
        [
          zone.zone1Seconds, zone.zone2Seconds, zone.zone3Seconds,
          zone.zone4Seconds, zone.zone5Seconds,
          metrics.result.trimp, hasHr, restingHr, computedAt, runId,
        ],
      );
    } else {
      await _powerSync.execute(
        'INSERT INTO run_computed_metrics'
        '  (id, zone1_seconds, zone2_seconds, zone3_seconds,'
        '   zone4_seconds, zone5_seconds,'
        '   trimp, has_hr_samples, resting_hr, computed_at)'
        ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          runId,
          zone.zone1Seconds, zone.zone2Seconds, zone.zone3Seconds,
          zone.zone4Seconds, zone.zone5Seconds,
          metrics.result.trimp, hasHr, restingHr, computedAt,
        ],
      );
    }
  }

  /// Recomputes only zone times for a single run, preserving existing TRIMP.
  Future<void> _recomputeZones(
    String runId, {
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final hrSamples = await loadHrSamples(runId);

    final ZoneTimeResult zone;
    final int hasHr;
    if (hrSamples.isEmpty) {
      zone = const ZoneTimeResult();
      hasHr = 0;
    } else {
      zone = trainingLoad.compute(hrSamples).zoneTime;
      hasHr = 1;
    }

    final computedAt = DateTime.now().toUtc().toIso8601String();
    final existing = await _powerSync.getOptional(
      'SELECT id FROM run_computed_metrics WHERE id = ?',
      [runId],
    );
    if (existing != null) {
      await _powerSync.execute(
        'UPDATE run_computed_metrics'
        ' SET zone1_seconds = ?, zone2_seconds = ?, zone3_seconds = ?,'
        '     zone4_seconds = ?, zone5_seconds = ?,'
        '     has_hr_samples = ?, computed_at = ?'
        ' WHERE id = ?',
        [
          zone.zone1Seconds, zone.zone2Seconds, zone.zone3Seconds,
          zone.zone4Seconds, zone.zone5Seconds,
          hasHr, computedAt, runId,
        ],
      );
    } else {
      await _powerSync.execute(
        'INSERT INTO run_computed_metrics'
        '  (id, zone1_seconds, zone2_seconds, zone3_seconds,'
        '   zone4_seconds, zone5_seconds,'
        '   has_hr_samples, computed_at)'
        ' VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          runId,
          zone.zone1Seconds, zone.zone2Seconds, zone.zone3Seconds,
          zone.zone4Seconds, zone.zone5Seconds,
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
