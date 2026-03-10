import 'package:workouts/models/cardio_type.dart';

class CardioImportPayload {
  const CardioImportPayload({
    required this.externalWorkoutId,
    required this.activityType,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.energyKcal,
    required this.avgHeartRateBpm,
    required this.maxHeartRateBpm,
    required this.routeAvailable,
    required this.sourceName,
    required this.sourceBundleId,
    required this.deviceModel,
    required this.routePoints,
    required this.heartRateSamples,
  });

  final String externalWorkoutId;
  final CardioType activityType;
  final String startedAt;
  final String endedAt;
  final int durationSeconds;
  final double distanceMeters;
  final double? energyKcal;
  final double? avgHeartRateBpm;
  final double? maxHeartRateBpm;
  final bool routeAvailable;
  final String sourceName;
  final String? sourceBundleId;
  final String? deviceModel;
  final List<RoutePointPayload> routePoints;
  final List<HeartRateSamplePayload> heartRateSamples;

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
    final activityTypeKey =
        payload['activityType'] as String? ?? 'outdoorRun';
    return CardioImportPayload(
      externalWorkoutId: externalWorkoutId,
      activityType: CardioType.fromDbKey(activityTypeKey),
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: payload['durationSeconds'] as int? ?? 0,
      distanceMeters: _asDouble(payload['distanceMeters']) ?? 0,
      energyKcal: _asDouble(payload['energyKcal']),
      avgHeartRateBpm: _asDouble(payload['avgHeartRateBpm']),
      maxHeartRateBpm: _asDouble(payload['maxHeartRateBpm']),
      routeAvailable: payload['routeAvailable'] == true,
      sourceName: (payload['sourceName'] as String?) ?? 'Apple Health',
      sourceBundleId: payload['sourceBundleId'] as String?,
      deviceModel: payload['deviceModel'] as String?,
      routePoints: RoutePointPayload.parseList(payload['routePoints']),
      heartRateSamples:
          HeartRateSamplePayload.parseList(payload['heartRateSeries']),
    );
  }
}

class RoutePointPayload {
  const RoutePointPayload({
    required this.lat,
    required this.lng,
    required this.altitudeMeters,
    required this.timestamp,
  });

  final double lat;
  final double lng;
  final double? altitudeMeters;
  final String? timestamp;

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

class HeartRateSamplePayload {
  const HeartRateSamplePayload({required this.timestamp, required this.bpm});

  final String timestamp;
  final int bpm;

  static List<HeartRateSamplePayload> parseList(Object? raw) {
    if (raw is! List) return const [];
    final parsedSamples = <HeartRateSamplePayload>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final Map<String, dynamic> sampleMap = Map<String, dynamic>.from(item);
      final String? timestamp = sampleMap['timestamp'] as String?;
      final int? bpm = _asDouble(sampleMap['bpm'])?.round();
      if (timestamp == null || bpm == null) continue;
      parsedSamples.add(
        HeartRateSamplePayload(timestamp: timestamp, bpm: bpm),
      );
    }
    return parsedSamples;
  }
}

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}
