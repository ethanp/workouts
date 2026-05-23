import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/services/backend/hostname_notifier.dart';

/// Decides _when_ to re-probe the backend hostname.
///
/// Knows nothing about PowerSync, LLM, or tiles. Its only job is to call
/// [HostnameNotifier.refineByTcpProbe]. When the notifier changes state,
/// every URL provider re-emits and dependent services react via Riverpod.
class BackendHostProbeScheduler {
  BackendHostProbeScheduler(this._container);

  final ProviderContainer _container;

  Future<void> probeNow() =>
      _container.read(hostnameProvider.notifier).refineByTcpProbe();

  void scheduleAfterFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(probeNow());
    });
  }
}
