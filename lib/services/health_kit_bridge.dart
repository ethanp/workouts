import 'dart:async';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
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
    int maxWorkouts = 40,
  }) async {
    try {
      final payload = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'inspectRecentCardioWorkouts',
        {'maxWorkouts': maxWorkouts},
      );
      if (payload == null) return const {};
      return Map<String, dynamic>.from(payload);
    } on MissingPluginException {
      return const {};
    } on PlatformException {
      return const {};
    }
  }

  Future<int> importCardioWorkouts({
    int maxWorkouts = 0,
    bool includeRoute = true,
    int maxRoutePoints = 1500,
    bool includeHeartRateSeries = true,
    bool includeAssociatedSeries = true,
    required void Function(HealthInventoryInspectProgress progress) onProgress,
    required Future<void> Function(Map<String, dynamic> workout) onWorkout,
  }) async {
    final importEvents = StreamController<Map<String, dynamic>>();
    final eventSubscription = _importChannel.receiveBroadcastStream().listen((
      event,
    ) {
      importEvents.add(Map<String, dynamic>.from(event as Map));
    });
    final consumeEvents = () async {
      await for (final event in importEvents.stream) {
        final workout = event['workout'];
        if (workout is Map) {
          await onWorkout(Map<String, dynamic>.from(workout));
          continue;
        }
        onProgress(HealthInventoryInspectProgress.fromMap(event));
        if (event['importFinished'] == true) break;
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
        },
      );
      await consumeEvents;
      return workoutCount ?? 0;
    } on MissingPluginException {
      return 0;
    } on PlatformException {
      rethrow;
    } finally {
      await eventSubscription.cancel();
      await importEvents.close();
    }
  }

  HealthPermissionStatus _mapStatus(String? status) {
    if (status == null) return HealthPermissionStatus.unknown;
    return HealthPermissionStatus.values.firstWhere(
      (permissionStatus) => permissionStatus.name == status,
      orElse: () => HealthPermissionStatus.unknown,
    );
  }
}
