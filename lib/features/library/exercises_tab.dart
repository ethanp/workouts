import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/features/library/bulk_benefits_provider.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:ethan_sync/ethan_sync.dart' show isOfflineProvider;
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/repositories/library_exercise_store.dart';
import 'package:workouts/theme/exercise_modality_palette.dart';
import 'package:workouts/widgets/connection_gated_widget.dart';
import 'package:workouts/widgets/exercise_benefits_sheet.dart';

class const ExercisesTab({required final VoidCallback onGenerateAllBenefits})
    extends ConsumerStatefulWidget {
  @override
  ConsumerState<ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState() extends ConsumerState<ExercisesTab> {
  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(allExercisesProvider);
    final bulkProgress = ref.watch(bulkBenefitsControllerProvider);

    return exercisesAsync.when(
      data: (exercises) => _ExercisesBody(
        exercises: exercises,
        bulkProgress: bulkProgress,
        onGenerateAll: widget.onGenerateAllBenefits,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error: $error',
          style: EText.body.medium.copyWith(color: EColors.danger),
        ),
      ),
    );
  }
}

class const _ExercisesBody({
  required final List<WorkoutExercise> exercises,
  required final BulkBenefitsProgress? bulkProgress,
  required final VoidCallback onGenerateAll,
}) extends ConsumerWidget {
  bool get _hasMissingBenefits =>
      exercises.any((exercise) => exercise.benefits.isEmpty);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isOffline = ref.watch(isOfflineProvider);
    return CustomScrollView(slivers: _librarySections(context, isOffline));
  }

  List<Widget> _librarySections(BuildContext context, bool isOffline) {
    return [
      _exerciseCountHeader(),
      ..._benefitsGenerationBanners(isOffline),
      if (exercises.isEmpty) _emptyLibrary() else _exerciseRows(exercises),
      SliverToBoxAdapter(
        child: SizedBox(height: 32 + context.overlaidTabBarInset),
      ),
    ];
  }

  Widget _exerciseCountHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ELayout.spaceLg,
          ELayout.spaceMd,
          ELayout.spaceLg,
          ELayout.spaceSm,
        ),
        child: Text(
          '${exercises.length} exercises',
          style: EText.caption.copyWith(color: EColors.textMuted),
        ),
      ),
    );
  }

  List<Widget> _benefitsGenerationBanners(bool isOffline) {
    if (bulkProgress != null) {
      return [
        SliverToBoxAdapter(
          child: _GeneratingProgressBanner(progress: bulkProgress!),
        ),
      ];
    }
    if (_hasMissingBenefits && !isOffline) {
      return [
        SliverToBoxAdapter(
          child: _GenerateAllBanner(onGenerateAllBenefits: onGenerateAll),
        ),
      ];
    }
    return [];
  }

  Widget _emptyLibrary() {
    return SliverFillRemaining(
      child: Center(
        child: Text(
          'No exercises yet',
          style: EText.caption.copyWith(color: EColors.textMuted),
        ),
      ),
    );
  }

  Widget _exerciseRows(List<WorkoutExercise> filteredExercises) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceLg,
        vertical: ELayout.spaceSm,
      ),
      sliver: SliverList.separated(
        itemCount: filteredExercises.length,
        separatorBuilder: (_, _) => Container(
          height: 1,
          margin: const EdgeInsets.only(left: 48),
          color: EColors.border,
        ),
        itemBuilder: (context, exerciseIndex) =>
            _ExerciseRow(exercise: filteredExercises[exerciseIndex]),
      ),
    );
  }
}

