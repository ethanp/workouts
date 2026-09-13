import 'package:ethan_utils/ethan_utils.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:workouts/widgets/connection_gated_widget.dart';
import 'package:workouts/widgets/exercise_benefits_sheet.dart';

class const ExercisePickerScreen({required final Set<String> excludeIds})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(allExercisesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: EAppHeader(
        title: 'Add Exercise',
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: exercisesAsync.when(
          data: (exercises) =>
              _ExercisePickerBody(exercises: exercises, excludeIds: excludeIds),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Error: $e',
              style: EText.body.medium.copyWith(color: EColors.textTertiary),
            ),
          ),
        ),
      ),
    );
  }
}

class const _ExercisePickerBody({
  required final List<WorkoutExercise> exercises,
  required final Set<String> excludeIds,
}) extends StatefulWidget {
  @override
  State<_ExercisePickerBody> createState() => _ExercisePickerBodyState();
}

class _ExercisePickerBodyState() extends State<_ExercisePickerBody> {
  ExerciseModality? _selectedModality;

  List<WorkoutExercise> get filteredExercises {
    final available = widget.exercises.whereL(
      (workoutExercise) => !widget.excludeIds.contains(workoutExercise.id),
    );

    // Filter by modality only
    if (_selectedModality == null) return available;
    return available.whereL(
      (workoutExercise) => workoutExercise.modality == _selectedModality,
    );
  }

  Set<ExerciseModality> get availableModalities => widget.exercises
      .where(
        (workoutExercise) => !widget.excludeIds.contains(workoutExercise.id),
      )
      .map((workoutExercise) => workoutExercise.modality)
      .toSet();

  Map<ExerciseModality, List<WorkoutExercise>> get groupedExercises {
    final grouped = <ExerciseModality, List<WorkoutExercise>>{};
    for (final exercise in filteredExercises) {
      grouped.putIfAbsent(exercise.modality, () => []).add(exercise);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        filterChips(),
        Expanded(child: exerciseList()),
      ],
    );
  }

  Widget filterChips() {
    final modalities = availableModalities.toList().sortedOn(
      (exerciseModality) => exerciseModality.name,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceLg,
        vertical: ELayout.spaceMd,
      ),
      child: Row(
        children: [
          filterChip(null, 'All'),
          ...modalities.map(
            (exerciseModality) => filterChip(
              exerciseModality,
              exerciseModality.name.toUpperCase(),
            ),
          ),
        ],
      ),
    );
  }

  Widget filterChip(ExerciseModality? modality, String label) {
    final isSelected = _selectedModality == modality;
    return Padding(
      padding: const EdgeInsets.only(right: ELayout.spaceSm),
      child: InkWell(
        onTap: () => setState(() => _selectedModality = modality),
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ELayout.spaceMd,
            vertical: ELayout.spaceSm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? EColors.accent
                : EColors.surface,
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

  Widget exerciseList() {
    final groups = groupedExercises;
    if (groups.isEmpty) {
      return Center(
        child: Text(
          'No exercises available',
          style: EText.body.medium.copyWith(color: EColors.textTertiary),
        ),
      );
    }

    final modalities = groups.keys.toList().sortedOn(
      (exerciseModality) => exerciseModality.name,
    );

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32).withOverlaidTabBar(context),
      itemCount: modalities.length,
      itemBuilder: (context, index) {
        final modality = modalities[index];
        final exercises = groups[modality]!;
        return modalitySection(modality, exercises);
      },
    );
  }

  Widget modalitySection(
    ExerciseModality modality,
    List<WorkoutExercise> exercises,
  ) {
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
        ...exercises.map(exerciseRow),
      ],
    );
  }

  Widget exerciseRow(WorkoutExercise exercise) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: EColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => Navigator.of(context).pop(exercise),
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
                          Wrap(
                            spacing: ELayout.spaceSm,
                            runSpacing: ELayout.spaceXs,
                            children: [
                              prescriptionBadge(exercise.prescription),
                              setMetricsBadge(exercise.setMetrics.label),
                              if (exercise.equipment != null) ...[
                                equipmentBadge(exercise.equipment!),
                              ],
                              if (exercise.benefits.isNotEmpty) ...[
                                _benefitsBadge(exercise.benefits.length),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.add_circle_outline,
                      color: EColors.accent,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
          ConnectionGatedWidget(
            child: IconButton(
              tooltip: 'Benefits',
              onPressed: () => _openBenefitsSheet(exercise),
              icon: const Icon(
                Icons.auto_awesome,
                size: 18,
                color: EColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitsBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: ELayout.spaceXs,
      ),
      decoration: BoxDecoration(
        color: EColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome,
            size: 10,
            color: EColors.warning,
          ),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: EText.caption.copyWith(
              color: EColors.warning,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  void _openBenefitsSheet(WorkoutExercise exercise) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseBenefitsSheet(exercise: exercise),
      ),
    );
  }

  Widget prescriptionBadge(String prescription) {
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
        prescription,
        style: EText.caption.copyWith(color: EColors.textTertiary),
      ),
    );
  }

  Widget equipmentBadge(String equipment) {
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
          const Icon(
            Icons.view_in_ar,
            size: 12,
            color: EColors.warning,
          ),
          const SizedBox(width: ELayout.spaceXs),
          Text(
            equipment,
            style: EText.caption.copyWith(
              color: EColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget setMetricsBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: ELayout.spaceXs,
      ),
      decoration: BoxDecoration(
        color: EColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Text(
        label,
        style: EText.caption.copyWith(color: EColors.accent),
      ),
    );
  }
}
