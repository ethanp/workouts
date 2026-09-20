import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/cardio_quantity_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';

/// GPS / HR / distance for one cardio session, loaded from Apple Health
/// when the detail screen opens. Not stored in PowerSync.
class const CardioWorkoutSeries({
  required final List<CardioRoutePoint> routePoints,
  required final List<CardioHeartRateSample> heartRateSamples,
  required final List<CardioQuantitySample> distanceSamples,
}) {
  static const empty = CardioWorkoutSeries(
    routePoints: [],
    heartRateSamples: [],
    distanceSamples: [],
  );
}
