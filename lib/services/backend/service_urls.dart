import 'package:ethan_sync/ethan_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-service URL providers derived from ethan_sync's [backendEndpointsProvider].
///
/// PowerSync, PostgREST, and the LLM proxy come from shared endpoints. The tile
/// proxy is workouts-only and stays on [BackendEndpoints.urlFor].

const _tileProxyPort = 3004;

final powersyncUrlProvider = Provider<String>(
  (ref) => ref.watch(backendEndpointsProvider).powersyncUrl,
);

final postgrestUrlProvider = Provider<String>(
  (ref) => ref.watch(backendEndpointsProvider).postgrestUrl,
);

final llmProxyUrlProvider = Provider<String>(
  (ref) => ref.watch(backendEndpointsProvider).llmProxyUrl,
);

final tileProxyUrlProvider = Provider<String>(
  (ref) => ref.watch(backendEndpointsProvider).urlFor(_tileProxyPort),
);
