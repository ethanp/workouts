import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/services/watch_connectivity_bridge.dart';

const _watchBridge = WatchConnectivityBridge();

final watchConnectionStatusProvider = StreamProvider<bool>((ref) {
  final connectionStatusController = StreamController<bool>();
  connectionStatusController.add(false);

  final subscription = _watchBridge.connectionStream().listen(
    connectionStatusController.add,
    onError: (_) => connectionStatusController.add(false),
  );

  ref.onDispose(() async {
    await subscription.cancel();
    await connectionStatusController.close();
  });

  return connectionStatusController.stream;
});

final watchCommandStreamProvider = StreamProvider<String>((ref) {
  return _watchBridge.commandStream();
});
