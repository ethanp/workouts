import 'package:workouts/utils/run_formatting.dart';

class CardioBestEffort {
  const CardioBestEffort({
    required this.bucket,
    required this.elapsedSeconds,
    this.workoutStartedAt,
  });

  factory CardioBestEffort.fromRow(Map<String, dynamic> row) {
    final distanceMeters = (row['distance_meters'] as num).toDouble();
    final bucket = DistanceBucket.fromMeters(distanceMeters);
    if (bucket == null) {
      throw ArgumentError('Unknown distance bucket: $distanceMeters');
    }
    return CardioBestEffort(
      bucket: bucket,
      elapsedSeconds: (row['elapsed_seconds'] as num).toDouble(),
      workoutStartedAt: row['started_at'] != null
          ? DateTime.parse(row['started_at'] as String)
          : null,
    );
  }

  final DistanceBucket bucket;
  final double elapsedSeconds;
  final DateTime? workoutStartedAt;

  double paceSecondsPerUnit(double metersPerUnit) =>
      elapsedSeconds / (bucket.meters / metersPerUnit);
}
