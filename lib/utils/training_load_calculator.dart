import 'dart:math' as math;

import 'package:workouts/models/hr_zone_time.dart';

/// A heart rate reading at a point in time, without persistence metadata.
class TimestampedHeartRate {
  const TimestampedHeartRate({required this.timestamp, required this.bpm});

  final DateTime timestamp;
  final int bpm;
}

class TrainingLoadResult {
  const TrainingLoadResult({
    this.zoneTime = HrZoneTime.zero,
    this.trimp = 0,
  });

  final HrZoneTime zoneTime;
  final double trimp;
}

/// Computes per-zone time and Banister TRIMP from a continuous HR series.
///
/// Standard 5-zone model (% of max HR):
///   Zone 1: 50-60%, Zone 2: 60-70%, Zone 3: 70-80%,
///   Zone 4: 80-90%, Zone 5: 90-100%
///
/// TRIMP formula per interval:
///   HRratio = (bpm - restingHR) / (maxHR - restingHR)
///   TRIMP += (gapMinutes) * HRratio * 0.64 * e^(1.92 * HRratio)
class TrainingLoadCalculator {
  TrainingLoadCalculator({
    required this.maxHeartRate,
    required this.restingHeartRate,
  })  : zoneBoundaries = [
          (maxHeartRate * 0.50).floor(),
          (maxHeartRate * 0.60).floor(),
          (maxHeartRate * 0.70).floor(),
          (maxHeartRate * 0.80).floor(),
          (maxHeartRate * 0.90).floor(),
        ],
        _hrReserve = (maxHeartRate - restingHeartRate).toDouble();

  final int maxHeartRate;
  final int restingHeartRate;

  /// Zone lower bounds: [zone1Lower, zone2Lower, zone3Lower, zone4Lower, zone5Lower].
  final List<int> zoneBoundaries;

  final double _hrReserve;

  int get zone2Lower => zoneBoundaries[1];

  TrainingLoadResult compute(
    List<TimestampedHeartRate> samples, {
    int maxGapSeconds = 30,
  }) {
    if (samples.length < 2) return const TrainingLoadResult();

    final zoneTotals = List.filled(5, 0);
    var trimpTotal = 0.0;

    for (var i = 0; i < samples.length - 1; i++) {
      final bpm = samples[i].bpm;
      final gapSeconds = samples[i + 1]
          .timestamp
          .difference(samples[i].timestamp)
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
    for (var z = 4; z >= 0; z--) {
      if (bpm >= zoneBoundaries[z]) return z;
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
