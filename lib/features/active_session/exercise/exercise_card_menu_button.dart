import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ethan_sync/ethan_sync.dart' show isOfflineProvider;

/// A single ellipsis button on an exercise card header that opens an action
/// sheet listing every per-exercise affordance — history, AI coach, stop
/// early flag, swap exercise. Replaces what used to be four cryptic icons
/// inline in the header.
///
/// Each action is opt-in: pass `null` for the callback to hide the row.
/// The "Ask AI Coach" row is additionally hidden whenever the backend is
/// unreachable (mirrors the gating used by other AI affordances).
class const ExerciseCardMenuButton({
  required final String exerciseName,
  final VoidCallback? onExerciseHistoryRequested,
  final VoidCallback? onAiCoachRequested,
  final VoidCallback? onExerciseSwapRequested,
  final VoidCallback? onToggleStoppedEarly,
  final bool isStoppedEarly = false,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isOffline = ref.watch(isOfflineProvider);
    final List<_MenuItem> items = _buildItems(isOffline: isOffline);
    if (items.isEmpty) return const SizedBox.shrink();

    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: 'Exercise actions',
      onPressed: () => _showSheet(context, items),
      icon: const Icon(Icons.more_horiz, size: 22, color: EColors.textTertiary),
    );
  }

  List<_MenuItem> _buildItems({required bool isOffline}) {
    return [
      if (onExerciseHistoryRequested != null)
        _MenuItem(
          icon: Icons.schedule,
          label: 'History',
          onActivated: onExerciseHistoryRequested!,
        ),
      if (onAiCoachRequested != null && !isOffline)
        _MenuItem(
          icon: Icons.auto_awesome,
          label: 'Ask AI Coach',
          onActivated: onAiCoachRequested!,
        ),
      if (onToggleStoppedEarly != null)
        _MenuItem(
          icon: isStoppedEarly ? Icons.flag : Icons.outlined_flag,
          iconColor: isStoppedEarly ? EColors.warning : null,
          label: isStoppedEarly ? 'Resume exercise' : 'Stop early',
          onActivated: onToggleStoppedEarly!,
        ),
      if (onExerciseSwapRequested != null)
        _MenuItem(
          icon: Icons.swap_horiz,
          label: 'Swap exercise',
          onActivated: onExerciseSwapRequested!,
        ),
    ];
  }

  void _showSheet(BuildContext context, List<_MenuItem> items) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: EColors.backgroundLift,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ELayout.spaceLg,
                ELayout.spaceLg,
                ELayout.spaceLg,
                ELayout.spaceSm,
              ),
              child: Text(exerciseName, style: EText.section),
            ),
            for (final item in items)
              ListTile(
                leading: Icon(
                  item.icon,
                  color: item.iconColor ?? EColors.accent,
                ),
                title: Text(item.label),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  item.onActivated();
                },
              ),
            ListTile(
              title: const Text('Cancel'),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class const _MenuItem({
  required final IconData icon,
  required final String label,
  required final VoidCallback onActivated,
  final Color? iconColor,
});
