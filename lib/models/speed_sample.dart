import 'package:ethan_utils/ethan_utils.dart';
import 'package:workouts/models/cardio_route_point.dart';

class const SpeedSample({
  required final DateTime timestamp,
  required final double speedKmh,
}) {
  static List<SpeedSample> fromRoutePoints(List<CardioRoutePoint> points) {
    final timedPoints = points.whereL(
      (routePoint) => routePoint.recordedAt != null,
    )..sortOn((routePoint) => routePoint.recordedAt!);

    if (timedPoints.length < 2) return [];

    const maxReasonableSpeedKmh = 35.0;
    final rawSamples = <SpeedSample>[];

    for (var pointIndex = 1; pointIndex < timedPoints.length; pointIndex++) {
      final previousPoint = timedPoints[pointIndex - 1];
      final currentPoint = timedPoints[pointIndex];
      final timeDeltaSeconds =
          currentPoint.recordedAt!
              .difference(previousPoint.recordedAt!)
              .inMilliseconds /
          1000.0;
      if (timeDeltaSeconds <= 0) continue;

      final distanceMeters = previousPoint.metersTo(currentPoint);
      final speedKmh = (distanceMeters / timeDeltaSeconds) * 3.6;
      if (speedKmh > maxReasonableSpeedKmh) continue;

      final midMs =
          currentPoint.recordedAt!
              .difference(previousPoint.recordedAt!)
              .inMilliseconds ~/
          2;
      final midTime = previousPoint.recordedAt!.add(
        Duration(milliseconds: midMs),
      );
      rawSamples.add(SpeedSample(timestamp: midTime, speedKmh: speedKmh));
    }

    return _rollingAverage(rawSamples, windowSize: 9);
  }

  static List<SpeedSample> _rollingAverage(
    List<SpeedSample> samples, {
    required int windowSize,
  }) {
    if (samples.length <= windowSize) return samples;
    final half = windowSize ~/ 2;
    return List.generate(samples.length, (sampleIndex) {
      final start = (sampleIndex - half).clamp(0, samples.length - 1);
      final end = (sampleIndex + half + 1).clamp(0, samples.length);
      final window = samples.sublist(start, end);
      final averageSpeed =
          window
              .map((speedSample) => speedSample.speedKmh)
              .reduce((firstSpeed, secondSpeed) => firstSpeed + secondSpeed) /
          window.length;
      return SpeedSample(
        timestamp: samples[sampleIndex].timestamp,
        speedKmh: averageSpeed,
      );
    });
  }
}
