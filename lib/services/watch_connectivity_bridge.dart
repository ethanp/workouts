import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class WatchConnectivityBridge {
  const WatchConnectivityBridge();

  static const EventChannel _connectivityChannel = EventChannel(
    'com.workouts/watch_connectivity',
  );

  static const EventChannel _commandChannel = EventChannel(
    'com.workouts/watch_commands',
  );

  static const MethodChannel _workoutChannel = MethodChannel(
    'com.workouts/watch_workout',
  );

  Stream<bool> connectionStream() {
    if (!Platform.isIOS) return Stream.value(false);

    final controller = StreamController<bool>.broadcast();
    controller.add(false);

    final subscription = _connectivityChannel
        .receiveBroadcastStream()
        .map((event) => event is bool ? event : false)
        .listen(controller.add, onError: (_) => controller.add(false));

    controller.onCancel = () async {
      await subscription.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  Stream<String> commandStream() {
    if (!Platform.isIOS) return const Stream.empty();

    return _commandChannel
        .receiveBroadcastStream()
        .where((event) => event is String)
        .cast<String>();
  }

  Future<void> startWatchWorkout({
    required String sessionId,
    double samplingIntervalSeconds = 5.0,
  }) async {
    if (!Platform.isIOS) return;
    await _workoutChannel.invokeMethod('startWorkout', {
      'sessionId': sessionId,
      'samplingIntervalSeconds': samplingIntervalSeconds,
    });
  }

  Future<void> stopWatchWorkout() async {
    if (!Platform.isIOS) return;
    await _workoutChannel.invokeMethod('stopWorkout');
  }

  Future<void> pauseWatchWorkout() async {
    if (!Platform.isIOS) return;
    await _workoutChannel.invokeMethod('pauseWorkout');
  }

  Future<void> resumeWatchWorkout() async {
    if (!Platform.isIOS) return;
    await _workoutChannel.invokeMethod('resumeWorkout');
  }
}
