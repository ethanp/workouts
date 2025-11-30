import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/providers/templates_provider.dart';
import 'package:workouts/theme/app_theme.dart';

class ExercisePickerScreen extends ConsumerWidget {
  const ExercisePickerScreen({required this.excludeIds});

  final Set<String> excludeIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(allExercisesProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.backgroundDepth1,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.backgroundDepth1,
        border: const Border(bottom: BorderSide(color: AppColors.borderDepth1)),
        middle: const Text('Add Exercise', style: AppTypography.title),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.xmark, color: AppColors.textColor2),
        ),
      ),
      child: exercisesAsync.when(
        data: (exercises) =>
            _ExercisePickerBody(exercises: exercises, excludeIds: excludeIds),
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error: $e',
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          ),
        ),
      ),
    );
  }
}

class _ExercisePickerBody extends StatefulWidget {
  const _ExercisePickerBody({
    required this.exercises,
    required this.excludeIds,
  });

  final List<WorkoutExercise> exercises;
  final Set<String> excludeIds;

  @override
  State<_ExercisePickerBody> createState() => _ExercisePickerBodyState();
}

class _ExercisePickerBodyState extends State<_ExercisePickerBody> {
  ExerciseModality? _selectedModality;

  List<WorkoutExercise> get filteredExercises {
    final available = widget.exercises
        .where((e) => !widget.excludeIds.contains(e.id))
        .toList();

    // Filter by modality only
    if (_selectedModality == null) return available;
    return available.where((e) => e.modality == _selectedModality).toList();
  }

  Set<ExerciseModality> get availableModalities => widget.exercises
      .where((e) => !widget.excludeIds.contains(e.id))
      .map((e) => e.modality)
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
    return SafeArea(
      child: Column(
        children: [
          filterChips(),
          Expanded(child: exerciseList()),
        ],
      ),
    );
  }

  Widget filterChips() {
    final modalities = availableModalities.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          filterChip(null, 'All'),
          ...modalities.map((m) => filterChip(m, m.name.toUpperCase())),
        ],
      ),
    );
  }

  Widget filterChip(ExerciseModality? modality, String label) {
    final isSelected = _selectedModality == modality;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => setState(() => _selectedModality = modality),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.backgroundDepth3,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isSelected ? AppColors.textColor1 : AppColors.textColor3,
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
          style: AppTypography.body.copyWith(color: AppColors.textColor3),
        ),
      );
    }

    final modalities = groups.keys.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
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
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(
            modality.name.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: AppColors.textColor4,
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
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => Navigator.of(context).pop(exercise),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderDepth1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textColor1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      prescriptionBadge(exercise.prescription),
                      if (exercise.equipment != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        equipmentBadge(exercise.equipment!),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.add_circled,
              color: AppColors.accentPrimary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget prescriptionBadge(String prescription) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        prescription,
        style: AppTypography.caption.copyWith(color: AppColors.textColor3),
      ),
    );
  }

  Widget equipmentBadge(String equipment) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentSecondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.cube,
            size: 12,
            color: AppColors.accentSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            equipment,
            style: AppTypography.caption.copyWith(
              color: AppColors.accentSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
