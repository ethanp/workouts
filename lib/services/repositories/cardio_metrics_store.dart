import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/services/powersync/powersync_extensions.dart';
import 'package:workouts/utils/hr_zone_classifier.dart';

const _log = ELogger('CardioMetricsStore');

/// Workouts that still need zone metrics: no row yet, an incomplete row, or a
/// stale empty row written before HR samples landed (import/backfill race).
const _needsMetricsSql = '''
  m.id IS NULL
  OR m.zone1_seconds IS NULL
  OR (
    COALESCE(m.has_hr_samples, 0) = 0
    AND EXISTS (
      SELECT 1 FROM cardio_heart_rate_samples sample
      WHERE sample.workout_id = w.id
      LIMIT 1
    )
  )
''';

/// Manages the `cardio_computed_metrics` local-only table: computing,
/// storing, backfilling, and recomputing zone times for individual workouts.
class CardioMetricsStore {
  CardioMetricsStore(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<void> computeAndStore(String workoutId) async {
    final hrSamples = await loadHrSamples(workoutId);
    if (hrSamples.isEmpty) {
      // Don't clobber a good metrics row with an empty one — import can race
      // with backfill, which may load samples before they've been written.
      if (await _hasComputedHrSamples(workoutId)) return;
      await _persist(workoutId, HrZoneTime.zero, hasHrSamples: false);
      return;
    }
    await _persist(
      workoutId,
      HrZoneClassifier.compute(hrSamples),
      hasHrSamples: true,
    );
  }

  Future<void> recomputeAllZones({
    void Function(int done, int total)? onProgress,
  }) async {
    final List<Map<String, dynamic>> workoutRows = await _powerSync.execute(
      'SELECT id FROM cardio_workouts ORDER BY started_at DESC',
    );
    _log.log('Recomputing zones for ${workoutRows.length} workouts.');
    for (var index = 0; index < workoutRows.length; index++) {
      await computeAndStore(workoutRows[index]['id'] as String);
      onProgress?.call(index + 1, workoutRows.length);
    }
    _log.log('Zone recompute complete.');
  }

  Future<void> backfillMissing() async {
    final List<Map<String, dynamic>> pendingRows = await _missingRows();
    if (pendingRows.isEmpty) return;

    _log.log(
      'Computing missing cardio metrics for ${pendingRows.length} workouts...',
    );
    for (final pendingRow in pendingRows) {
      await computeAndStore(pendingRow['id'] as String);
    }
    _log.log('Cardio metrics computed for ${pendingRows.length} workouts.');
  }

  /// Streams the number of cardio workouts that have no computed zone metrics
  /// yet. Drives the "compute missing zones" UI affordance.
  Stream<int> watchMissingCount() => _powerSync
      .watch('''
        SELECT COUNT(*) AS cnt FROM cardio_workouts w
        LEFT JOIN cardio_computed_metrics m ON m.id = w.id
        WHERE $_needsMetricsSql
      ''')
      .map((rows) => (rows.first['cnt'] as int?) ?? 0);

  Future<List<Map<String, dynamic>>> _missingRows() => _powerSync.execute('''
        SELECT w.id FROM cardio_workouts w
        LEFT JOIN cardio_computed_metrics m ON m.id = w.id
        WHERE $_needsMetricsSql
      ''');

  Future<bool> _hasComputedHrSamples(String workoutId) async {
    final Map<String, dynamic>? metricsRow = await _powerSync.getOptional(
      'SELECT has_hr_samples FROM cardio_computed_metrics WHERE id = ?',
      [workoutId],
    );
    return (metricsRow?['has_hr_samples'] as int?) == 1;
  }

  Future<List<TimestampedHeartRate>> loadHrSamples(String workoutId) async {
    final List<Map<String, dynamic>> sampleRows = await _powerSync.execute(
      'SELECT timestamp, bpm FROM cardio_heart_rate_samples'
      ' WHERE workout_id = ? ORDER BY timestamp ASC',
      [workoutId],
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

  Future<void> _persist(
    String workoutId,
    HrZoneTime zone, {
    required bool hasHrSamples,
  }) async {
    final computedAt = DateTime.now().toUtc().toIso8601String();
    await _powerSync.upsert('cardio_computed_metrics', {
      'id': workoutId,
      ...zone.toRow(),
      'has_hr_samples': hasHrSamples ? 1 : 0,
      'computed_at': computedAt,
    });
  }
}
