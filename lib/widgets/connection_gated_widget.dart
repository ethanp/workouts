import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ethan_sync/ethan_sync.dart' show isOfflineProvider;

/// Hides [child] whenever the PowerSync backend is not connected.
///
/// Use this to gate any UI that depends on the backend being reachable —
/// most notably AI-powered features that call the LLM proxy.
class ConnectionGatedWidget extends ConsumerWidget {
  const ConnectionGatedWidget({
    super.key,
    required this.child,
    this.offlinePlaceholder = const SizedBox.shrink(),
  });

  final Widget child;
  final Widget offlinePlaceholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isOffline = ref.watch(isOfflineProvider);
    if (isOffline) return offlinePlaceholder;
    return child;
  }
}
