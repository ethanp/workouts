import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Rich diagnostic snapshot of one backend host candidate (LAN or Tailscale).
///
/// Sister to [HostResolverController], which only cares about which candidate to
/// route traffic to. This carries the per-candidate latency / HTTP status /
/// error string surfaced to the user on the Connection tile.
class HostProbe {
  const HostProbe({
    required this.label,
    required this.host,
    required this.reachable,
    required this.latency,
    required this.httpStatus,
    required this.error,
  });

  final String label;
  final String host;
  final bool reachable;
  final Duration? latency;
  final int? httpStatus;
  final String? error;

  /// Human-readable one-line summary, e.g. `OK 7ms · HTTP 200` or
  /// `unreachable: SocketException…`.
  String get summary {
    if (host.isEmpty) return 'not configured';
    if (reachable) {
      final ms = latency?.inMilliseconds ?? -1;
      final httpPart = httpStatus != null ? ' \u00B7 HTTP $httpStatus' : '';
      return 'OK ${ms}ms$httpPart';
    }
    return error ?? 'unreachable';
  }
}

class HostProbesState {
  const HostProbesState({
    this.probes = const [],
    this.probedAt,
    this.isProbing = false,
  });

  final List<HostProbe> probes;
  final DateTime? probedAt;
  final bool isProbing;

  HostProbesState copyWith({
    List<HostProbe>? probes,
    DateTime? probedAt,
    bool? isProbing,
  }) => HostProbesState(
    probes: probes ?? this.probes,
    probedAt: probedAt ?? this.probedAt,
    isProbing: isProbing ?? this.isProbing,
  );
}

/// Probes the LAN and Tailscale candidates for diagnostic display. Read by
/// the Connection tile on settings; results are independent of the active
/// host selection done by [HostResolverController].
class HostProbesNotifier extends Notifier<HostProbesState> {
  static const _postgrestPort = 3001;
  static const _tcpTimeout = Duration(seconds: 2);
  static const _httpTimeout = Duration(seconds: 3);

  @override
  HostProbesState build() => const HostProbesState();

  Future<void> probe() async {
    if (state.isProbing) return;
    state = state.copyWith(isProbing: true);
    final lan = dotenv.env['SERVER_HOST_LAN'] ?? '';
    final tailscale = dotenv.env['SERVER_HOST_TAILSCALE'] ?? '';
    final probes = await Future.wait([
      _probeOne('LAN', lan, _postgrestPort),
      _probeOne('Tailscale', tailscale, _postgrestPort),
    ]);
    state = HostProbesState(
      probes: probes,
      probedAt: DateTime.now(),
      isProbing: false,
    );
  }

  static Future<HostProbe> _probeOne(
    String label,
    String host,
    int port,
  ) async {
    if (host.isEmpty) {
      return HostProbe(
        label: label,
        host: host,
        reachable: false,
        latency: null,
        httpStatus: null,
        error: 'env var empty',
      );
    }
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: _tcpTimeout);
      socket.destroy();
      final tcpLatency = stopwatch.elapsed;
      int? httpStatus;
      String? httpError;
      try {
        final response = await http
            .get(Uri.parse('http://$host:$port/'))
            .timeout(_httpTimeout);
        httpStatus = response.statusCode;
      } catch (error) {
        httpError = error.toString();
      }
      return HostProbe(
        label: label,
        host: host,
        reachable: true,
        latency: tcpLatency,
        httpStatus: httpStatus,
        error: httpError,
      );
    } catch (error) {
      return HostProbe(
        label: label,
        host: host,
        reachable: false,
        latency: null,
        httpStatus: null,
        error: error.toString(),
      );
    }
  }
}

final hostProbesProvider =
    NotifierProvider<HostProbesNotifier, HostProbesState>(
      HostProbesNotifier.new,
    );
