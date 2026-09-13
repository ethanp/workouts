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
  final String? deviceName,
  final double? elevationAscendedMeters,
  final double? recoveryBpm,
  final double? effortScore,
  final double? estimatedEffortScore,
  final bool machineLinked = false,
  final double? averageMets,
  final double? fitnessMachineDurationSeconds,
  final double? crossTrainerDistanceMeters,
  final double? indoorBikeDistanceMeters,
  final double? basalEnergyKcal,
  final double? stepCount,
  final double? flightsClimbed,
  final double? minHeartRateBpm,
  required final List<RoutePointPayload> routePoints,
  required final List<HeartRateSamplePayload> heartRateSamples,
  final List<QuantitySamplePayload> distanceSamples = const [],
  final List<QuantitySamplePayload> stepSamples = const [],
  final List<WorkoutEventPayload> events = const [],
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
      deviceName: payload['deviceName'] as String?,
      elevationAscendedMeters: _asDouble(payload['elevationAscendedMeters']),
      recoveryBpm: _asDouble(payload['recoveryBpm']),
      effortScore: _asDouble(payload['effortScore']),
      estimatedEffortScore: _asDouble(payload['estimatedEffortScore']),
      machineLinked: payload['machineLinked'] == true,
      averageMets: _asDouble(payload['averageMets']),
      fitnessMachineDurationSeconds: _asDouble(
        payload['fitnessMachineDurationSeconds'],
      ),
      crossTrainerDistanceMeters: _asDouble(
        payload['crossTrainerDistanceMeters'],
      ),
      indoorBikeDistanceMeters: _asDouble(payload['indoorBikeDistanceMeters']),
      basalEnergyKcal: _asDouble(payload['basalEnergyKcal']),
      stepCount: _asDouble(payload['stepCount']),
      flightsClimbed: _asDouble(payload['flightsClimbed']),
      minHeartRateBpm: _asDouble(payload['minHeartRateBpm']),
      routePoints: RoutePointPayload.parseList(payload['routePoints']),
      heartRateSamples: HeartRateSamplePayload.parseList(
        payload['heartRateSeries'],
      ),
      distanceSamples: QuantitySamplePayload.parseList(payload['distanceSeries']),
      stepSamples: QuantitySamplePayload.parseList(payload['stepSeries']),
      events: WorkoutEventPayload.parseList(payload['events']),
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

class const QuantitySamplePayload({
  required final String startedAt,
  required final String endedAt,
  required final double value,
}) {
  static List<QuantitySamplePayload> parseList(Object? raw) {
    if (raw is! List) return const [];
    final parsedSamples = <QuantitySamplePayload>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final Map<String, dynamic> sampleMap = Map<String, dynamic>.from(item);
      final String? startedAt = sampleMap['timestamp'] as String?;
      final String endedAt =
          (sampleMap['endTimestamp'] as String?) ?? startedAt ?? '';
      final double? value = _asDouble(sampleMap['value']);
      if (startedAt == null || value == null) continue;
      parsedSamples.add(
        QuantitySamplePayload(
          startedAt: startedAt,
          endedAt: endedAt,
          value: value,
        ),
      );
    }
    return parsedSamples;
  }
}

class const WorkoutEventPayload({
  required final String eventType,
  required final String occurredAt,
  final String? endedAt,
}) {
  static List<WorkoutEventPayload> parseList(Object? raw) {
    if (raw is! List) return const [];
    final parsedEvents = <String, WorkoutEventPayload>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final Map<String, dynamic> eventMap = Map<String, dynamic>.from(item);
      final String? eventType = eventMap['type'] as String?;
      final String? occurredAt = eventMap['timestamp'] as String?;
      if (eventType == null || occurredAt == null) continue;
      parsedEvents['$eventType|$occurredAt'] = WorkoutEventPayload(
        eventType: eventType,
        occurredAt: occurredAt,
        endedAt: eventMap['endTimestamp'] as String?,
      );
    }
    return parsedEvents.values.toList();
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
