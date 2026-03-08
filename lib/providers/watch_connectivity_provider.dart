import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/services/watch_connectivity_bridge.dart';

const _watchBridge = WatchConnectivityBridge();

final watchConnectionStatusProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>();
  controller.add(false);

  final subscription = _watchBridge.connectionStream().listen(
    controller.add,
    onError: (_) => controller.add(false),
  );

  ref.onDispose(() async {
    await subscription.cancel();
    await controller.close();
  });

  return controller.stream;
});

final watchCommandStreamProvider = StreamProvider<String>((ref) {
  return _watchBridge.commandStream();
});
