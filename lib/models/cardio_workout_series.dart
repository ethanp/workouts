import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/cardio_quantity_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';

/// GPS / HR / distance for one cardio session when the detail screen opens.
/// GPS points are stored per workout in Postgres and are not part of the
/// PowerSync bucket.
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
