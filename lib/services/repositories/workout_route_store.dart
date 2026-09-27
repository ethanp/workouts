import 'package:powersync/powersync.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/services/health_kit_bridge.dart';
import 'package:workouts/services/repositories/cardio_metrics_store.dart';
import 'package:workouts/services/repositories/stored_workout_route.dart';

class const RouteStoreOutcome({
  required final int stored,
  required final int alreadyStored,
  required final int withoutGps,
  required final int failed,
});

/// Writes each outdoor workout's GPS to Postgres, one workout at a time.
///
/// Routes stay out of the PowerSync bucket. A workout that already has a
/// stored first point is left alone.
class WorkoutRouteStore({
  required final PowerSyncDatabase powerSync,
  required final HealthKitBridge healthKit,
  required final String postgrestUrl,
}) {
  late final StoredWorkoutRoute _storedRoute = StoredWorkoutRoute(postgrestUrl);

  Future<RouteStoreOutcome> storeMissing({
    void Function(int done, int total)? onProgress,
  }) async {
    final workoutRows = await powerSync.getAll('''
      SELECT id, external_workout_id, activity_type
      FROM cardio_workouts w
      WHERE ${CardioMetricsStore.workoutsSinceFirstDayWhere}
      ORDER BY w.started_at DESC
    ''');
    final routeWorkouts = [
      for (final workoutRow in workoutRows)
        if (CardioType.fromDbKey(workoutRow['activity_type'] as String)
            .hasRoute)
          workoutRow,
    ];
    final alreadyStoredIds = await _storedRoute.idsWithAFirstPoint();
    final missing = [
      for (final workoutRow in routeWorkouts)
        if (!alreadyStoredIds.contains(workoutRow['id'] as String)) workoutRow,
    ];
    var stored = 0;
    var withoutGps = 0;
    var failed = 0;
    for (var index = 0; index < missing.length; index++) {
      final workoutRow = missing[index];
      final workoutId = workoutRow['id'] as String;
      try {
        final series = await healthKit.fetchCardioWorkoutSeries(
          workoutId: workoutId,
          externalWorkoutId: workoutRow['external_workout_id'] as String,
        );
        if (series.routePoints.length < 2) {
          withoutGps++;
        } else if (await _storedRoute.replace(workoutId, series.routePoints)) {
          stored++;
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
      onProgress?.call(index + 1, missing.length);
    }
    return RouteStoreOutcome(
      stored: stored,
      alreadyStored: routeWorkouts.length - missing.length,
      withoutGps: withoutGps,
      failed: failed,
    );
  }
}
