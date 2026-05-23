import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/services/backend/hostname_notifier.dart';

/// Per-service URL providers, derived from [hostnameProvider].
///
/// Each consumer depends on exactly one of these — a single string. Nobody
/// outside this file needs to know about hostname resolution, ports, or
/// the candidate list. When the hostname changes (LAN ↔ Tailscale fallback),
/// every URL provider re-emits, and dependents (PowerSync, LLM, tile widgets)
/// react via Riverpod.

const _powersyncPort = 8081;
const _postgrestPort = 3001;
const _llmProxyPort = 3002;
const _tileProxyPort = 3004;

final powersyncUrlProvider = Provider<String>(
  (ref) => 'http://${ref.watch(hostnameProvider)}:$_powersyncPort',
);

final postgrestUrlProvider = Provider<String>(
  (ref) => 'http://${ref.watch(hostnameProvider)}:$_postgrestPort',
);

final llmProxyUrlProvider = Provider<String>(
  (ref) => 'http://${ref.watch(hostnameProvider)}:$_llmProxyPort',
);

final tileProxyUrlProvider = Provider<String>(
  (ref) => 'http://${ref.watch(hostnameProvider)}:$_tileProxyPort',
);
