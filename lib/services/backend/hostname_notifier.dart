import 'dart:io';

import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _log = ELogger('HostnameNotifier');

/// Owns the current backend hostname.
///
/// Two `.env` candidates: `SERVER_HOST_LAN` (preferred when at home — fast)
/// and `SERVER_HOST_TAILSCALE` (fallback when traveling). [refineByTcpProbe]
/// picks the first reachable one. If neither answers, it parks on the last
/// candidate (Tailscale) on the assumption that the user is more likely to
/// fix Tailscale than to suddenly be back on the home LAN — so PowerSync's
/// existing retry timer lands on a routable host the moment connectivity
/// returns, with no further app-side action.
class HostnameNotifier extends Notifier<String> {
  static const _postgrestPort = 3001;
  static const _probeTimeout = Duration(seconds: 1);

  @override
  String build() => _candidatesFromEnv().first;

  /// Manual override for the active host (e.g. from the Connection tile's
  /// per-route "Use" button). No-op when [host] already matches state.
  /// Subsequent auto-probes are not re-run; the user's choice sticks for
  /// the rest of this app session.
  void setHost(String host) {
    if (host == state) return;
    _log.log('Manual host override: $state -> $host');
    state = host;
  }

  /// Returns true if the hostname changed.
  Future<bool> refineByTcpProbe() async {
    final hostBefore = state;
    final candidates = _candidatesFromEnv();

    for (final candidate in candidates) {
      if (await _tcpReachable(candidate, _postgrestPort)) {
        if (candidate != state) {
          _log.log('Probe selected $candidate');
          state = candidate;
        }
        return state != hostBefore;
      }
    }

    final parkOn = candidates.last;
    if (parkOn != state) {
      _log.warn(
        'No candidate reachable on port $_postgrestPort; parking on $parkOn',
      );
      state = parkOn;
    } else {
      _log.warn(
        'No candidate reachable on port $_postgrestPort; staying on $state',
      );
    }
    return state != hostBefore;
  }

  static List<String> _candidatesFromEnv() {
    final lan = dotenv.env['SERVER_HOST_LAN'];
    final tailscale = dotenv.env['SERVER_HOST_TAILSCALE'];
    final candidates = [
      if (lan != null && lan.isNotEmpty) lan,
      if (tailscale != null && tailscale.isNotEmpty && tailscale != lan)
        tailscale,
    ];
    if (candidates.isEmpty) {
      throw StateError(
        'No SERVER_HOST_LAN or SERVER_HOST_TAILSCALE configured in .env',
      );
    }
    return candidates;
  }

  static Future<bool> _tcpReachable(String hostname, int port) async {
    try {
      final socket = await Socket.connect(
        hostname,
        port,
        timeout: _probeTimeout,
      );
      socket.destroy();
      return true;
    } on SocketException catch (socketException) {
      _log.log('$hostname:$port not reachable: $socketException');
      return false;
    }
  }
}

final hostnameProvider = NotifierProvider<HostnameNotifier, String>(
  HostnameNotifier.new,
);
