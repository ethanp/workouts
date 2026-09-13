import 'package:workouts/models/cardio_best_effort.dart';
import 'package:workouts/models/cardio_quantity_sample.dart';
import 'package:workouts/utils/run_formatting.dart';

class DistanceTimelineBestEffortCalculator() {
  List<CardioBestEffort> compute(List<CardioQuantitySample> distanceSamples) {
    final timeline = _cumulativeTimeline(distanceSamples);
    if (timeline.length < 2) return const [];
    final totalDistance = timeline.last.meters;
    final bestEfforts = <CardioBestEffort>[];
    for (final bucket in DistanceBucket.values) {
      if (totalDistance < bucket.meters) continue;
      final elapsedSeconds = _fastestWindow(timeline, bucket.meters);
      if (elapsedSeconds == null) continue;
      bestEfforts.add(
        CardioBestEffort(bucket: bucket, elapsedSeconds: elapsedSeconds),
      );
    }
    return bestEfforts;
  }

  List<_DistanceMark> _cumulativeTimeline(List<CardioQuantitySample> samples) {
    final ordered = [...samples]
      ..sort((left, right) => left.startedAt.compareTo(right.startedAt));
    final marks = <_DistanceMark>[];
    var cumulativeMeters = 0.0;
    for (final sample in ordered) {
      if (sample.value <= 0) continue;
      if (marks.isEmpty) {
        marks.add(_DistanceMark(at: sample.startedAt, meters: 0));
      }
      cumulativeMeters += sample.value;
      marks.add(_DistanceMark(at: sample.endedAt, meters: cumulativeMeters));
    }
    return marks;
  }

  double? _fastestWindow(List<_DistanceMark> marks, double targetMeters) {
    double? bestSeconds;
    var start = 0;
    for (var end = 1; end < marks.length; end++) {
      while (marks[end].meters - marks[start + 1].meters >= targetMeters) {
        start++;
      }
      final windowDistance = marks[end].meters - marks[start].meters;
      if (windowDistance < targetMeters) continue;
      final windowSeconds =
          marks[end].at.difference(marks[start].at).inMilliseconds / 1000.0;
      if (windowSeconds <= 0) continue;
      if (bestSeconds == null || windowSeconds < bestSeconds) {
        bestSeconds = windowSeconds;
      }
    }
    return bestSeconds;
  }
}

class const _DistanceMark({
  required final DateTime at,
  required final double meters,
});
