/// A heart rate reading at a point in time, without persistence metadata.
class TimestampedHeartRate {
  const TimestampedHeartRate({required this.timestamp, required this.bpm});

  final DateTime timestamp;
  final int bpm;
}

/// Calculates Zone 2 heart rate metrics from a configured max heart rate.
///
/// Zone 2 is defined as 60–70% of max HR. Construct with a max heart rate,
/// then use [seconds] to compute time-in-zone from ordered HR samples.
class Zone2Calculator {
  Zone2Calculator({required this.maxHeartRate})
      : lowerBpm = (maxHeartRate * 0.60).floor(),
        upperBpm = (maxHeartRate * 0.70).ceil();

  final int maxHeartRate;

  /// Inclusive lower bound of Zone 2 (60% of max HR).
  final int lowerBpm;

  /// Inclusive upper bound of Zone 2 (70% of max HR).
  final int upperBpm;

  /// Computes seconds spent in Zone 2 from an ordered sequence of HR samples.
  ///
  /// For each consecutive pair, if the earlier sample's BPM falls within
  /// [lowerBpm, upperBpm], the time gap to the next sample is counted —
  /// capped at [maxGapSeconds] to handle pauses or gaps in recording.
  int seconds(
    List<TimestampedHeartRate> samples, {
    int maxGapSeconds = 30,
  }) {
    if (samples.length < 2) return 0;
    var total = 0;
    for (var i = 0; i < samples.length - 1; i++) {
      final bpm = samples[i].bpm;
      if (bpm >= lowerBpm && bpm <= upperBpm) {
        final gap =
            samples[i + 1].timestamp.difference(samples[i].timestamp).inSeconds;
        total += gap.clamp(0, maxGapSeconds);
      }
    }
    return total;
  }
}
