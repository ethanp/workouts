import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/cardio/cardio_browse_providers.dart';
import 'package:workouts/features/cardio/cardio_import_controller.dart';
import 'package:workouts/features/history/activity_provider.dart';

/// Apple Health catalog sync. Heart-rate zones are computed before sync
/// reports done.
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
            'Pulls new and changed cardio from Apple Health, then saves any outdoor GPS that isn’t stored yet. Workouts that are already stored stay put.',
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
            SelectableText(
              importErrorMessage,
              style: EText.caption.copyWith(color: EColors.danger),
            ),
          ],
          ..._backfillSection(missingCount, backfillStatus, isImporting, ref),
          const SizedBox(height: ELayout.spaceSm),
          _pullAllWorkoutsButton(
            isBackfilling: backfillStatus.inProgress,
            isImporting: isImporting,
            ref: ref,
          ),
          const SizedBox(height: ELayout.spaceXs),
          Text(
            'Replaces every stored workout since Apr 14, 2026, computes zones again, and saves any outdoor GPS that isn’t stored yet.',
            style: EText.caption.copyWith(color: EColors.textMuted),
          ),
          const SizedBox(height: ELayout.spaceSm),
          _storeRoutesButton(
            isBackfilling: backfillStatus.inProgress,
            isImporting: isImporting,
            ref: ref,
          ),
          const SizedBox(height: ELayout.spaceXs),
          Text(
            'Same GPS save, without pulling workouts again.',
            style: EText.caption.copyWith(color: EColors.textMuted),
          ),
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
              'Sync from Apple Health',
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
        importProgress.status.isNotEmpty
            ? importProgress.status
            : 'Reading Apple Health…',
        style: EText.caption.copyWith(color: EColors.textTertiary),
      ),
      if (importProgress.totalWorkouts > 0) ...[
        const SizedBox(height: ELayout.spaceXs),
        Text(
          '${importProgress.processedWorkouts}/${importProgress.totalWorkouts}',
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
    ],
  );

  Widget _pullAllWorkoutsButton({
    required bool isBackfilling,
    required bool isImporting,
    required WidgetRef ref,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: EColors.surface,
          disabledBackgroundColor: EColors.surface,
          padding: const EdgeInsets.symmetric(vertical: ELayout.spaceSm),
        ),
        onPressed: isBackfilling || isImporting
            ? null
            : () => ref
                  .read(cardioImportControllerProvider.notifier)
                  .importRecentWorkouts(replaceStored: true),
        child: Text(
          'Pull all workouts',
          style: EText.body.medium.copyWith(color: EColors.textPrimary),
        ),
      ),
    );
  }

  Widget _storeRoutesButton({
    required bool isBackfilling,
    required bool isImporting,
    required WidgetRef ref,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: EColors.surface,
          disabledBackgroundColor: EColors.surface,
          padding: const EdgeInsets.symmetric(vertical: ELayout.spaceSm),
        ),
        onPressed: isBackfilling || isImporting
            ? null
            : () => ref
                  .read(cardioImportControllerProvider.notifier)
                  .storeRoutes(),
        child: Text(
          'Store routes',
          style: EText.body.medium.copyWith(color: EColors.textPrimary),
        ),
      ),
    );
  }

  /// Returns the backfill section as a list so the parent can splat it
  /// without leaving a dangling spacer when there's nothing to show.
  List<Widget> _backfillSection(
    int missingCount,
    MetricsBackfillStatus backfillStatus,
    bool isImporting,
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
          '$missingCount workout${missingCount == 1 ? '' : 's'} missing zone data. '
          'Sync computes these newest first.',
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
            onPressed: isBackfilling || isImporting
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
            color: backfillStatus.failed
                ? EColors.danger
                : isBackfilling
                ? EColors.textTertiary
                : EColors.success,
          ),
        ),
      ],
    ];
  }
}
