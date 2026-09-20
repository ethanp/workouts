import 'package:ethan_utils/ethan_utils.dart';

import 'package:powersync/powersync.dart';
import 'package:powersync/sqlite_async.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/cardio_best_effort.dart';
import 'package:workouts/models/cardio_quantity_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/models/cardio_workout_series.dart';
import 'package:workouts/models/distance_bucket.dart';

const _log = ELogger('BestEffortStore');
const _uuid = Uuid();
final _bestEffortIdNamespace = Namespace.url.value;

/// Matches [DistanceBucket.fromMeters] so a downloaded double still finds the
/// local bucket row.
const _bucketMetersTolerance = 0.01;

/// Computes and stores best-effort times for a single workout across fixed
/// distance buckets in `cardio_best_efforts`.
///
/// Entries are keyed by `workout_id` + `distance_meters`; workout modality
/// (for example, run vs bike) is derived from the parent workout record.
/// Recompute updates the existing row in place so PowerSync does not queue
/// a new UUID that collides on that unique pair during upload.
class BestEffortStore(final PowerSyncDatabase _powerSync) {
  Future<void> computeFromSeries(
    String workoutId,
    CardioWorkoutSeries series,
  ) async {
    final bestEfforts = series.routePoints.length >= 2
        ? series.routePoints.bestEfforts
        : series.distanceSamples.bestEfforts;
    if (bestEfforts.isEmpty) return;

    _log.fine('Storing ${bestEfforts.length} best efforts for $workoutId.');
    final now = DateTime.now().toUtc().toIso8601String();
    await _powerSync.writeTransaction((transaction) async {
      for (final effort in bestEfforts) {
        await _writeEffort(transaction, workoutId, effort, now);
      }
    });
  }

  Future<void> _writeEffort(
    SqliteWriteContext transaction,
    String workoutId,
    CardioBestEffort effort,
    String now,
  ) async {
    final existingRows = await transaction.getAll(
      'SELECT id, elapsed_seconds FROM cardio_best_efforts'
      ' WHERE workout_id = ? AND ABS(distance_meters - ?) < ?',
      [workoutId, effort.bucket.meters, _bucketMetersTolerance],
    );
    if (existingRows.isEmpty) {
      await transaction.execute(
        'INSERT INTO cardio_best_efforts'
        ' (id, workout_id, distance_meters, elapsed_seconds, created_at, updated_at)'
        ' VALUES (?, ?, ?, ?, ?, ?)',
        [
          _idFor(workoutId, effort.bucket),
          workoutId,
          effort.bucket.meters,
          effort.elapsedSeconds,
          now,
          now,
        ],
      );
      return;
    }
    await _updateKeptEffort(transaction, existingRows, effort.elapsedSeconds, now);
  }

  Future<void> _updateKeptEffort(
    SqliteWriteContext transaction,
    List<Map<String, dynamic>> existingRows,
    double elapsedSeconds,
    String now,
  ) async {
    final kept = existingRows.first;
    final storedSeconds = (kept['elapsed_seconds'] as num).toDouble();
    if (storedSeconds != elapsedSeconds) {
      await transaction.execute(
        'UPDATE cardio_best_efforts'
        ' SET elapsed_seconds = ?, updated_at = ? WHERE id = ?',
        [elapsedSeconds, now, kept['id']],
      );
    }
    for (final extra in existingRows.skip(1)) {
      await transaction.execute(
        'DELETE FROM cardio_best_efforts WHERE id = ?',
        [extra['id']],
      );
    }
  }

  static String _idFor(String workoutId, DistanceBucket bucket) => _uuid.v5(
    _bestEffortIdNamespace,
    'cardio-best-effort:$workoutId:${bucket.name}',
  );
}
