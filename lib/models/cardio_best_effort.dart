import 'package:workouts/utils/run_formatting.dart';

class const CardioBestEffort({
  required final DistanceBucket bucket,
  required final double elapsedSeconds,
  final DateTime? workoutStartedAt,
}) {
  factory fromRow(Map<String, dynamic> row) {
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

  double paceSecondsPerUnit(double metersPerUnit) =>
      elapsedSeconds / (bucket.meters / metersPerUnit);
}
