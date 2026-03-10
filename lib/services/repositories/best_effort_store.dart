import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/utils/best_effort_calculator.dart';

final _log = Logger('BestEffortStore');
const _uuid = Uuid();

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
    _log.info('Backfilling best efforts for ${pendingRows.length} workouts.');
    for (var i = 0; i < pendingRows.length; i++) {
      await computeAndStore(pendingRows[i]['id'] as String);
      onProgress?.call(i + 1, pendingRows.length);
    }
    _log.info('Best effort backfill complete.');
  }

  Future<List<CardioRoutePoint>> _loadRoutePoints(String workoutId) async {
    final rows = await _powerSync.execute(
      'SELECT * FROM cardio_route_points WHERE workout_id = ? ORDER BY point_index ASC',
      [workoutId],
    );
    return rows.map(_routePointFromRow).toList();
  }

  Future<void> _upsert(
    String workoutId,
    double distanceMeters,
    double elapsedSeconds,
  ) async {
    final existing = await _powerSync.getOptional(
      'SELECT id FROM cardio_best_efforts WHERE workout_id = ? AND distance_meters = ?',
      [workoutId, distanceMeters],
    );
    final now = DateTime.now().toUtc().toIso8601String();
    if (existing != null) {
      await _powerSync.execute(
        'UPDATE cardio_best_efforts SET elapsed_seconds = ?, updated_at = ? WHERE id = ?',
        [elapsedSeconds, now, existing['id']],
      );
    } else {
      await _powerSync.execute(
        'INSERT INTO cardio_best_efforts (id, workout_id, distance_meters, elapsed_seconds, created_at, updated_at)'
        ' VALUES (?, ?, ?, ?, ?, ?)',
        [_uuid.v4(), workoutId, distanceMeters, elapsedSeconds, now, now],
      );
    }
  }

  CardioRoutePoint _routePointFromRow(Map<String, dynamic> row) {
    return CardioRoutePoint(
      id: row['id'] as String,
      workoutId: row['workout_id'] as String,
      pointIndex: (row['point_index'] as int?) ?? 0,
      latitude: _asDouble(row['lat']) ?? 0,
      longitude: _asDouble(row['lng']) ?? 0,
      altitudeMeters: _asDouble(row['altitude_meters']),
      recordedAt: _asDateTime(row['timestamp']),
    );
  }
}

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

DateTime? _asDateTime(Object? value) {
  final string = value as String?;
  return string == null ? null : DateTime.tryParse(string);
}
