import 'package:ethan_sync/ethan_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// PowerSync nav icon. Product overlays stay in other apps.
class const SyncStatusIcon() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ESyncPhaseIcon(
      phase: ref.watch(syncPhaseProvider),
      caption: ref.watch(syncStatusCaptionProvider),
    );
  }
}
