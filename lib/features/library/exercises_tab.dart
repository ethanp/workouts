import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/features/library/bulk_benefits_provider.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/exercise_benefits_sheet.dart';

class ExercisesTab extends ConsumerStatefulWidget {
  const ExercisesTab({super.key, required this.onGenerateAllPressed});

  final VoidCallback onGenerateAllPressed;

  @override
  ConsumerState<ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends ConsumerState<ExercisesTab> {
  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(allExercisesProvider);
    final bulkProgress = ref.watch(bulkBenefitsControllerProvider);

    return exercisesAsync.when(
      data: (exercises) => _ExercisesBody(
        exercises: exercises,
        bulkProgress: bulkProgress,
        onGenerateAll: widget.onGenerateAllPressed,
      ),
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error: $error',
          style: AppTypography.body.copyWith(color: AppColors.error),
        ),
      ),
    );
  }
}

class _ExercisesBody extends ConsumerWidget {
  const _ExercisesBody({
    required this.exercises,
    required this.bulkProgress,
    required this.onGenerateAll,
  });

  final List<WorkoutExercise> exercises;
  final BulkBenefitsProgress? bulkProgress;
  final VoidCallback onGenerateAll;

  bool get _hasMissingBenefits =>
      exercises.any((exercise) => exercise.benefits.isEmpty);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(slivers: _slivers(context));
  }

  List<Widget> _slivers(BuildContext context) {
    return [
      _headerSliver(),
      ..._bannerSlivers(),
      if (exercises.isEmpty) _emptySliver() else _exerciseListSliver(exercises),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
    ];
  }

  Widget _headerSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Text(
          '${exercises.length} exercises',
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
        ),
      ),
    );
  }

  List<Widget> _bannerSlivers() {
    if (bulkProgress != null) {
      return [
        SliverToBoxAdapter(
          child: _GeneratingProgressBanner(progress: bulkProgress!),
        ),
      ];
    }
    if (_hasMissingBenefits) {
      return [
        SliverToBoxAdapter(child: _GenerateAllBanner(onTap: onGenerateAll)),
      ];
    }
    return [];
  }

  Widget _emptySliver() {
    return SliverFillRemaining(
      child: Center(
        child: Text(
          'No exercises yet',
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
        ),
      ),
    );
  }

  Widget _exerciseListSliver(List<WorkoutExercise> filteredExercises) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      sliver: SliverList.separated(
        itemCount: filteredExercises.length,
        separatorBuilder: (_, __) => Container(
          height: 1,
          margin: const EdgeInsets.only(left: 48),
          color: AppColors.borderDepth1,
        ),
        itemBuilder: (context, exerciseIndex) =>
            _ExerciseRow(exercise: filteredExercises[exerciseIndex]),
      ),
    );
  }
}

class _GenerateAllBanner extends StatelessWidget {
  const _GenerateAllBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: _bannerCard(),
      ),
    );
  }

  Widget _bannerCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentSecondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.accentSecondary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.sparkles,
            size: 18,
            color: AppColors.accentSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _bannerText()),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 14,
            color: AppColors.accentSecondary,
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
          style: AppTypography.body.copyWith(
            color: AppColors.accentSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'Use AI to auto-generate benefits and link them to your goals.',
          style: AppTypography.caption.copyWith(
            color: AppColors.accentSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _GeneratingProgressBanner extends ConsumerWidget {
  const _GeneratingProgressBanner({required this.progress});

  final BulkBenefitsProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.accentSecondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.accentSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const CupertinoActivityIndicator(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                progress.label,
                style: AppTypography.body.copyWith(
                  color: AppColors.accentSecondary,
                ),
              ),
            ),
            Text(
              '${((progress.completed / progress.total) * 100).round()}%',
              style: AppTypography.caption.copyWith(
                color: AppColors.accentSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () =>
                  ref.read(bulkBenefitsControllerProvider.notifier).cancel(),
              child: const Icon(
                CupertinoIcons.stop_circle,
                size: 20,
                color: AppColors.accentSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseRow extends ConsumerWidget {
  const _ExerciseRow({required this.exercise});

  final WorkoutExercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _openBenefitsSheet(context),
      child: _rowContent(context),
    );
  }

  Widget _rowContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      color: CupertinoColors.transparent,
      child: Row(
        children: [
          _ModalityIcon(modality: exercise.modality),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _exerciseDetails()),
          if (exercise.benefits.isEmpty) _sparkleButton(context),
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
          style: AppTypography.body.copyWith(color: AppColors.textColor1),
        ),
        const SizedBox(height: 2),
        _exerciseMeta(),
      ],
    );
  }

  Widget _exerciseMeta() {
    final benefitCount = exercise.benefits.length;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _ModalityPill(modality: exercise.modality),
        _SetMetricsPill(label: exercise.setMetrics.label),
        Text(
          benefitCount == 0
              ? 'No benefits'
              : '$benefitCount ${benefitCount == 1 ? 'benefit' : 'benefits'}',
          style: AppTypography.caption.copyWith(
            fontSize: 12,
            color: benefitCount == 0
                ? AppColors.textColor4
                : AppColors.textColor3,
          ),
        ),
      ],
    );
  }

  Widget _sparkleButton(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      onPressed: () => _openBenefitsSheet(context, autoGenerate: true),
      child: const Icon(
        CupertinoIcons.sparkles,
        size: 18,
        color: AppColors.accentSecondary,
      ),
    );
  }

  void _openBenefitsSheet(BuildContext context, {bool autoGenerate = false}) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ExerciseBenefitsSheet(
          exercise: exercise,
          autoGenerate: autoGenerate,
        ),
      ),
    );
  }
}

class _SetMetricsPill extends StatelessWidget {
  const _SetMetricsPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.accentPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ModalityIcon extends StatelessWidget {
  const _ModalityIcon({required this.modality});

  final ExerciseModality modality;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(_icon, size: 16, color: _color),
    );
  }

  IconData get _icon => switch (modality) {
    ExerciseModality.reps => CupertinoIcons.repeat,
    ExerciseModality.timed => CupertinoIcons.timer,
    ExerciseModality.hold => CupertinoIcons.pause_circle,
    ExerciseModality.mobility => CupertinoIcons.arrow_2_circlepath,
    ExerciseModality.breath => CupertinoIcons.wind,
  };

  Color get _color => switch (modality) {
    ExerciseModality.reps => AppColors.accentPrimary,
    ExerciseModality.timed => AppColors.warning,
    ExerciseModality.hold => AppColors.accentSecondary,
    ExerciseModality.mobility => AppColors.success,
    ExerciseModality.breath => AppColors.textColor3,
  };
}

class _ModalityPill extends StatelessWidget {
  const _ModalityPill({required this.modality});

  final ExerciseModality modality;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth4,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        modality.name,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textColor3,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
