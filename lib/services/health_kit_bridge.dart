import 'dart:async';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/apple_health_cardio_listing.dart';
import 'package:workouts/models/cardio_heart_rate_sample.dart';
import 'package:workouts/models/cardio_import_payload.dart';
import 'package:workouts/models/cardio_quantity_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/models/cardio_workout_series.dart';
import 'package:workouts/models/cardio_workout_fingerprint.dart';
import 'package:workouts/models/health_data_inventory.dart';
import 'package:workouts/models/health_permission_status.dart';
import 'package:workouts/models/heart_rate_sample.dart';

class HealthKitBridge() {
  this
    : _methodChannel = const MethodChannel('com.workouts/health_kit'),
      _heartRateChannel = const EventChannel('com.workouts/heart_rate_stream'),
      _inventoryProgressChannel = const EventChannel(
        'com.workouts/health_inventory_progress',
      ),
      _importChannel = const EventChannel('com.workouts/health_import');

  final MethodChannel _methodChannel;
  final EventChannel _heartRateChannel;
  final EventChannel _inventoryProgressChannel;
  final EventChannel _importChannel;
  final _uuid = const Uuid();

  Future<HealthPermissionStatus> getAuthorizationStatus() async {
    try {
      final status = await _methodChannel.invokeMethod<String>('status');
      return _mapStatus(status);
    } on MissingPluginException {
      return HealthPermissionStatus.unavailable;
    } on PlatformException {
      return HealthPermissionStatus.unavailable;
    }
  }

  Future<HealthPermissionStatus> requestAuthorization() async {
    try {
      final status = await _methodChannel.invokeMethod<String>('request');
      return _mapStatus(status);
    } on MissingPluginException {
      return HealthPermissionStatus.unavailable;
    } on PlatformException {
      return HealthPermissionStatus.unavailable;
    }
  }

  Stream<HeartRateSample> heartRateStream() {
    return _heartRateChannel
        .receiveBroadcastStream()
        .map((event) {
          final map = Map<String, dynamic>.from(event as Map);
          return HeartRateSample(
            id: map['id'] as String? ?? _uuid.v4(),
            sessionId: map['sessionId'] as String? ?? 'unknown',
            timestamp: DateTime.parse(map['timestamp'] as String),
            bpm: map['bpm'] as int,
            energyKcal: (map['energyKcal'] as num?)?.toDouble(),
            source: map['source'] as String? ?? 'watch',
          );
        })
        .handleError((_) {
          // Ignore errors and continue the stream
        });
  }

  Future<int> countCardioWorkouts() async {
    try {
      final count = await _methodChannel.invokeMethod<int>(
        'countCardioWorkouts',
      );
      return count ?? 0;
    } on MissingPluginException {
      return -1;
    } on PlatformException {
      return -1;
    }
  }

  Stream<HealthInventoryInspectProgress> inventoryInspectProgress() {
    return _inventoryProgressChannel.receiveBroadcastStream().map((event) {
      return HealthInventoryInspectProgress.fromMap(
        Map<String, dynamic>.from(event as Map),
      );
    });
  }

