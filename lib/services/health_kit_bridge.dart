import 'dart:async';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/health_permission_status.dart';
import 'package:workouts/models/heart_rate_sample.dart';

class HealthKitBridge {
  HealthKitBridge()
    : _methodChannel = const MethodChannel('com.workouts/health_kit'),
      _heartRateChannel = const EventChannel('com.workouts/heart_rate_stream');

  final MethodChannel _methodChannel;
  final EventChannel _heartRateChannel;
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

  Future<List<Map<String, dynamic>>> fetchRecentCardioWorkouts({
    int maxWorkouts = 20,
    bool includeRoute = false,
    int maxRoutePoints = 1500,
    bool includeHeartRateSeries = true,
  }) async {
    try {
      final payload = await _methodChannel.invokeMethod<List<Object?>>(
        'fetchRecentCardioWorkouts',
        {
          'maxWorkouts': maxWorkouts,
          'includeRoute': includeRoute,
          'maxRoutePoints': maxRoutePoints,
          'includeHeartRateSeries': includeHeartRateSeries,
        },
      );
      if (payload == null) {
        return const [];
      }
      return payload
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  Future<int?> fetchRestingHeartRate({DateTime? nearDate}) async {
    try {
      final arguments = nearDate != null
          ? {'date': nearDate.toUtc().toIso8601String()}
          : null;
      final bpm = await _methodChannel.invokeMethod<int>(
        'fetchRestingHeartRate',
        arguments,
      );
      return bpm;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  HealthPermissionStatus _mapStatus(String? status) {
    return switch (status) {
      'authorized' => HealthPermissionStatus.authorized,
      'limited' => HealthPermissionStatus.limited,
      'denied' => HealthPermissionStatus.denied,
      'unavailable' => HealthPermissionStatus.unavailable,
      _ => HealthPermissionStatus.unknown,
    };
  }
}
