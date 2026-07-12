import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/utils/hr_zone_classifier.dart';

const _log = ELogger('SessionMetricsStore');

/// Manages the `session_computed_metrics` local-only table: computing,
/// storing, backfilling, and recomputing zone times for individual sessions.
class SessionMetricsStore {
  SessionMetricsStore(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<void> computeAndStore(String sessionId) async {
    final hrSamples = await loadHrSamples(sessionId);
    final HrZoneTime zone;
    final bool hasHrSamples;
    if (hrSamples.isEmpty) {
      zone = HrZoneTime.zero;
      hasHrSamples = false;
    } else {
      zone = HrZoneClassifier.compute(hrSamples);
      hasHrSamples = true;
    }
    await _persist(sessionId, zone, hasHrSamples: hasHrSamples);
  }

  Future<void> recomputeAllZones({
    void Function(int done, int total)? onProgress,
  }) async {
    final List<Map<String, dynamic>> sessionRows = await _powerSync.execute(
      "SELECT id FROM sessions WHERE completed_at IS NOT NULL"
      " ORDER BY started_at DESC",
    );
    _log.log('Recomputing session zones for ${sessionRows.length} sessions.');
    for (
      var sessionIndex = 0;
      sessionIndex < sessionRows.length;
      sessionIndex++
    ) {
      await computeAndStore(sessionRows[sessionIndex]['id'] as String);
      onProgress?.call(sessionIndex + 1, sessionRows.length);
    }
    _log.log('Session zone recompute complete.');
  }

  Future<void> backfillMissing() async {
    final List<Map<String, dynamic>> pendingRows = await _powerSync.execute('''
      SELECT s.id FROM sessions s
      LEFT JOIN session_computed_metrics m ON m.id = s.id
      WHERE s.completed_at IS NOT NULL
        AND (m.id IS NULL OR m.zone1_seconds IS NULL)
    ''');
    if (pendingRows.isEmpty) return;
    _log.log('Backfilling session metrics for ${pendingRows.length} sessions.');
    for (final pendingRow in pendingRows) {
      await computeAndStore(pendingRow['id'] as String);
    }
    _log.log('Session metrics backfill complete.');
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

  Future<void> _persist(
    String sessionId,
    HrZoneTime zone, {
    required bool hasHrSamples,
  }) async {
    final computedAt = DateTime.now().toUtc().toIso8601String();
    await _powerSync.upsert('session_computed_metrics', {
      'id': sessionId,
      ...zone.toRow(),
      'has_hr_samples': hasHrSamples ? 1 : 0,
      'computed_at': computedAt,
    });
  }
}
