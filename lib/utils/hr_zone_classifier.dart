import 'package:workouts/models/hr_zone_time.dart';

/// A heart rate reading at a point in time, without persistence metadata.
class TimestampedHeartRate {
  const TimestampedHeartRate({required this.timestamp, required this.bpm});

  final DateTime timestamp;
  final int bpm;
}

/// Buckets a continuous HR series into the 5-zone model and reports total
/// seconds spent in each zone.
///
/// Fixed boundaries (bpm):
///   Zone 1: 93-114, Zone 2: 115-145, Zone 3: 146-162,
///   Zone 4: 163-175, Zone 5: 176-185
///
/// Stateless — call [HrZoneClassifier.compute] directly. Zone boundaries
/// are exposed as static constants so settings UI can render the same
/// numbers without instantiating anything.
class HrZoneClassifier {
  const HrZoneClassifier._();

  /// Zone lower bounds: [zone1, zone2, zone3, zone4, zone5].
  static const List<int> zoneBoundaries = [93, 115, 146, 163, 176];

  /// Upper bounds per zone (inclusive).
  static const List<int> zoneUpperBounds = [114, 145, 162, 175, 185];

  static int get zone2Lower => zoneBoundaries[1];

  /// Returns total seconds spent in each zone across [samples]. Each
  /// sample is treated as the start of an interval that continues until
  /// the next sample (capped at [maxGapSeconds] to handle dropouts).
  static HrZoneTime compute(
    List<TimestampedHeartRate> samples, {
    int maxGapSeconds = 30,
  }) {
    if (samples.length < 2) return HrZoneTime.zero;

    final zoneTotals = List.filled(5, 0);

    for (var sampleIndex = 0; sampleIndex < samples.length - 1; sampleIndex++) {
      final bpm = samples[sampleIndex].bpm;
      final gapSeconds = samples[sampleIndex + 1].timestamp
          .difference(samples[sampleIndex].timestamp)
          .inSeconds
          .clamp(0, maxGapSeconds);

      if (gapSeconds <= 0) continue;

      final zone = _zoneForBpm(bpm);
      if (zone >= 0) zoneTotals[zone] += gapSeconds;
    }

    return HrZoneTime(
      zone1: zoneTotals[0],
      zone2: zoneTotals[1],
      zone3: zoneTotals[2],
      zone4: zoneTotals[3],
      zone5: zoneTotals[4],
    );
  }

  /// Maps a BPM to a zone index (0-4), or -1 if below zone 1.
  static int _zoneForBpm(int bpm) {
    for (var zoneIndex = 4; zoneIndex >= 0; zoneIndex--) {
      if (bpm >= zoneBoundaries[zoneIndex]) return zoneIndex;
    }
    return -1;
  }
}
