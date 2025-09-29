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

  Future<bool> deleteWorkouts(List<String> uuids) async {
    if (uuids.isEmpty) {
      return true;
    }
    try {
      final result = await _methodChannel.invokeMethod<bool>('deleteWorkouts', {
        'uuids': uuids,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
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
