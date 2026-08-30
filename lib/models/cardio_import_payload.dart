import 'package:workouts/models/cardio_type.dart';

class const CardioImportPayload({
  required final String externalWorkoutId,
  required final CardioType activityType,
  required final String startedAt,
  required final String endedAt,
  required final int durationSeconds,
  required final double distanceMeters,
  required final double? energyKcal,
  required final double? avgHeartRateBpm,
  required final double? maxHeartRateBpm,
  required final bool routeAvailable,
  required final String sourceName,
  required final String? sourceBundleId,
  required final String? deviceModel,
  required final List<RoutePointPayload> routePoints,
  required final List<HeartRateSamplePayload> heartRateSamples,
}) {
  static CardioImportPayload? tryParse(Map<String, dynamic> payload) {
    final String? externalWorkoutId = payload['externalWorkoutId'] as String?;
    final String? startedAt = payload['startDate'] as String?;
    final String? endedAt = payload['endDate'] as String?;
    if (externalWorkoutId == null ||
        externalWorkoutId.isEmpty ||
        startedAt == null ||
        endedAt == null) {
      return null;
    }
    final activityTypeKey = payload['activityType'] as String? ?? 'outdoorRun';
    return CardioImportPayload(
      externalWorkoutId: externalWorkoutId,
      activityType: CardioType.fromDbKey(activityTypeKey),
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: _asInt(payload['durationSeconds']) ?? 0,
      distanceMeters: _asDouble(payload['distanceMeters']) ?? 0,
      energyKcal: _asDouble(payload['energyKcal']),
      avgHeartRateBpm: _asDouble(payload['avgHeartRateBpm']),
      maxHeartRateBpm: _asDouble(payload['maxHeartRateBpm']),
      routeAvailable: payload['routeAvailable'] == true,
      sourceName: (payload['sourceName'] as String?) ?? 'Apple Health',
      sourceBundleId: payload['sourceBundleId'] as String?,
      deviceModel: payload['deviceModel'] as String?,
      routePoints: RoutePointPayload.parseList(payload['routePoints']),
      heartRateSamples: HeartRateSamplePayload.parseList(
        payload['heartRateSeries'],
      ),
    );
  }
}

class const RoutePointPayload({
  required final double lat,
  required final double lng,
  required final double? altitudeMeters,
  required final String? timestamp,
}) {
  static List<RoutePointPayload> parseList(Object? raw) {
    if (raw is! List) return const [];
    final parsedPoints = <RoutePointPayload>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final Map<String, dynamic> pointMap = Map<String, dynamic>.from(item);
      final double? lat = _asDouble(pointMap['lat']);
      final double? lng = _asDouble(pointMap['lng']);
      if (lat == null || lng == null) continue;
      parsedPoints.add(
        RoutePointPayload(
          lat: lat,
          lng: lng,
          altitudeMeters: _asDouble(pointMap['altitudeMeters']),
          timestamp: pointMap['timestamp'] as String?,
        ),
      );
    }
    return parsedPoints;
  }
}

class const HeartRateSamplePayload({
  required final String timestamp,
  required final int bpm,
}) {
  static List<HeartRateSamplePayload> parseList(Object? raw) {
    if (raw is! List) return const [];
    final parsedSamples = <HeartRateSamplePayload>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final Map<String, dynamic> sampleMap = Map<String, dynamic>.from(item);
      final String? timestamp = sampleMap['timestamp'] as String?;
      final int? bpm = _asDouble(sampleMap['bpm'])?.round();
      if (timestamp == null || bpm == null) continue;
      parsedSamples.add(HeartRateSamplePayload(timestamp: timestamp, bpm: bpm));
    }
    return parsedSamples;
  }
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.round();
  return int.tryParse('$value');
}

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}
