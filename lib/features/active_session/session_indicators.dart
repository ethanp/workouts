import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';

class SessionTimerDisplay extends StatelessWidget {
  const SessionTimerDisplay({
    super.key,
    required this.duration,
    required this.isPaused,
  });

  final Duration duration;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    final Duration safeDuration = duration.isNegative
        ? Duration.zero
        : duration;
    final String timeLabel = _formatTimeLabel(safeDuration);
    final String statusLabel = isPaused ? 'Paused' : 'Elapsed';
    final Color statusColor = isPaused
        ? AppColors.warning
        : AppColors.textColor2;
    final TextStyle timeStyle = AppTypography.displayLarge(context).copyWith(
      fontSize: 32,
      letterSpacing: 1.8,
      color: CupertinoColors.white,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final TextStyle statusStyle = AppTypography.caption.copyWith(
      fontSize: 12,
      color: statusColor,
      letterSpacing: 0.9,
      fontWeight: FontWeight.w500,
    );

    return _glowCard(timeLabel, statusLabel, timeStyle, statusStyle);
  }

  String _formatTimeLabel(Duration safeDuration) {
    final hours = safeDuration.inHours;
    final minutes = safeDuration.inMinutes.remainder(60);
    final seconds = safeDuration.inSeconds.remainder(60);
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$mm:$ss'
        : '$mm:$ss';
  }

  Widget _glowCard(
    String timeLabel,
    String statusLabel,
    TextStyle timeStyle,
    TextStyle statusStyle,
  ) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.backgroundDepth5, AppColors.backgroundDepth3],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.borderDepth2),
      boxShadow: [
        BoxShadow(
          color: AppColors.accentPrimary.withValues(alpha: 0.16),
          blurRadius: 14,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(timeLabel, style: timeStyle),
        ),
        const SizedBox(height: 2),
        Text(statusLabel, style: statusStyle),
      ],
    ),
  );
}

class BlockProgressIndicator extends StatelessWidget {
  const BlockProgressIndicator({
    super.key,
    required this.currentIndex,
    required this.totalBlocks,
  });

  final int currentIndex;
  final int totalBlocks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDepth2),
      ),
      child: Text(
        '${currentIndex + 1} of $totalBlocks',
        style: AppTypography.caption.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}

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
