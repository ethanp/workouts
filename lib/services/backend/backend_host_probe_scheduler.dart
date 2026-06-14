import 'dart:async';

import 'package:ethan_sync/ethan_sync.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Decides _when_ to re-probe the backend hostname.
///
/// Knows nothing about PowerSync, LLM, or tiles. Its only job is to call
/// [HostResolverController.refineByTcpProbe]. When the resolver changes state,
/// every URL provider re-emits and dependent services react via Riverpod.
class BackendHostProbeScheduler {
  BackendHostProbeScheduler(this._container);

  final ProviderContainer _container;

  Future<void> probeNow() =>
      _container.read(hostResolverProvider.notifier).refineByTcpProbe();

  void scheduleAfterFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(probeNow());
    });
  }
}
