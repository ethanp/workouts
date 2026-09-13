import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:workouts/models/workout_exercise.dart';

class const ReplaceExerciseBadges({required final WorkoutExercise exercise})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ELayout.spaceSm,
      runSpacing: ELayout.spaceXs,
      children: [
        ReplaceExerciseModalityBadge(modality: exercise.modality),
        if (exercise.equipment != null && exercise.equipment!.isNotEmpty)
          ReplaceExerciseEquipmentBadge(equipment: exercise.equipment!),
      ],
    );
  }
}

class const ReplaceExerciseModalityBadge({
  required final ExerciseModality modality,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: ELayout.spaceXs,
      ),
      decoration: BoxDecoration(
        color: EColors.surface,
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Text(
        modality.name,
        style: EText.caption.copyWith(
          color: EColors.textTertiary,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class const ReplaceExerciseEquipmentBadge({required final String equipment})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: ELayout.spaceXs,
      ),
      decoration: BoxDecoration(
        color: EColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.view_in_ar, size: 12, color: EColors.warning),
          const SizedBox(width: ELayout.spaceXs),
          Text(
            equipment,
            style: EText.caption.copyWith(color: EColors.warning),
          ),
        ],
      ),
    );
  }
}

class const ReplaceExerciseSectionHeader({required final String label})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ELayout.spaceLg,
        ELayout.spaceMd,
        ELayout.spaceLg,
        ELayout.spaceXs,
      ),
      child: Text(
        label,
        style: EText.caption.copyWith(
          color: EColors.textMuted,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class const ReplaceExerciseNewBadge() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: ELayout.spaceXs,
      ),
      decoration: BoxDecoration(
        color: EColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Text(
        'NEW',
        style: EText.caption.copyWith(
          color: EColors.accent,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
