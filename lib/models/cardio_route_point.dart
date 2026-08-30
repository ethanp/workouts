class const CardioRoutePoint({
  required final String id,
  required final String workoutId,
  required final int pointIndex,
  required final double latitude,
  required final double longitude,
  final double? altitudeMeters,
  final DateTime? recordedAt,
  final DateTime? createdAt,
  final DateTime? updatedAt,
}) {
  factory fromRow(Map<String, dynamic> routePointRow) {
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
