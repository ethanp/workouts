import 'package:ethan_sync/ethan_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-service URL providers derived from ethan_sync's [backendEndpointsProvider].
///
/// PowerSync and PostgREST come straight from the shared endpoints; the LLM and
/// tile proxies are workouts-only services layered on the same host via
/// [BackendEndpoints.urlFor]. When the host changes, every URL re-emits and
/// dependents react via Riverpod.

const _llmProxyPort = 3002;
const _tileProxyPort = 3004;

final powersyncUrlProvider = Provider<String>(
  (ref) => ref.watch(backendEndpointsProvider).powersyncUrl,
);

final postgrestUrlProvider = Provider<String>(
  (ref) => ref.watch(backendEndpointsProvider).postgrestUrl,
);

final llmProxyUrlProvider = Provider<String>(
  (ref) => ref.watch(backendEndpointsProvider).urlFor(_llmProxyPort),
);

final tileProxyUrlProvider = Provider<String>(
  (ref) => ref.watch(backendEndpointsProvider).urlFor(_tileProxyPort),
);
