import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/cardio/cardio_provider.dart';
import 'package:workouts/features/history/activity_provider.dart';

/// Single tile that drives the two-step Apple Health workflow: import recent
/// cardio workouts, then compute heart rate zones for any that are missing.
class const AppleHealthSyncTile() extends ConsumerWidget {
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
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Apple Health', style: EText.section),
          const SizedBox(height: ELayout.spaceXs),
          Text(
            'Import recent workouts from Apple Health and compute their heart rate zones.',
            style: EText.body.medium.copyWith(color: EColors.textTertiary),
          ),
          const SizedBox(height: ELayout.spaceMd),
          _importButton(isImporting, ref),
          if (isImporting) ...[
            const SizedBox(height: ELayout.spaceSm),
            _importProgressSection(importProgress),
          ] else if (importProgress.status.isNotEmpty) ...[
            const SizedBox(height: ELayout.spaceXs),
            Text(
              importProgress.status,
              style: EText.caption.copyWith(color: EColors.success),
            ),
          ],
          if (importErrorMessage != null) ...[
            const SizedBox(height: ELayout.spaceSm),
            Text(
              importErrorMessage,
              style: EText.caption.copyWith(color: EColors.danger),
            ),
          ],
          ..._backfillSection(missingCount, backfillStatus, ref),
        ],
      ),
    );
  }

  Widget _importButton(bool isImporting, WidgetRef ref) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: isImporting
          ? null
          : () => ref
                .read(cardioImportControllerProvider.notifier)
                .importRecentWorkouts(),
      child: isImporting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'Import workouts',
              style: TextStyle(
                color: Colors.white,
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
        style: EText.caption.copyWith(color: EColors.textTertiary),
      ),
      const SizedBox(height: ELayout.spaceXs),
      ClipRRect(
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
        child: Container(
          height: 6,
          color: EColors.surface,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: importProgress.progressFraction.clamp(0.0, 1.0),
            child: Container(color: EColors.accent),
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
      const SizedBox(height: ELayout.spaceMd),
      if (hasMissing)
        Text(
          '$missingCount workout${missingCount == 1 ? '' : 's'} missing zone data',
          style: EText.caption.copyWith(color: EColors.warning),
        ),
      if (hasMissing || isBackfilling) ...[
        if (hasMissing) const SizedBox(height: ELayout.spaceSm),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: EColors.surface,
              disabledBackgroundColor: EColors.surface,
              padding: const EdgeInsets.symmetric(vertical: ELayout.spaceSm),
            ),
            onPressed: isBackfilling
                ? null
                : () => ref
                      .read(metricsBackfillControllerProvider.notifier)
                      .runBackfill(),
            child: isBackfilling
                ? const CircularProgressIndicator()
                : Text(
                    'Compute missing zones',
                    style: EText.body.medium.copyWith(
                      color: EColors.textPrimary,
                    ),
                  ),
          ),
        ),
      ],
      if (hasStatusLabel) ...[
        const SizedBox(height: ELayout.spaceXs),
        Text(
          backfillStatus.label,
          style: EText.caption.copyWith(
            color: isBackfilling ? EColors.textTertiary : EColors.success,
          ),
        ),
      ],
    ];
  }
}
