import 'dart:async';

import 'package:flutter/services.dart';

class WatchConnectivityBridge {
  const WatchConnectivityBridge();

  static const EventChannel _connectivityChannel = EventChannel(
    'com.workouts/watch_connectivity',
  );

  static const MethodChannel _workoutChannel = MethodChannel(
    'com.workouts/watch_workout',
  );

  Stream<bool> connectionStream() {
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

  /// Tell the watch to start a workout session for heart rate streaming.
  Future<void> startWatchWorkout({
    required String sessionId,
    double samplingIntervalSeconds = 5.0,
  }) async {
    await _workoutChannel.invokeMethod('startWorkout', {
      'sessionId': sessionId,
      'samplingIntervalSeconds': samplingIntervalSeconds,
    });
  }

  /// Tell the watch to stop the current workout session.
  Future<void> stopWatchWorkout() async {
    await _workoutChannel.invokeMethod('stopWorkout');
  }

  /// Tell the watch to pause the current workout session.
  Future<void> pauseWatchWorkout() async {
    await _workoutChannel.invokeMethod('pauseWorkout');
  }

  /// Tell the watch to resume the current workout session.
  Future<void> resumeWatchWorkout() async {
    await _workoutChannel.invokeMethod('resumeWorkout');
  }
}
