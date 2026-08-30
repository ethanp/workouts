import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ethan_sync/ethan_sync.dart' show isOfflineProvider;
import 'package:workouts/theme/app_theme.dart';

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

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      minimumSize: const Size(28, 28),
      onPressed: () => _showSheet(context, items),
      child: const Icon(
        CupertinoIcons.ellipsis_circle,
        size: 22,
        color: AppColors.textColor3,
      ),
    );
  }

  List<_MenuItem> _buildItems({required bool isOffline}) {
    return [
      if (onExerciseHistoryRequested != null)
        _MenuItem(
          icon: CupertinoIcons.clock,
          label: 'History',
          onActivated: onExerciseHistoryRequested!,
        ),
      if (onAiCoachRequested != null && !isOffline)
        _MenuItem(
          icon: CupertinoIcons.sparkles,
          label: 'Ask AI Coach',
          onActivated: onAiCoachRequested!,
        ),
      if (onToggleStoppedEarly != null)
        _MenuItem(
          icon: isStoppedEarly ? CupertinoIcons.flag_fill : CupertinoIcons.flag,
          iconColor: isStoppedEarly ? AppColors.warning : null,
          label: isStoppedEarly ? 'Resume exercise' : 'Stop early',
          onActivated: onToggleStoppedEarly!,
        ),
      if (onExerciseSwapRequested != null)
        _MenuItem(
          icon: CupertinoIcons.arrow_2_squarepath,
          label: 'Swap exercise',
          onActivated: onExerciseSwapRequested!,
        ),
    ];
  }

  void _showSheet(BuildContext context, List<_MenuItem> items) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: Text(exerciseName),
        actions: items
            .map(
              (item) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(popupContext).pop();
                  item.onActivated();
                },
                child: _itemRow(item),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(popupContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _itemRow(_MenuItem item) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        item.icon,
        size: 20,
        color: item.iconColor ?? AppColors.accentPrimary,
      ),
      const SizedBox(width: AppSpacing.sm),
      Text(item.label),
    ],
  );
}

class const _MenuItem({
  required final IconData icon,
  required final String label,
  required final VoidCallback onActivated,
  final Color? iconColor,
});
