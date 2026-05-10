import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/exercise_benefit.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:workouts/services/repositories/templates/template_repository_powersync.dart';

part 'exercise_benefits_provider.g.dart';

@riverpod
class ExerciseBenefitsController extends _$ExerciseBenefitsController {
  @override
  FutureOr<void> build() {}

  Future<void> saveBenefits(
    WorkoutExercise exercise,
    List<ExerciseBenefit> benefits,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(templateRepositoryPowerSyncProvider)
          .updateExerciseBenefits(exercise.id, benefits);
      // Benefits are stored on exercises; refresh both direct exercise lists
      // and any template views that have already hydrated exercise rows.
      ref.invalidate(allExercisesProvider);
      ref.invalidate(workoutTemplatesProvider);
    });
  }
}
