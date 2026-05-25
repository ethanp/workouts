import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/cardio/cardio_provider.dart';
import 'package:workouts/features/history/activity_provider.dart';
import 'package:workouts/theme/app_theme.dart';

/// Single tile that drives the two-step Apple Health workflow: import recent
/// cardio workouts, then compute heart rate zones for any that are missing.
class AppleHealthSyncTile extends ConsumerWidget {
  const AppleHealthSyncTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importAsync = ref.watch(cardioImportControllerProvider);
    final importProgress =
        importAsync.value ?? const CardioImportProgress.idle();
    final isImporting = importProgress.inProgress;

    final backfillStatus = ref.watch(metricsBackfillControllerProvider);
    final missingCountAsync = ref.watch(workoutsMissingMetricsCountProvider);
    final missingCount = missingCountAsync.value ?? 0;

    final importErrorMessage = importAsync.hasError
        ? '${importAsync.error}'
        : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Apple Health', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Import recent workouts from Apple Health and compute their heart rate zones.',
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          ),
          const SizedBox(height: AppSpacing.md),
          _importButton(isImporting, ref),
          if (isImporting) ...[
            const SizedBox(height: AppSpacing.sm),
            _importProgressSection(importProgress),
          ] else if (importProgress.status.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              importProgress.status,
              style: AppTypography.caption.copyWith(color: AppColors.success),
            ),
          ],
          if (importErrorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              importErrorMessage,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ],
          ..._backfillSection(missingCount, backfillStatus, ref),
        ],
      ),
    );
  }

  Widget _importButton(bool isImporting, WidgetRef ref) => SizedBox(
    width: double.infinity,
    child: CupertinoButton.filled(
      onPressed: isImporting
          ? null
          : () => ref
                .read(cardioImportControllerProvider.notifier)
                .importRecentWorkouts(),
      child: isImporting
          ? const CupertinoActivityIndicator(color: CupertinoColors.white)
          : const Text(
              'Import workouts',
              style: TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
    ),
  );

  Widget _importProgressSection(CardioImportProgress importProgress) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Importing ${importProgress.processedWorkouts}/${importProgress.totalWorkouts}',
        style: AppTypography.caption.copyWith(color: AppColors.textColor3),
      ),
      const SizedBox(height: AppSpacing.xs),
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          height: 6,
          color: AppColors.backgroundDepth3,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: importProgress.progressFraction.clamp(0.0, 1.0),
            child: Container(color: AppColors.accentPrimary),
          ),
        ),
      ),
    ],
  );

  /// Returns the backfill section as a list so the parent can splat it
  /// without leaving a dangling spacer when there's nothing to show.
  List<Widget> _backfillSection(
    int missingCount,
    MetricsBackfillStatus backfillStatus,
    WidgetRef ref,
  ) {
    final hasMissing = missingCount > 0;
    final isBackfilling = backfillStatus.inProgress;
    final hasStatusLabel = backfillStatus.label.isNotEmpty;
    if (!hasMissing && !isBackfilling && !hasStatusLabel) return const [];

    return [
      const SizedBox(height: AppSpacing.md),
      if (hasMissing)
        Text(
          '$missingCount workout${missingCount == 1 ? '' : 's'} missing zone data',
          style: AppTypography.caption.copyWith(color: AppColors.warning),
        ),
      if (hasMissing || isBackfilling) ...[
        if (hasMissing) const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: AppColors.backgroundDepth3,
            disabledColor: AppColors.backgroundDepth3,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            onPressed: isBackfilling
                ? null
                : () => ref
                      .read(metricsBackfillControllerProvider.notifier)
                      .runBackfill(),
            child: isBackfilling
                ? const CupertinoActivityIndicator()
                : Text(
                    'Compute missing zones',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textColor1,
                    ),
                  ),
          ),
        ),
      ],
      if (hasStatusLabel) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          backfillStatus.label,
          style: AppTypography.caption.copyWith(
            color: isBackfilling ? AppColors.textColor3 : AppColors.success,
          ),
        ),
      ],
    ];
  }
}
