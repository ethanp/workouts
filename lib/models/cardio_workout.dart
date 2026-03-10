import 'package:workouts/models/cardio_type.dart';

class CardioWorkout {
  const CardioWorkout({
    required this.id,
    required this.externalWorkoutId,
    required this.activityType,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    this.energyKcal,
    this.averageHeartRateBpm,
    this.maxHeartRateBpm,
    required this.routeAvailable,
    required this.sourceName,
    this.sourceBundleId,
    this.deviceModel,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String externalWorkoutId;
  final CardioType activityType;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final double distanceMeters;
  final double? energyKcal;
  final double? averageHeartRateBpm;
  final double? maxHeartRateBpm;
  final bool routeAvailable;
  final String sourceName;
  final String? sourceBundleId;
  final String? deviceModel;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
