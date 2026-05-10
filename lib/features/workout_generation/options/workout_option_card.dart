import 'package:flutter/cupertino.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/theme/app_theme.dart';

class WorkoutOptionCard extends StatelessWidget {
  const WorkoutOptionCard({
    super.key,
    required this.option,
    required this.isExpanded,
    required this.onTap,
    required this.onSelect,
  });

  final LlmWorkoutOption option;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_header(), if (isExpanded) _expandedContent()],
      ),
    );
  }

  Widget _header() {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titleRow(),
            const SizedBox(height: AppSpacing.sm),
            _rationale(),
            const SizedBox(height: AppSpacing.sm),
            _expandToggle(),
          ],
        ),
      ),
    );
  }

  Widget _titleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(option.title, style: AppTypography.subtitle)),
        Row(
          children: [
            _goalBadge(),
            const SizedBox(width: AppSpacing.xs),
            _timeBadge(),
          ],
        ),
      ],
    );
  }

  Widget _rationale() => Text(
    option.rationale,
    style: AppTypography.body.copyWith(color: AppColors.textColor2),
  );

  Widget _expandToggle() {
    return Row(
      children: [
        Icon(
          isExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
          size: 16,
          color: AppColors.textColor3,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          isExpanded ? 'Hide exercises' : 'Show exercises',
          style: AppTypography.caption.copyWith(color: AppColors.textColor3),
        ),
      ],
    );
  }

  Widget _expandedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: AppColors.borderDepth1),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...option.blocks.map((block) => _BlockSection(block: block)),
              const SizedBox(height: AppSpacing.md),
              _startButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _startButton() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton.filled(
        onPressed: onSelect,
        child: const Text('Start This Workout'),
      ),
    );
  }

  Widget _goalBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Text(
        option.goal.toUpperCase(),
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _timeBadge() {
    final totalMinutes = option.blocks.fold<int>(
      0,
      (sum, block) => sum + block.estimatedMinutes,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text('${totalMinutes}m', style: AppTypography.caption),
    );
  }
}

class _BlockSection extends StatelessWidget {
  const _BlockSection({required this.block});

  final LlmWorkoutBlock block;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Text(
                block.title,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor1,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${block.estimatedMinutes}m',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textColor3,
                ),
              ),
            ],
          ),
        ),
        if (block.description != null && block.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              block.description!,
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor2,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ...block.exercises.map((exercise) => _ExerciseRow(exercise: exercise)),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});

  final LlmExercise exercise;

  @override
  Widget build(BuildContext context) {
    final prescription = exercise.prescription;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(exercise.name, style: AppTypography.body)),
          Text(
            prescription,
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
          ),
        ],
      ),
    );
  }
}