class const _GenerateAllBanner({
  required final VoidCallback onGenerateAllBenefits,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ELayout.spaceLg,
        ELayout.spaceSm,
        ELayout.spaceLg,
        ELayout.spaceXs,
      ),
      child: InkWell(
        onTap: onGenerateAllBenefits,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        child: _bannerCard(),
      ),
    );
  }

  Widget _bannerCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceLg,
        vertical: ELayout.spaceMd,
      ),
      decoration: BoxDecoration(
        color: EColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(
          color: EColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome,
            size: 18,
            color: EColors.warning,
          ),
          const SizedBox(width: ELayout.spaceMd),
          Expanded(child: _bannerText()),
          const Icon(
            Icons.chevron_right,
            size: 14,
            color: EColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _bannerText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Generate All Benefits',
          style: EText.body.medium.copyWith(
            color: EColors.warning,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'Use AI to auto-generate benefits and link them to your goals.',
          style: EText.caption.copyWith(
            color: EColors.warning.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class const _GeneratingProgressBanner({
  required final BulkBenefitsProgress progress,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ELayout.spaceLg,
        ELayout.spaceSm,
        ELayout.spaceLg,
        ELayout.spaceXs,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ELayout.spaceLg,
          vertical: ELayout.spaceMd,
        ),
        decoration: BoxDecoration(
          color: EColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(ELayout.radiusMd),
          border: Border.all(
            color: EColors.warning.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: ELayout.spaceMd),
            Expanded(
              child: Text(
                progress.label,
                style: EText.body.medium.copyWith(
                  color: EColors.warning,
                ),
              ),
            ),
            Text(
              '${((progress.completed / progress.total) * 100).round()}%',
              style: EText.caption.copyWith(
                color: EColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: ELayout.spaceSm),
            IconButton(
              tooltip: 'Cancel',
              onPressed: () =>
                  ref.read(bulkBenefitsControllerProvider.notifier).cancel(),
              icon: const Icon(
                Icons.stop_circle,
                size: 20,
                color: EColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class const _ExerciseRow({required final WorkoutExercise exercise})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _openBenefitsSheet(context),
      child: _rowContent(context, ref),
    );
  }

  Widget _rowContent(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: ELayout.spaceMd),
      color: Colors.transparent,
      child: Row(
        children: [
          _ModalityIcon(modality: exercise.modality),
          const SizedBox(width: ELayout.spaceMd),
          Expanded(child: _exerciseDetails()),
          _UnilateralToggle(exercise: exercise),
          if (exercise.benefits.isEmpty)
            ConnectionGatedWidget(child: _sparkleButton(context)),
        ],
      ),
    );
  }

  Widget _exerciseDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exercise.name,
          style: EText.body.medium.copyWith(color: EColors.textPrimary),
        ),
        const SizedBox(height: 2),
        _exerciseMeta(),
      ],
    );
  }

  Widget _exerciseMeta() {
    final benefitCount = exercise.benefits.length;
    return Wrap(
      spacing: ELayout.spaceSm,
      runSpacing: ELayout.spaceXs,
      children: [
        _ModalityPill(modality: exercise.modality),
        _SetMetricsPill(label: exercise.setMetrics.label),
        Text(
          benefitCount == 0
              ? 'No benefits'
              : '$benefitCount ${benefitCount == 1 ? 'benefit' : 'benefits'}',
          style: EText.caption.copyWith(
            fontSize: 12,
            color: benefitCount == 0
                ? EColors.textMuted
                : EColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _sparkleButton(BuildContext context) {
    return IconButton(
      tooltip: 'Generate benefits',
      onPressed: () => _openBenefitsSheet(context, autoGenerate: true),
      icon: const Icon(
        Icons.auto_awesome,
        size: 18,
        color: EColors.warning,
      ),
    );
  }

  void _openBenefitsSheet(BuildContext context, {bool autoGenerate = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseBenefitsSheet(
          exercise: exercise,
          autoGenerate: autoGenerate,
        ),
      ),
    );
  }
}

/// Inline switch on the library tile that flips an exercise between bilateral
/// and unilateral. Persists immediately via [LibraryExerciseStore] so the
/// next session honors the change. Kept compact — label + small switch — so
/// it doesn't dominate the row, but still recognizable so users can fix
/// catalog rows without an extra "edit exercise" sheet.
class const _UnilateralToggle({required final WorkoutExercise exercise})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: ELayout.spaceXs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Unilateral',
            style: EText.caption.copyWith(
              fontSize: 11,
              color: EColors.textTertiary,
            ),
          ),
          const SizedBox(width: ELayout.spaceXs),
          Transform.scale(
            scale: 0.7,
            child: Switch(
              value: exercise.isUnilateral,
              onChanged: (next) => _toggle(ref, next),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(WidgetRef ref, bool next) async {
    final powerSync = await ref.read(powerSyncDatabaseProvider.future);
    final store = LibraryExerciseStore(powerSync);
    await store.upsert(exercise.copyWith(isUnilateral: next));
    ref.invalidate(allExercisesProvider);
  }
}

class const _SetMetricsPill({required final String label})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: EColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: EColors.accent,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class const _ModalityIcon({required final ExerciseModality modality})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: modality.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Icon(_icon, size: 16, color: modality.color),
    );
  }

  IconData get _icon => switch (modality) {
    ExerciseModality.reps => Icons.repeat,
    ExerciseModality.timed => Icons.timer,
    ExerciseModality.hold => Icons.pause_circle_outline,
    ExerciseModality.mobility => Icons.sync,
    ExerciseModality.breath => Icons.air,
  };

}

class const _ModalityPill({required final ExerciseModality modality})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: EColors.surfaceRaised,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        modality.name,
        style: const TextStyle(
          fontSize: 10,
          color: EColors.textTertiary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
