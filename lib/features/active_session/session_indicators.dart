import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';

class WatchConnectionIndicator extends StatelessWidget {
  const WatchConnectionIndicator({super.key, required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? AppColors.success : AppColors.textColor3;
    final background = isConnected
        ? AppColors.success.withValues(alpha: 0.15)
        : AppColors.backgroundDepth3;
    final icon = isConnected
        ? CupertinoIcons.check_mark_circled_solid
        : CupertinoIcons.exclamationmark_triangle_fill;
    final label = isConnected ? 'Watch connected' : 'Watch offline';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTypography.caption.copyWith(color: color)),
        ],
      ),
    );
  }
}
