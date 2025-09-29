import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/services/watch_connectivity_bridge.dart';

final watchConnectionStatusProvider = StreamProvider<bool>((ref) {
  final bridge = WatchConnectivityBridge();
  final controller = StreamController<bool>();
  controller.add(false);

  final subscription = bridge.connectionStream().listen(
    controller.add,
    onError: (_) => controller.add(false),
  );

  ref.onDispose(() async {
    await subscription.cancel();
    await controller.close();
  });

  return controller.stream;
});
