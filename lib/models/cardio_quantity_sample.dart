import 'package:workouts/models/cardio_best_effort.dart';
import 'package:workouts/models/distance_bucket.dart';

class const CardioQuantitySample({
  required final String id,
  required final String workoutId,
  required final DateTime startedAt,
  required final DateTime endedAt,
  required final double value,
}) {
  factory fromRow(Map<String, dynamic> sampleRow) {
    return CardioQuantitySample(
      id: sampleRow['id'] as String,
      workoutId: sampleRow['workout_id'] as String,
      startedAt: DateTime.parse(sampleRow['started_at'] as String),
      endedAt: DateTime.parse(sampleRow['ended_at'] as String),
      value: _asDouble(sampleRow['value']) ?? 0,
    );
  }

  Duration get interval => endedAt.difference(startedAt);
}

extension DistanceSampleBestEfforts on List<CardioQuantitySample> {
  List<CardioBestEffort> get bestEfforts =>
      _DistanceTimelineBestEfforts(this).compute();
}

class _DistanceTimelineBestEfforts {
  const _DistanceTimelineBestEfforts(this.distanceSamples);

  final List<CardioQuantitySample> distanceSamples;

  List<CardioBestEffort> compute() {
    final timeline = _cumulativeTimeline();
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

  List<_DistanceMark> _cumulativeTimeline() {
    final ordered = [...distanceSamples]
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

double? _asDouble(Object? rawValue) {
  if (rawValue == null) return null;
  if (rawValue is num) return rawValue.toDouble();
  return double.tryParse('$rawValue');
}
