import 'dart:math' as math;

/// A heart rate reading at a point in time, without persistence metadata.
class TimestampedHeartRate {
  const TimestampedHeartRate({required this.timestamp, required this.bpm});

  final DateTime timestamp;
  final int bpm;
}

class TrainingLoadResult {
  const TrainingLoadResult({required this.zone2Seconds, required this.trimp});

  final int zone2Seconds;
  final double trimp;
}

/// Computes both Zone 2 time and Banister TRIMP from a continuous HR series.
///
/// TRIMP formula per interval:
///   HRratio = (bpm - restingHR) / (maxHR - restingHR)
///   TRIMP += (gapMinutes) * HRratio * 0.64 * e^(1.92 * HRratio)
///
/// Zone 2 is defined as 60–70% of max HR.
class TrainingLoadCalculator {
  TrainingLoadCalculator({
    required this.maxHeartRate,
    required this.restingHeartRate,
  })  : zone2Lower = (maxHeartRate * 0.60).floor(),
        zone2Upper = (maxHeartRate * 0.70).ceil(),
        _hrReserve = (maxHeartRate - restingHeartRate).toDouble();

  final int maxHeartRate;
  final int restingHeartRate;
  final int zone2Lower;
  final int zone2Upper;
  final double _hrReserve;

  TrainingLoadResult compute(
    List<TimestampedHeartRate> samples, {
    int maxGapSeconds = 30,
  }) {
    if (samples.length < 2) {
      return const TrainingLoadResult(zone2Seconds: 0, trimp: 0);
    }

    var zone2Total = 0;
    var trimpTotal = 0.0;

    for (var i = 0; i < samples.length - 1; i++) {
      final bpm = samples[i].bpm;
      final gapSeconds = samples[i + 1]
          .timestamp
          .difference(samples[i].timestamp)
          .inSeconds
          .clamp(0, maxGapSeconds);

      if (gapSeconds <= 0) continue;

      if (bpm >= zone2Lower && bpm <= zone2Upper) {
        zone2Total += gapSeconds;
      }

      if (_hrReserve > 0 && bpm > restingHeartRate) {
        final hrRatio = (bpm - restingHeartRate) / _hrReserve;
        final gapMinutes = gapSeconds / 60.0;
        trimpTotal += gapMinutes * hrRatio * 0.64 * math.exp(1.92 * hrRatio);
      }
    }

    return TrainingLoadResult(
      zone2Seconds: zone2Total,
      trimp: trimpTotal,
    );
  }
}
