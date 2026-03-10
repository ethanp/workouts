class CardioRoutePoint {
  const CardioRoutePoint({
    required this.id,
    required this.workoutId,
    required this.pointIndex,
    required this.latitude,
    required this.longitude,
    this.altitudeMeters,
    this.recordedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String workoutId;
  final int pointIndex;
  final double latitude;
  final double longitude;
  final double? altitudeMeters;
  final DateTime? recordedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