  Future<Map<String, dynamic>> inspectRecentCardioWorkouts({
    int maxWorkouts = 5,
  }) async {
    try {
      final payload = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'inspectRecentCardioWorkouts',
        {'maxWorkouts': maxWorkouts},
      );
      if (payload == null) return const {};
      return _jsonObjectMap(payload);
    } on MissingPluginException {
      return const {};
    } on PlatformException {
      return const {};
    }
  }

  Future<List<CardioHeartRateSample>> fetchCardioHeartRateForZones({
    required String workoutId,
    required String externalWorkoutId,
  }) async {
    final payload = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'fetchCardioHeartRateForZones',
      {'externalWorkoutId': externalWorkoutId},
    );
    if (payload == null) {
      throw StateError('Apple Health returned no heart-rate series');
    }
    final heartRateSamples = HeartRateSamplePayload.parseList(
      Map<String, dynamic>.from(payload)['heartRateSeries'],
    );
    return [
      for (
        var sampleIndex = 0;
        sampleIndex < heartRateSamples.length;
        sampleIndex++
      )
        CardioHeartRateSample.fromHealthKit(
          workoutId: workoutId,
          sampleIndex: sampleIndex,
          timestamp: DateTime.parse(heartRateSamples[sampleIndex].timestamp),
          bpm: heartRateSamples[sampleIndex].bpm,
        ),
    ];
  }

  Future<CardioWorkoutSeries> fetchCardioWorkoutSeries({
    required String workoutId,
    required String externalWorkoutId,
    int maxRoutePoints = 1500,
    bool includeRoute = true,
  }) async {
    try {
      final payload = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'fetchCardioWorkoutSeries',
        {
          'externalWorkoutId': externalWorkoutId,
          'maxRoutePoints': maxRoutePoints,
          'includeRoute': includeRoute,
        },
      );
      if (payload == null) return CardioWorkoutSeries.empty;
      return _seriesFromHealthKitPayload(
        workoutId: workoutId,
        payload: Map<String, dynamic>.from(payload),
      );
    } on MissingPluginException {
      return CardioWorkoutSeries.empty;
    } on PlatformException {
      return CardioWorkoutSeries.empty;
    }
  }

  CardioWorkoutSeries _seriesFromHealthKitPayload({
    required String workoutId,
    required Map<String, dynamic> payload,
  }) {
    final routePoints = RoutePointPayload.parseList(payload['routePoints']);
    final heartRateSamples = HeartRateSamplePayload.parseList(
      payload['heartRateSeries'],
    );
    final distanceSamples = QuantitySamplePayload.parseList(
      payload['distanceSeries'],
    );
    return CardioWorkoutSeries(
      routePoints: [
        for (var pointIndex = 0; pointIndex < routePoints.length; pointIndex++)
          CardioRoutePoint.fromHealthKit(
            workoutId: workoutId,
            pointIndex: pointIndex,
            latitude: routePoints[pointIndex].lat,
            longitude: routePoints[pointIndex].lng,
            altitudeMeters: routePoints[pointIndex].altitudeMeters,
            recordedAt: DateTime.tryParse(
              routePoints[pointIndex].timestamp ?? '',
            ),
          ),
      ],
      heartRateSamples: [
        for (
          var sampleIndex = 0;
          sampleIndex < heartRateSamples.length;
          sampleIndex++
        )
          CardioHeartRateSample.fromHealthKit(
            workoutId: workoutId,
            sampleIndex: sampleIndex,
            timestamp: DateTime.parse(heartRateSamples[sampleIndex].timestamp),
            bpm: heartRateSamples[sampleIndex].bpm,
          ),
      ],
      distanceSamples: [
        for (
          var sampleIndex = 0;
          sampleIndex < distanceSamples.length;
          sampleIndex++
        )
          CardioQuantitySample.fromHealthKit(
            workoutId: workoutId,
            sampleIndex: sampleIndex,
            startedAt: DateTime.parse(distanceSamples[sampleIndex].startedAt),
            endedAt: DateTime.parse(distanceSamples[sampleIndex].endedAt),
            value: distanceSamples[sampleIndex].value,
          ),
      ],
    );
  }

  Future<AppleHealthCardioListing> importCardioWorkouts({
    int maxWorkouts = 0,
    bool includeRoute = true,
    int maxRoutePoints = 1500,
    bool includeHeartRateSeries = true,
    bool includeAssociatedSeries = true,
    List<CardioWorkoutFingerprint> skipUnchanged = const [],
    required void Function(HealthInventoryInspectProgress progress) onProgress,
    required Future<void> Function(Map<String, dynamic> workout) onWorkout,
  }) async {
    final importEvents = StreamController<Map<String, dynamic>>();
    final eventSubscription = _importChannel.receiveBroadcastStream().listen((
      event,
    ) {
      importEvents.add(Map<String, dynamic>.from(event as Map));
    });
    var seenExternalIds = const <String>[];
    final consumeEvents = () async {
      await for (final event in importEvents.stream) {
        final workout = event['workout'];
        if (workout is Map) {
          await onWorkout(Map<String, dynamic>.from(workout));
          await _acknowledgePersistedImportWorkout();
          continue;
        }
        onProgress(HealthInventoryInspectProgress.fromMap(event));
        if (event['importFinished'] != true) continue;
        seenExternalIds = [
          for (final id in event['seenExternalIds'] as List? ?? const []) '$id',
        ];
        break;
      }
    }();
    try {
      final workoutCount = await _methodChannel.invokeMethod<int>(
        'fetchRecentCardioWorkouts',
        {
          'maxWorkouts': maxWorkouts,
          'includeRoute': includeRoute,
          'maxRoutePoints': maxRoutePoints,
          'includeHeartRateSeries': includeHeartRateSeries,
          'includeAssociatedSeries': includeAssociatedSeries,
          'skipUnchangedWorkouts': [
            for (final fingerprint in skipUnchanged)
              fingerprint.asHealthKitSkipArgument,
          ],
        },
      );
      await consumeEvents;
      return AppleHealthCardioListing(
        listedCount: workoutCount ?? 0,
        seenExternalIds: seenExternalIds,
      );
    } on MissingPluginException {
      return const AppleHealthCardioListing(
        listedCount: 0,
        seenExternalIds: [],
      );
    } on PlatformException {
      rethrow;
    } finally {
      await eventSubscription.cancel();
      await importEvents.close();
    }
  }

  Future<void> _acknowledgePersistedImportWorkout() async {
    try {
      await _methodChannel.invokeMethod<void>('cardioImportPersisted');
    } on MissingPluginException {
      return;
    }
  }

  Map<String, dynamic> _jsonObjectMap(Map<Object?, Object?> payload) => {
    for (final entry in payload.entries)
      if (entry.key is String)
        entry.key as String: _jsonReadyValue(entry.value),
  };

  Object? _jsonReadyValue(Object? value) {
    if (value is Map) {
      return _jsonObjectMap(Map<Object?, Object?>.from(value));
    }
    if (value is List) {
      return [for (final item in value) _jsonReadyValue(item)];
    }
    return value;
  }

  HealthPermissionStatus _mapStatus(String? status) {
    if (status == null) return HealthPermissionStatus.unknown;
    return HealthPermissionStatus.values.firstWhere(
      (permissionStatus) => permissionStatus.name == status,
      orElse: () => HealthPermissionStatus.unknown,
    );
  }
}
