import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:workouts/models/workout_exercise.dart';

import 'replace_exercise_badges.dart';

class const ReplaceExerciseLibraryList({
  required final List<WorkoutExercise> libraryExercises,
  required final Set<String> excludeIds,
  required final ExerciseModality? selectedModality,
  required final ValueChanged<WorkoutExercise> onExerciseSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final groups = _groupedFilteredLibrary();
    if (groups.isEmpty) {
      return Column(
        children: [
          const ReplaceExerciseSectionHeader(label: 'LIBRARY'),
          Padding(
            padding: const EdgeInsets.all(ELayout.spaceLg),
            child: Center(
              child: Text(
                'No exercises available',
                style: EText.body.medium.copyWith(color: EColors.textTertiary),
              ),
            ),
          ),
        ],
      );
    }

    final modalities = groups.keys.toList().sortedOn((modality) => modality.name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ReplaceExerciseSectionHeader(label: 'LIBRARY'),
        for (final modality in modalities)
          ReplaceExerciseModalitySection(
            modality: modality,
            exercises: groups[modality]!,
            onExerciseSelected: onExerciseSelected,
          ),
      ],
    );
  }

  List<WorkoutExercise> _filteredLibrary() {
    final available = libraryExercises.whereL(
      (exercise) => !excludeIds.contains(exercise.id),
    );
    if (selectedModality == null) return available;
    return available.whereL(
      (exercise) => exercise.modality == selectedModality,
    );
  }

  Map<ExerciseModality, List<WorkoutExercise>> _groupedFilteredLibrary() {
    final grouped = <ExerciseModality, List<WorkoutExercise>>{};
    for (final exercise in _filteredLibrary()) {
      grouped.putIfAbsent(exercise.modality, () => []).add(exercise);
    }
    return grouped;
  }
}

class const ReplaceExerciseModalitySection({
  required final ExerciseModality modality,
  required final List<WorkoutExercise> exercises,
  required final ValueChanged<WorkoutExercise> onExerciseSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ELayout.spaceLg,
            ELayout.spaceMd,
            ELayout.spaceLg,
            ELayout.spaceSm,
          ),
          child: Text(
            modality.name.toUpperCase(),
            style: EText.caption.copyWith(
              color: EColors.textMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...exercises.map(
          (exercise) => ReplaceExerciseLibraryRow(
            exercise: exercise,
            onSelected: () => onExerciseSelected(exercise),
          ),
        ),
      ],
    );
  }
}

class const ReplaceExerciseLibraryRow({
  required final WorkoutExercise exercise,
  required final VoidCallback onSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: EColors.border)),
      ),
      child: InkWell(
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ELayout.spaceLg,
            vertical: ELayout.spaceMd,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: EText.body.medium.copyWith(
                        color: EColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: ELayout.spaceXs),
                    ReplaceExerciseBadges(exercise: exercise),
                  ],
                ),
              ),
              const Icon(
                Icons.add_circle_outline,
                color: EColors.accent,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class const ReplaceExerciseModalityFilters({
  required final List<WorkoutExercise> libraryExercises,
  required final Set<String> excludeIds,
  required final ExerciseModality? selectedModality,
  required final ValueChanged<ExerciseModality?> onModalitySelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final modalities = libraryExercises
        .where((exercise) => !excludeIds.contains(exercise.id))
        .map((exercise) => exercise.modality)
        .toSet()
        .toList()
        .sortedOn((modality) => modality.name);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceLg,
        vertical: ELayout.spaceMd,
      ),
      child: Row(
        children: [
          ReplaceExerciseFilterChip(
            label: 'All',
            isSelected: selectedModality == null,
            onActivated: () => onModalitySelected(null),
          ),
          ...modalities.map(
            (modality) => ReplaceExerciseFilterChip(
              label: modality.name.toUpperCase(),
              isSelected: selectedModality == modality,
              onActivated: () => onModalitySelected(modality),
            ),
          ),
        ],
      ),
    );
  }
}

class const ReplaceExerciseFilterChip({
  required final String label,
  required final bool isSelected,
  required final VoidCallback onActivated,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: ELayout.spaceSm),
      child: InkWell(
        onTap: onActivated,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ELayout.spaceMd,
            vertical: ELayout.spaceSm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? EColors.accent : EColors.surface,
            borderRadius: BorderRadius.circular(ELayout.radiusMd),
          ),
          child: Text(
            label,
            style: EText.caption.copyWith(
              color: isSelected ? EColors.textPrimary : EColors.textTertiary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
