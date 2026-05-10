import 'dart:math' as math;

import 'package:workouts/models/hr_zone_time.dart';

/// A heart rate reading at a point in time, without persistence metadata.
class TimestampedHeartRate {
  const TimestampedHeartRate({required this.timestamp, required this.bpm});

  final DateTime timestamp;
  final int bpm;
}

class TrainingLoadResult {
  const TrainingLoadResult({this.zoneTime = HrZoneTime.zero, this.trimp = 0});

  final HrZoneTime zoneTime;
  final double trimp;
}

/// Computes per-zone time and Banister TRIMP from a continuous HR series.
///
/// Fixed 5-zone model (bpm):
///   Zone 1: 93-114, Zone 2: 115-145, Zone 3: 146-162,
///   Zone 4: 163-175, Zone 5: 176-185
///
/// TRIMP formula per interval:
///   HRratio = (bpm - restingHR) / (maxHR - restingHR)
///   TRIMP += (gapMinutes) * HRratio * 0.64 * e^(1.92 * HRratio)
class TrainingLoadCalculator {
  TrainingLoadCalculator({required this.restingHeartRate})
    : _hrReserve = (_trimpMaxHr - restingHeartRate).toDouble();

  static const int _trimpMaxHr = 185;

  /// Zone lower bounds: [zone1, zone2, zone3, zone4, zone5].
  static const List<int> zoneBoundaries = [93, 115, 146, 163, 176];

  /// Upper bounds per zone (inclusive).
  static const List<int> zoneUpperBounds = [114, 145, 162, 175, 185];

  final int restingHeartRate;
  final double _hrReserve;

  int get zone2Lower => zoneBoundaries[1];

  TrainingLoadResult compute(
    List<TimestampedHeartRate> samples, {
    int maxGapSeconds = 30,
  }) {
    if (samples.length < 2) return const TrainingLoadResult();

    final zoneTotals = List.filled(5, 0);
    var trimpTotal = 0.0;

    for (var sampleIndex = 0; sampleIndex < samples.length - 1; sampleIndex++) {
      final bpm = samples[sampleIndex].bpm;
      final gapSeconds = samples[sampleIndex + 1].timestamp
          .difference(samples[sampleIndex].timestamp)
          .inSeconds
          .clamp(0, maxGapSeconds);

      if (gapSeconds <= 0) continue;

      final zone = _zoneForBpm(bpm);
      if (zone >= 0) zoneTotals[zone] += gapSeconds;

      trimpTotal += _trimpForInterval(bpm, gapSeconds);
    }

    return TrainingLoadResult(
      zoneTime: HrZoneTime(
        zone1: zoneTotals[0],
        zone2: zoneTotals[1],
        zone3: zoneTotals[2],
        zone4: zoneTotals[3],
        zone5: zoneTotals[4],
      ),
      trimp: trimpTotal,
    );
  }

  /// Maps a BPM to a zone index (0-4), or -1 if below zone 1.
  int _zoneForBpm(int bpm) {
    for (var zoneIndex = 4; zoneIndex >= 0; zoneIndex--) {
      if (bpm >= zoneBoundaries[zoneIndex]) return zoneIndex;
    }
    return -1;
  }

  double _trimpForInterval(int bpm, int gapSeconds) {
    if (_hrReserve <= 0 || bpm <= restingHeartRate) return 0;
    final hrRatio = (bpm - restingHeartRate) / _hrReserve;
    final gapMinutes = gapSeconds / 60.0;
    return gapMinutes * hrRatio * 0.64 * math.exp(1.92 * hrRatio);
  }
}
