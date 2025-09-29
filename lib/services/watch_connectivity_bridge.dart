import 'dart:async';

import 'package:flutter/services.dart';

class WatchConnectivityBridge {
  const WatchConnectivityBridge();

  static const EventChannel _channel = EventChannel(
    'com.workouts/watch_connectivity',
  );

  Stream<bool> connectionStream() {
    final controller = StreamController<bool>.broadcast();
    controller.add(false);

    final subscription = _channel
        .receiveBroadcastStream()
        .map((event) => event is bool ? event : false)
        .listen(controller.add, onError: (_) => controller.add(false));

    controller.onCancel = () async {
      await subscription.cancel();
      await controller.close();
    };

    return controller.stream;
  }
}
