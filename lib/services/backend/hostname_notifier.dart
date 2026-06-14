import 'package:ethan_sync/ethan_sync.dart';

/// The active backend host, backed by ethan_sync's shared [hostResolverProvider].
///
/// Kept as a workouts-named alias so existing consumers (the connection tile,
/// the probe scheduler) need not change. `ref.watch` yields the host string;
/// `.notifier` exposes `setHost` and `refineByTcpProbe`.
final hostnameProvider = hostResolverProvider;
