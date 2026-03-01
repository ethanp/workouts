/// Pure functions for Zone 2 heart rate calculations.
/// Kept free of Flutter/database dependencies so they are trivially testable.

/// Returns the Zone 2 BPM bounds for a given max heart rate.
/// Zone 2 is defined as 60–70% of max HR.
({int lower, int upper}) zone2Bounds(int maxHR) => (
      lower: (maxHR * 0.60).floor(),
      upper: (maxHR * 0.70).ceil(),
    );

/// Computes the number of seconds spent in Zone 2 from an ordered sequence
/// of heart rate samples.
///
/// For each consecutive pair of samples, if the earlier sample's BPM falls
/// within [lowerBpm, upperBpm] (inclusive), the time gap between it and the
/// next sample is counted as Zone 2 time — capped at [maxGapSeconds] to
/// handle pauses or gaps in recording.
int computeZone2Seconds(
  List<({DateTime timestamp, int bpm})> samples, {
  required int lowerBpm,
  required int upperBpm,
  int maxGapSeconds = 30,
}) {
  if (samples.length < 2) return 0;
  var zone2Seconds = 0;
  for (var i = 0; i < samples.length - 1; i++) {
    final bpm = samples[i].bpm;
    if (bpm >= lowerBpm && bpm <= upperBpm) {
      final gapSeconds =
          samples[i + 1].timestamp.difference(samples[i].timestamp).inSeconds;
      zone2Seconds += gapSeconds.clamp(0, maxGapSeconds);
    }
  }
  return zone2Seconds;
}
