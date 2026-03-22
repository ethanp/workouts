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

  factory CardioRoutePoint.fromRow(Map<String, dynamic> routePointRow) {
    return CardioRoutePoint(
      id: routePointRow['id'] as String,
      workoutId: routePointRow['workout_id'] as String,
      pointIndex: (routePointRow['point_index'] as int?) ?? 0,
      latitude: _asDouble(routePointRow['lat']) ?? 0,
      longitude: _asDouble(routePointRow['lng']) ?? 0,
      altitudeMeters: _asDouble(routePointRow['altitude_meters']),
      recordedAt: _asDateTime(routePointRow['timestamp']),
      createdAt: _asDateTime(routePointRow['created_at']),
      updatedAt: _asDateTime(routePointRow['updated_at']),
    );
  }

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

double? _asDouble(Object? rawValue) {
  if (rawValue == null) return null;
  if (rawValue is num) return rawValue.toDouble();
  return double.tryParse('$rawValue');
}

DateTime? _asDateTime(Object? rawValue) {
  final String? maybeDateTime = rawValue as String?;
  return maybeDateTime == null ? null : DateTime.tryParse(maybeDateTime);
}
