import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/services/powersync/powersync_extensions.dart';
import 'package:workouts/utils/training_load_calculator.dart';

final _log = Logger('CardioMetricsStore');

/// Manages the `cardio_computed_metrics` local-only table: computing, storing,
/// backfilling, and recomputing zone times and TRIMP for individual workouts.
class CardioMetricsStore {
  CardioMetricsStore(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<void> computeAndStore(
    String workoutId, {
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final result =
        await _loadAndCompute(workoutId, trainingLoad: trainingLoad);
    await _persistMetrics(workoutId, result,
        restingHr: trainingLoad.restingHeartRate);
  }

  Future<void> recomputeAllZones({
    required TrainingLoadCalculator trainingLoad,
    void Function(int done, int total)? onProgress,
  }) async {
    final List<Map<String, dynamic>> workoutRows = await _powerSync.execute(
      'SELECT id FROM cardio_workouts ORDER BY started_at DESC',
    );
    _log.info('Recomputing zones for ${workoutRows.length} workouts.');
    for (var index = 0; index < workoutRows.length; index++) {
      await _recomputeZones(
        workoutRows[index]['id'] as String,
        trainingLoad: trainingLoad,
      );
      onProgress?.call(index + 1, workoutRows.length);
    }
    _log.info('Zone recompute complete.');
  }

  Future<void> backfillMissing({
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final List<Map<String, dynamic>> pendingRows =
        await _powerSync.execute('''
      SELECT w.id FROM cardio_workouts w
      LEFT JOIN cardio_computed_metrics m ON m.id = w.id
      WHERE m.id IS NULL OR m.zone1_seconds IS NULL
    ''');
    if (pendingRows.isEmpty) return;
    _log.info('Backfilling metrics for ${pendingRows.length} workouts.');
    for (final pendingRow in pendingRows) {
      await computeAndStore(
        pendingRow['id'] as String,
        trainingLoad: trainingLoad,
      );
    }
    _log.info('Backfill complete.');
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

  Future<_ComputedMetrics> _loadAndCompute(
    String workoutId, {
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final hrSamples = await loadHrSamples(workoutId);
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
    String workoutId,
    _ComputedMetrics metrics, {
    required int restingHr,
  }) async {
    final zone = metrics.result.zoneTime;
    final computedAt = DateTime.now().toUtc().toIso8601String();
    final hasHr = metrics.hasHrSamples ? 1 : 0;

    await _powerSync.upsert('cardio_computed_metrics', {
      'id': workoutId,
      ...zone.toRow(),
      'trimp': metrics.result.trimp,
      'has_hr_samples': hasHr,
      'resting_hr': restingHr,
      'computed_at': computedAt,
    });
  }

  Future<void> _recomputeZones(
    String workoutId, {
    required TrainingLoadCalculator trainingLoad,
  }) async {
    final hrSamples = await loadHrSamples(workoutId);

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
    await _powerSync.upsert('cardio_computed_metrics', {
      'id': workoutId,
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
