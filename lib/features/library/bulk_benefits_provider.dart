import 'package:ethan_utils/ethan_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/features/goals/goals_provider.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:workouts/services/llm/llm_service.dart';
import 'package:workouts/services/repositories/templates/template_repository_powersync.dart';
import 'package:workouts/utils/error_bus.dart';

part 'bulk_benefits_provider.g.dart';

const _log = ELogger('BulkBenefits');

class BulkBenefitsProgress {
  const BulkBenefitsProgress({
    required this.completed,
    required this.total,
    this.failed = 0,
  });

  final int completed;
  final int total;
  final int failed;

  bool get isDone => completed + failed >= total;

  String get label {
    final done = completed + failed;
    return failed > 0
        ? 'Generating $done / $total ($failed failed)…'
        : 'Generating $done / $total…';
  }
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
    final exercisesNeedingBenefits = exercises.whereL(
      (exercise) => exercise.benefits.isEmpty,
    );

    if (exercisesNeedingBenefits.isEmpty) return;

    final total = exercisesNeedingBenefits.length;
    var completed = 0;
    var failed = 0;

    state = BulkBenefitsProgress(completed: 0, total: total);

    final llmService = ref.read(llmServiceProvider);
    final repository = ref.read(templateRepositoryPowerSyncProvider);

    for (final exercise in exercisesNeedingBenefits) {
      if (_cancelled) return;
      try {
        final generatedBenefits = await llmService.generateExerciseBenefits(
          exerciseName: exercise.name,
          activeGoals: activeGoals,
        );
        if (!ref.mounted || _cancelled) return;
        await repository.updateExerciseBenefits(exercise.id, generatedBenefits);
        completed++;
      } catch (error) {
        _log.log('Failed to generate/save benefits for "${exercise.name}": $error');
        failed++;
      }
      if (!ref.mounted || _cancelled) return;
      state = BulkBenefitsProgress(
        completed: completed,
        total: total,
        failed: failed,
      );
    }

    if (failed > 0) {
      errorBus.add('Benefits generation: $failed / $total exercises failed. Check logs for details.');
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
