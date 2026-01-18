import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/services/repositories/goals_repository_powersync.dart';

part 'goals_provider.g.dart';

const _uuid = Uuid();

@riverpod
Stream<List<FitnessGoal>> goalsStream(Ref ref) {
  final repo = ref.watch(goalsRepositoryPowerSyncProvider);
  return repo.watchGoals();
}

@riverpod
Stream<List<FitnessGoal>> activeGoalsStream(Ref ref) {
  final repo = ref.watch(goalsRepositoryPowerSyncProvider);
  return repo.watchActiveGoals();
}

@riverpod
class GoalsController extends _$GoalsController {
  @override
  FutureOr<void> build() {}

  Future<void> addGoal({
    required String title,
    required GoalCategory category,
    String description = '',
    int priority = 1,
    DateTime? targetDate,
  }) async {
    final repo = ref.read(goalsRepositoryPowerSyncProvider);
    final goal = FitnessGoal(
      id: _uuid.v4(),
      title: title,
      category: category,
      description: description,
      priority: priority,
      targetDate: targetDate,
      status: GoalStatus.active,
      createdAt: DateTime.now(),
    );
    await repo.saveGoal(goal);
    ref.invalidate(goalsStreamProvider);
  }

  Future<void> updateGoal(FitnessGoal goal) async {
    final repo = ref.read(goalsRepositoryPowerSyncProvider);
    await repo.saveGoal(goal);
    ref.invalidate(goalsStreamProvider);
  }

  Future<void> archiveGoal(String goalId) async {
    final repo = ref.read(goalsRepositoryPowerSyncProvider);
    await repo.updateGoalStatus(goalId, GoalStatus.paused);
    ref.invalidate(goalsStreamProvider);
  }

  Future<void> activateGoal(String goalId) async {
    final repo = ref.read(goalsRepositoryPowerSyncProvider);
    await repo.updateGoalStatus(goalId, GoalStatus.active);
    ref.invalidate(goalsStreamProvider);
  }

  Future<void> markAchieved(String goalId) async {
    final repo = ref.read(goalsRepositoryPowerSyncProvider);
    await repo.updateGoalStatus(goalId, GoalStatus.achieved);
    ref.invalidate(goalsStreamProvider);
  }

  Future<void> deleteGoal(String goalId) async {
    final repo = ref.read(goalsRepositoryPowerSyncProvider);
    await repo.deleteGoal(goalId);
    ref.invalidate(goalsStreamProvider);
  }

  Future<void> reorderGoal(String goalId, int newPriority) async {
    final repo = ref.read(goalsRepositoryPowerSyncProvider);
    await repo.updateGoalPriority(goalId, newPriority);
    ref.invalidate(goalsStreamProvider);
  }
}
