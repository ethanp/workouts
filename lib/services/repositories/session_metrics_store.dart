import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/utils/training_load_calculator.dart';

final _log = Logger('SessionMetricsStore');

/// Manages the `session_computed_metrics` local-only table: computing, storing,
/// backfilling, and recomputing zone2/TRIMP for individual sessions.
class SessionMetricsStore {
  SessionMetricsStore(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<void> computeAndStore(
    String sessionId, {
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final List<TimestampedHeartRate> hrSamples =
        await loadHrSamples(sessionId);

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
      'SELECT id FROM session_computed_metrics WHERE id = ?',
      [sessionId],
    );
    if (metricsRow != null) {
      await _powerSync.execute(
        'UPDATE session_computed_metrics'
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
          sessionId,
        ],
      );
    } else {
      await _powerSync.execute(
        'INSERT INTO session_computed_metrics'
        '  (id, zone2_seconds, trimp, has_hr_samples,'
        '   zone2_hr_lower, zone2_hr_upper, resting_hr, computed_at)'
        ' VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          sessionId,
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
    final List<Map<String, dynamic>> sessionRows = await _powerSync.execute(
      "SELECT id FROM sessions WHERE completed_at IS NOT NULL"
      " ORDER BY started_at DESC",
    );
    _log.info(
      'Recomputing session zone 2 for ${sessionRows.length} sessions.',
    );
    for (var sessionIndex = 0;
        sessionIndex < sessionRows.length;
        sessionIndex++) {
      await _recomputeZone2Only(
        sessionRows[sessionIndex]['id'] as String,
        trainingLoad: trainingLoad,
      );
      onProgress?.call(sessionIndex + 1, sessionRows.length);
    }
    _log.info('Session zone 2 recompute complete.');
  }

  Future<void> backfillMissing({
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final List<Map<String, dynamic>> pendingRows =
        await _powerSync.execute('''
      SELECT s.id FROM sessions s
      LEFT JOIN session_computed_metrics m ON m.id = s.id
      WHERE s.completed_at IS NOT NULL
        AND (m.id IS NULL OR m.zone2_hr_lower IS NULL)
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

  /// Recomputes only zone2 for a single session, preserving existing
  /// TRIMP + resting_hr.
  Future<void> _recomputeZone2Only(
    String sessionId, {
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final List<TimestampedHeartRate> hrSamples =
        await loadHrSamples(sessionId);

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
      'SELECT id FROM session_computed_metrics WHERE id = ?',
      [sessionId],
    );
    if (metricsRow != null) {
      await _powerSync.execute(
        'UPDATE session_computed_metrics'
        ' SET zone2_seconds = ?, has_hr_samples = ?,'
        '     zone2_hr_lower = ?, zone2_hr_upper = ?, computed_at = ?'
        ' WHERE id = ?',
        [
          zone2Seconds,
          hasHrSamples,
          zone2Lower,
          zone2Upper,
          computedAt,
          sessionId,
        ],
      );
    } else {
      await _powerSync.execute(
        'INSERT INTO session_computed_metrics'
        '  (id, zone2_seconds, has_hr_samples,'
        '   zone2_hr_lower, zone2_hr_upper, computed_at)'
        ' VALUES (?, ?, ?, ?, ?, ?)',
        [
          sessionId,
          zone2Seconds,
          hasHrSamples,
          zone2Lower,
          zone2Upper,
          computedAt,
        ],
      );
    }
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
}
