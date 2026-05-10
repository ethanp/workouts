import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/services/repositories/goals_repository_powersync.dart';

part 'goals_provider.g.dart';

const _uuid = Uuid();

@riverpod
Stream<List<FitnessGoal>> goalsStream(Ref ref) {
  final goalsRepository = ref.watch(goalsRepositoryPowerSyncProvider);
  return goalsRepository.watchGoals();
}

@riverpod
Stream<List<FitnessGoal>> activeGoalsStream(Ref ref) {
  final goalsRepository = ref.watch(goalsRepositoryPowerSyncProvider);
  return goalsRepository.watchActiveGoals();
}

@Riverpod(keepAlive: true)
class GoalsController extends _$GoalsController {
  @override
  FutureOr<void> build() {}

  void _invalidateGoalsStreamIfMounted() {
    if (ref.mounted) {
      ref.invalidate(goalsStreamProvider);
    }
  }

  Future<void> addGoal({
    required String title,
    required GoalCategory category,
    String description = '',
    int priority = 1,
    DateTime? targetDate,
  }) async {
    final goalsRepository = ref.read(goalsRepositoryPowerSyncProvider);
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
    await goalsRepository.saveGoal(goal);
    _invalidateGoalsStreamIfMounted();
  }

  Future<void> updateGoal(FitnessGoal goal) async {
    final goalsRepository = ref.read(goalsRepositoryPowerSyncProvider);
    await goalsRepository.saveGoal(goal);
    _invalidateGoalsStreamIfMounted();
  }

  Future<void> setGoalStatus(String goalId, GoalStatus status) async {
    final goalsRepository = ref.read(goalsRepositoryPowerSyncProvider);
    await goalsRepository.updateGoalStatus(goalId, status);
    _invalidateGoalsStreamIfMounted();
  }

  Future<void> deleteGoal(String goalId) async {
    final goalsRepository = ref.read(goalsRepositoryPowerSyncProvider);
    await goalsRepository.deleteGoal(goalId);
    _invalidateGoalsStreamIfMounted();
  }

  Future<void> reorderGoal(String goalId, int newPriority) async {
    final goalsRepository = ref.read(goalsRepositoryPowerSyncProvider);
    await goalsRepository.updateGoalPriority(goalId, newPriority);
    _invalidateGoalsStreamIfMounted();
  }
}
