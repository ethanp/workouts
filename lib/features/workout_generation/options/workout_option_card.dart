import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:workouts/models/llm_workout_option.dart';

class const WorkoutOptionCard({
  required final LlmWorkoutOption option,
  required final bool isExpanded,
  required final VoidCallback onExpansionToggled,
  required final VoidCallback onWorkoutSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_header(), if (isExpanded) _expandedContent()],
      ),
    );
  }

  Widget _header() {
    return GestureDetector(
      onTap: onExpansionToggled,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(ELayout.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titleRow(),
            const SizedBox(height: ELayout.spaceSm),
            _rationale(),
            const SizedBox(height: ELayout.spaceSm),
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
        Expanded(child: Text(option.title, style: EText.section)),
        Row(
          children: [
            _goalBadge(),
            const SizedBox(width: ELayout.spaceXs),
            _timeBadge(),
          ],
        ),
      ],
    );
  }

  Widget _rationale() => Text(
    option.rationale,
    style: EText.body.medium.copyWith(color: EColors.textSecondary),
  );

  Widget _expandToggle() {
    return Row(
      children: [
        Icon(
          isExpanded ? Icons.expand_less : Icons.expand_more,
          size: 16,
          color: EColors.textTertiary,
        ),
        const SizedBox(width: ELayout.spaceXs),
        Text(
          isExpanded ? 'Hide exercises' : 'Show exercises',
          style: EText.caption.copyWith(color: EColors.textTertiary),
        ),
      ],
    );
  }

  Widget _expandedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: EColors.border),
        Padding(
          padding: const EdgeInsets.all(ELayout.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...option.blocks.map((block) => _BlockSection(block: block)),
              const SizedBox(height: ELayout.spaceMd),
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
      child: FilledButton(
        onPressed: onWorkoutSelected,
        child: const Text('Start This Workout'),
      ),
    );
  }

  Widget _goalBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: ELayout.spaceXs,
      ),
      decoration: BoxDecoration(
        color: EColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
        border: Border.all(color: EColors.border),
      ),
      child: Text(
        option.goal.toUpperCase(),
        style: EText.caption.copyWith(
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
        horizontal: ELayout.spaceSm,
        vertical: ELayout.spaceXs,
      ),
      decoration: BoxDecoration(
        color: EColors.surface,
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Text('${totalMinutes}m', style: EText.caption),
    );
  }
}

class const _BlockSection({required final LlmWorkoutBlock block})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: ELayout.spaceSm),
          child: Row(
            children: [
              Text(
                block.title,
                style: EText.body.medium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: EColors.textPrimary,
                ),
              ),
              const SizedBox(width: ELayout.spaceSm),
              Text(
                '${block.estimatedMinutes}m',
                style: EText.caption.copyWith(
                  color: EColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        if (block.description != null && block.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: ELayout.spaceSm),
            child: Text(
              block.description!,
              style: EText.caption.copyWith(
                color: EColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ...block.exercises.map((exercise) => _ExerciseRow(exercise: exercise)),
        const SizedBox(height: ELayout.spaceSm),
      ],
    );
  }
}

class const _ExerciseRow({required final LlmExercise exercise})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prescription = exercise.prescription;

    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(exercise.name, style: EText.body.medium)),
          Text(
            prescription,
            style: EText.caption.copyWith(color: EColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
