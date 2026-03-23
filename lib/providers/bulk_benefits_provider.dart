import 'package:ethan_utils/ethan_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/providers/goals_provider.dart';
import 'package:workouts/providers/templates_provider.dart';
import 'package:workouts/services/llm_service.dart';
import 'package:workouts/services/repositories/template_repository_powersync.dart';

part 'bulk_benefits_provider.g.dart';

class BulkBenefitsProgress {
  const BulkBenefitsProgress({
    required this.completed,
    required this.total,
  });

  final int completed;
  final int total;

  bool get isDone => completed >= total;
  String get label => 'Generating $completed / $total…';
}

@riverpod
class BulkBenefitsController extends _$BulkBenefitsController {
  bool _cancelled = false;

  @override
  BulkBenefitsProgress? build() => null;

  void cancel() {
    _cancelled = true;
    state = null;
  }

  Future<void> generateAll() async {
    _cancelled = false;

    final exercises = await ref.read(allExercisesProvider.future);
    if (!ref.mounted || _cancelled) return;

    final activeGoals = ref.read(activeGoalsStreamProvider).value ?? [];
    final exercisesNeedingBenefits =
        exercises.whereL((exercise) => exercise.benefits.isEmpty);

    if (exercisesNeedingBenefits.isEmpty) return;

    state = BulkBenefitsProgress(
      completed: 0,
      total: exercisesNeedingBenefits.length,
    );

    final llmService = ref.read(llmServiceProvider);
    final repository = ref.read(templateRepositoryPowerSyncProvider);

    for (var exerciseIndex = 0;
        exerciseIndex < exercisesNeedingBenefits.length;
        exerciseIndex++) {
      if (_cancelled) return;
      final exercise = exercisesNeedingBenefits[exerciseIndex];
      try {
        final generatedBenefits = await llmService.generateExerciseBenefits(
          exerciseName: exercise.name,
          activeGoals: activeGoals,
        );
        if (!ref.mounted || _cancelled) return;
        await repository.updateExerciseBenefits(exercise.id, generatedBenefits);
      } catch (_) {
        // Skip exercises that fail — don't abort the whole run.
      }
      if (!ref.mounted || _cancelled) return;
      state = BulkBenefitsProgress(
        completed: exerciseIndex + 1,
        total: exercisesNeedingBenefits.length,
      );
    }

    ref.invalidate(allExercisesProvider);
    await Future.delayed(const Duration(seconds: 2));
    if (!ref.mounted) return;
    state = null;
  }
}

// Convenience: exercises that still have no benefits (used by the banner).
@riverpod
Future<List<WorkoutExercise>> exercisesWithoutBenefits(Ref ref) async {
  final exercises = await ref.watch(allExercisesProvider.future);
  return exercises.where((exercise) => exercise.benefits.isEmpty).toList();
}
