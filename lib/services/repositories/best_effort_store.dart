import 'package:ethan_utils/ethan_utils.dart';

import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/utils/best_effort_calculator.dart';

const _log = ELogger('BestEffortStore');
const _uuid = Uuid();

/// Computes and stores best-effort times for a single workout across fixed
/// distance buckets in `cardio_best_efforts`.
///
/// Entries are keyed by `workout_id` + `distance_meters`; workout modality
/// (for example, run vs bike) is derived from the parent workout record.
class BestEffortStore {
  BestEffortStore(this._powerSync);

  final PowerSyncDatabase _powerSync;
  final _calculator = BestEffortCalculator();

  Future<void> computeAndStore(String workoutId) async {
    final routePoints = await _loadRoutePoints(workoutId);
    if (routePoints.length < 2) return;

    final bestEfforts = _calculator.compute(routePoints);
    if (bestEfforts.isEmpty) return;

    _log.fine('Storing ${bestEfforts.length} best efforts for $workoutId.');
    for (final effort in bestEfforts) {
      await _upsert(workoutId, effort.bucket.meters, effort.elapsedSeconds);
    }
  }

  Future<void> backfillAll({
    void Function(int done, int total)? onProgress,
  }) async {
    final pendingRows = await _powerSync.execute('''
      SELECT w.id FROM cardio_workouts w
      WHERE w.route_available = 1
        AND NOT EXISTS (
          SELECT 1 FROM cardio_best_efforts be WHERE be.workout_id = w.id
        )
    ''');
    if (pendingRows.isEmpty) return;
    _log.log('Backfilling best efforts for ${pendingRows.length} workouts.');
    for (var workoutIndex = 0; workoutIndex < pendingRows.length; workoutIndex++) {
      await computeAndStore(pendingRows[workoutIndex]['id'] as String);
      onProgress?.call(workoutIndex + 1, pendingRows.length);
    }
    _log.log('Best effort backfill complete.');
  }

  Future<List<CardioRoutePoint>> _loadRoutePoints(String workoutId) async {
    final routePointRows = await _powerSync.execute(
      'SELECT * FROM cardio_route_points WHERE workout_id = ? ORDER BY point_index ASC',
      [workoutId],
    );
    return routePointRows.mapL(CardioRoutePoint.fromRow);
  }

  Future<void> _upsert(
    String workoutId,
    double distanceMeters,
    double elapsedSeconds,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _powerSync.writeTransaction((transaction) async {
      await transaction.execute(
        'DELETE FROM cardio_best_efforts'
        ' WHERE workout_id = ? AND distance_meters = ?',
        [workoutId, distanceMeters],
      );
      await transaction.execute(
        'INSERT INTO cardio_best_efforts'
        ' (id, workout_id, distance_meters, elapsed_seconds, created_at, updated_at)'
        ' VALUES (?, ?, ?, ?, ?, ?)',
        [_uuid.v4(), workoutId, distanceMeters, elapsedSeconds, now, now],
      );
    });
  }
}
