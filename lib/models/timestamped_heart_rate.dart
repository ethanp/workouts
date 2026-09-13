import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/heart_rate_sample.dart';

/// A heart rate reading at a point in time, without persistence metadata.
class const TimestampedHeartRate({
  required final DateTime timestamp,
  required final int bpm,
});

extension CardioHeartRateSampleReading on CardioHeartRateSample {
  TimestampedHeartRate get asTimestampedHeartRate =>
      TimestampedHeartRate(timestamp: timestamp, bpm: bpm);
}

extension HeartRateSampleReading on HeartRateSample {
  TimestampedHeartRate get asTimestampedHeartRate =>
      TimestampedHeartRate(timestamp: timestamp, bpm: bpm);
}
