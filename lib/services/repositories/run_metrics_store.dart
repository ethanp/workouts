import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/utils/training_load_calculator.dart';

final _log = Logger('RunMetricsStore');

/// Manages the `run_computed_metrics` local-only table: computing, storing,
/// backfilling, and recomputing zone2/TRIMP for individual runs.
class RunMetricsStore {
  RunMetricsStore(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<void> computeAndStore(
    String runId, {
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final List<TimestampedHeartRate> hrSamples = await loadHrSamples(runId);

    final int zone2Seconds;
    final double trimp;
    final int hasHrSamples;
    final int? zone2Lower;
    final int? zone2Upper;

    if (hrSamples.isEmpty) {
      zone2Seconds = 0;
      trimp = 0;
      hasHrSamples = 0;
      zone2Lower = null;
      zone2Upper = null;
    } else {
      final TrainingLoadResult loadResult = trainingLoad.compute(hrSamples);
      zone2Seconds = loadResult.zone2Seconds;
      trimp = loadResult.trimp;
      hasHrSamples = 1;
      zone2Lower = trainingLoad.zone2Lower;
      zone2Upper = trainingLoad.zone2Upper;
    }

    final String computedAt = DateTime.now().toUtc().toIso8601String();
    final Map<String, dynamic>? metricsRow = await _powerSync.getOptional(
      'SELECT id FROM run_computed_metrics WHERE id = ?',
      [runId],
    );
    if (metricsRow != null) {
      await _powerSync.execute(
        'UPDATE run_computed_metrics'
        ' SET zone2_seconds = ?, trimp = ?, has_hr_samples = ?,'
        '     zone2_hr_lower = ?, zone2_hr_upper = ?,'
        '     resting_hr = ?, computed_at = ?'
        ' WHERE id = ?',
        [
          zone2Seconds,
          trimp,
          hasHrSamples,
          zone2Lower,
          zone2Upper,
          trainingLoad.restingHeartRate,
          computedAt,
          runId,
        ],
      );
    } else {
      await _powerSync.execute(
        'INSERT INTO run_computed_metrics'
        '  (id, zone2_seconds, trimp, has_hr_samples,'
        '   zone2_hr_lower, zone2_hr_upper, resting_hr, computed_at)'
        ' VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          runId,
          zone2Seconds,
          trimp,
          hasHrSamples,
          zone2Lower,
          zone2Upper,
          trainingLoad.restingHeartRate,
          computedAt,
        ],
      );
    }
  }

  Future<void> recomputeAllZone2({
    required TrainingLoadCalculator trainingLoad,
    void Function(int done, int total)? onProgress,
  }) async {
    final List<Map<String, dynamic>> runRows = await _powerSync.execute(
      'SELECT id FROM runs ORDER BY started_at DESC',
    );
    _log.info('Recomputing zone 2 for ${runRows.length} runs.');
    for (var runIndex = 0; runIndex < runRows.length; runIndex++) {
      await _recomputeZone2Only(
        runRows[runIndex]['id'] as String,
        trainingLoad: trainingLoad,
      );
      onProgress?.call(runIndex + 1, runRows.length);
    }
    _log.info('Zone 2 recompute complete.');
  }

  Future<void> backfillMissing({
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final List<Map<String, dynamic>> pendingRows = await _powerSync.execute('''
      SELECT r.id FROM runs r
      LEFT JOIN run_computed_metrics m ON m.id = r.id
      WHERE m.id IS NULL OR m.zone2_hr_lower IS NULL
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

  /// Recomputes only zone2 for a single run, preserving existing TRIMP + resting_hr.
  Future<void> _recomputeZone2Only(
    String runId, {
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final List<TimestampedHeartRate> hrSamples = await loadHrSamples(runId);

    final int zone2Seconds;
    final int hasHrSamples;
    final int? zone2Lower;
    final int? zone2Upper;

    if (hrSamples.isEmpty) {
      zone2Seconds = 0;
      hasHrSamples = 0;
      zone2Lower = null;
      zone2Upper = null;
    } else {
      final TrainingLoadResult loadResult = trainingLoad.compute(hrSamples);
      zone2Seconds = loadResult.zone2Seconds;
      hasHrSamples = 1;
      zone2Lower = trainingLoad.zone2Lower;
      zone2Upper = trainingLoad.zone2Upper;
    }

    final String computedAt = DateTime.now().toUtc().toIso8601String();
    final Map<String, dynamic>? metricsRow = await _powerSync.getOptional(
      'SELECT id FROM run_computed_metrics WHERE id = ?',
      [runId],
    );
    if (metricsRow != null) {
      await _powerSync.execute(
        'UPDATE run_computed_metrics'
        ' SET zone2_seconds = ?, has_hr_samples = ?,'
        '     zone2_hr_lower = ?, zone2_hr_upper = ?, computed_at = ?'
        ' WHERE id = ?',
        [zone2Seconds, hasHrSamples, zone2Lower, zone2Upper, computedAt, runId],
      );
    } else {
      await _powerSync.execute(
        'INSERT INTO run_computed_metrics'
        '  (id, zone2_seconds, has_hr_samples,'
        '   zone2_hr_lower, zone2_hr_upper, computed_at)'
        ' VALUES (?, ?, ?, ?, ?, ?)',
        [runId, zone2Seconds, hasHrSamples, zone2Lower, zone2Upper, computedAt],
      );
    }
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
}
