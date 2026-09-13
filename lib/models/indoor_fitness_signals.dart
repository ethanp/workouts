import 'package:workouts/models/cardio_quantity_sample.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/distance_bucket.dart';
import 'package:workouts/models/distance_origin.dart';
import 'package:workouts/models/fitness_signal_confidence.dart';
import 'package:workouts/models/timestamped_heart_rate.dart';

class const IndoorFitnessSignals({
  required final double? paceSecondsPerMile,
  required final double? metersPerHeartbeat,
  required final double? cardiacDriftPercent,
  required final bool hasDistanceSamples,
  required final DistanceOrigin distanceOrigin,
  required final FitnessSignalConfidence confidence,
}) {
  static const empty = IndoorFitnessSignals(
    paceSecondsPerMile: null,
    metersPerHeartbeat: null,
    cardiacDriftPercent: null,
    hasDistanceSamples: false,
    distanceOrigin: DistanceOrigin.unknown,
    confidence: FitnessSignalConfidence.insufficient,
  );
}

extension CardioWorkoutFitnessSignals on CardioWorkout {
  IndoorFitnessSignals fitnessSignals({
    required List<TimestampedHeartRate> heartRateSamples,
    required List<CardioQuantitySample> distanceSamples,
  }) => _IndoorFitness(
    workout: this,
    heartRateSamples: heartRateSamples,
    distanceSamples: distanceSamples,
  ).compute();
}

class _IndoorFitness {
  const _IndoorFitness({
    required this.workout,
    required this.heartRateSamples,
    required this.distanceSamples,
  });

  static const minDriftDuration = Duration(minutes: 20);
  static const minHalfSampleCount = 8;

  final CardioWorkout workout;
  final List<TimestampedHeartRate> heartRateSamples;
  final List<CardioQuantitySample> distanceSamples;

  IndoorFitnessSignals compute() {
    final cardiacDriftPercent = _cardiacDriftPercent();
    return IndoorFitnessSignals(
      paceSecondsPerMile: _paceSecondsPerMile(),
      metersPerHeartbeat: _metersPerHeartbeat(),
      cardiacDriftPercent: cardiacDriftPercent,
      hasDistanceSamples: distanceSamples.isNotEmpty,
      distanceOrigin: workout.machineLinked
          ? DistanceOrigin.machineLinked
          : DistanceOrigin.watchEstimated,
      confidence: _confidence(hasDrift: cardiacDriftPercent != null),
    );
  }

  double? _paceSecondsPerMile() {
    if (workout.durationSeconds <= 0 || workout.distanceMeters <= 0) {
      return null;
    }
    return workout.durationSeconds / (workout.distanceMeters / metersPerMile);
  }

  double? _metersPerHeartbeat() {
    if (workout.distanceMeters <= 0 || heartRateSamples.length < 2) {
      return null;
    }
    final totalBeats = _integratedBeats();
    if (totalBeats <= 0) return null;
    return workout.distanceMeters / totalBeats;
  }

  double _integratedBeats() {
    var totalBeats = 0.0;
    for (var index = 1; index < heartRateSamples.length; index++) {
      final elapsedMinutes = heartRateSamples[index].timestamp
              .difference(heartRateSamples[index - 1].timestamp)
              .inMilliseconds /
          60000.0;
      if (elapsedMinutes <= 0) continue;
      totalBeats += heartRateSamples[index - 1].bpm * elapsedMinutes;
    }
    return totalBeats;
  }

  double? _cardiacDriftPercent() {
    if (workout.durationSeconds < minDriftDuration.inSeconds) return null;
    if (heartRateSamples.length < minHalfSampleCount * 2) return null;
    final midpoint = heartRateSamples.first.timestamp.add(
      Duration(seconds: workout.durationSeconds ~/ 2),
    );
    final firstHalf = heartRateSamples
        .where((sample) => !sample.timestamp.isAfter(midpoint))
        .toList();
    final secondHalf = heartRateSamples
        .where((sample) => sample.timestamp.isAfter(midpoint))
        .toList();
    if (firstHalf.length < minHalfSampleCount) return null;
    if (secondHalf.length < minHalfSampleCount) return null;
    final firstAverage = _averageBpm(firstHalf);
    final secondAverage = _averageBpm(secondHalf);
    if (firstAverage <= 0) return null;
    return ((secondAverage - firstAverage) / firstAverage) * 100;
  }

  double _averageBpm(List<TimestampedHeartRate> samples) {
    var total = 0;
    for (final sample in samples) {
      total += sample.bpm;
    }
    return total / samples.length;
  }

  FitnessSignalConfidence _confidence({required bool hasDrift}) {
    final hasDistance =
        workout.distanceMeters > 0 || distanceSamples.isNotEmpty;
    if (heartRateSamples.length < minHalfSampleCount || !hasDistance) {
      return FitnessSignalConfidence.insufficient;
    }
    if (hasDrift &&
        workout.machineLinked &&
        workout.durationSeconds >= minDriftDuration.inSeconds) {
      return FitnessSignalConfidence.high;
    }
    if (hasDrift || workout.machineLinked) {
      return FitnessSignalConfidence.medium;
    }
    return FitnessSignalConfidence.low;
  }
}
