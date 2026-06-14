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
class ExerciseCardMenuButton extends ConsumerWidget {
  const ExerciseCardMenuButton({
    super.key,
    required this.exerciseName,
    this.onHistoryPressed,
    this.onAskAiPressed,
    this.onReplacePressed,
    this.onToggleStoppedEarly,
    this.isStoppedEarly = false,
  });

  final String exerciseName;
  final VoidCallback? onHistoryPressed;
  final VoidCallback? onAskAiPressed;
  final VoidCallback? onReplacePressed;
  final VoidCallback? onToggleStoppedEarly;
  final bool isStoppedEarly;

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
      if (onHistoryPressed != null)
        _MenuItem(
          icon: CupertinoIcons.clock,
          label: 'History',
          onPressed: onHistoryPressed!,
        ),
      if (onAskAiPressed != null && !isOffline)
        _MenuItem(
          icon: CupertinoIcons.sparkles,
          label: 'Ask AI Coach',
          onPressed: onAskAiPressed!,
        ),
      if (onToggleStoppedEarly != null)
        _MenuItem(
          icon: isStoppedEarly ? CupertinoIcons.flag_fill : CupertinoIcons.flag,
          iconColor: isStoppedEarly ? AppColors.warning : null,
          label: isStoppedEarly ? 'Resume exercise' : 'Stop early',
          onPressed: onToggleStoppedEarly!,
        ),
      if (onReplacePressed != null)
        _MenuItem(
          icon: CupertinoIcons.arrow_2_squarepath,
          label: 'Swap exercise',
          onPressed: onReplacePressed!,
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
                  item.onPressed();
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

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final VoidCallback onPressed;
}
