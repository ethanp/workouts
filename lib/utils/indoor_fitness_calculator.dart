import 'package:workouts/models/cardio_quantity_sample.dart';
import 'package:workouts/models/distance_origin.dart';
import 'package:workouts/models/fitness_signal_confidence.dart';
import 'package:workouts/utils/hr_zone_classifier.dart';
import 'package:workouts/utils/run_formatting.dart';

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

class IndoorFitnessCalculator() {
  static const minDriftDuration = Duration(minutes: 20);
  static const minHalfSampleCount = 8;

  IndoorFitnessSignals compute({
    required int durationSeconds,
    required double distanceMeters,
    required List<TimestampedHeartRate> heartRateSamples,
    required List<CardioQuantitySample> distanceSamples,
    required bool machineLinked,
  }) {
    final double? paceSecondsPerMile = _paceSecondsPerMile(
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
    );
    final double? metersPerHeartbeat = _metersPerHeartbeat(
      distanceMeters: distanceMeters,
      heartRateSamples: heartRateSamples,
    );
    final double? cardiacDriftPercent = _cardiacDriftPercent(
      durationSeconds: durationSeconds,
      heartRateSamples: heartRateSamples,
    );
    return IndoorFitnessSignals(
      paceSecondsPerMile: paceSecondsPerMile,
      metersPerHeartbeat: metersPerHeartbeat,
      cardiacDriftPercent: cardiacDriftPercent,
      hasDistanceSamples: distanceSamples.isNotEmpty,
      distanceOrigin: machineLinked
          ? DistanceOrigin.machineLinked
          : DistanceOrigin.watchEstimated,
      confidence: _confidence(
        durationSeconds: durationSeconds,
        hasDistance: distanceMeters > 0 || distanceSamples.isNotEmpty,
        heartRateSamples: heartRateSamples,
        hasDrift: cardiacDriftPercent != null,
        machineLinked: machineLinked,
      ),
    );
  }

  double? _paceSecondsPerMile({
    required int durationSeconds,
    required double distanceMeters,
  }) {
    if (durationSeconds <= 0 || distanceMeters <= 0) return null;
    return durationSeconds / (distanceMeters / metersPerMile);
  }

  double? _metersPerHeartbeat({
    required double distanceMeters,
    required List<TimestampedHeartRate> heartRateSamples,
  }) {
    if (distanceMeters <= 0 || heartRateSamples.length < 2) return null;
    final totalBeats = _integratedBeats(heartRateSamples);
    if (totalBeats <= 0) return null;
    return distanceMeters / totalBeats;
  }

  double _integratedBeats(List<TimestampedHeartRate> heartRateSamples) {
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

  double? _cardiacDriftPercent({
    required int durationSeconds,
    required List<TimestampedHeartRate> heartRateSamples,
  }) {
    if (durationSeconds < minDriftDuration.inSeconds) return null;
    if (heartRateSamples.length < minHalfSampleCount * 2) return null;
    final midpoint = heartRateSamples.first.timestamp.add(
      Duration(seconds: durationSeconds ~/ 2),
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

  FitnessSignalConfidence _confidence({
    required int durationSeconds,
    required bool hasDistance,
    required List<TimestampedHeartRate> heartRateSamples,
    required bool hasDrift,
    required bool machineLinked,
  }) {
    if (heartRateSamples.length < minHalfSampleCount || !hasDistance) {
      return FitnessSignalConfidence.insufficient;
    }
    if (hasDrift && machineLinked && durationSeconds >= minDriftDuration.inSeconds) {
      return FitnessSignalConfidence.high;
    }
    if (hasDrift || machineLinked) {
      return FitnessSignalConfidence.medium;
    }
    return FitnessSignalConfidence.low;
  }
}
