import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/powersync/powersync_extensions.dart';

part 'goals_repository_powersync.g.dart';

const _uuid = Uuid();

class GoalsRepositoryPowerSync {
  GoalsRepositoryPowerSync(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<List<FitnessGoal>> fetchGoals() async {
    final goalRows = await _powerSync.getAll(
      'SELECT * FROM fitness_goals ORDER BY priority ASC, created_at DESC',
    );
    return goalRows.mapL(FitnessGoal.fromRow);
  }

  Stream<List<FitnessGoal>> watchGoals() {
    return _powerSync
        .watch(
          'SELECT * FROM fitness_goals ORDER BY priority ASC, created_at DESC',
        )
        .map((goalRows) => goalRows.mapL(FitnessGoal.fromRow));
  }

  Stream<List<FitnessGoal>> watchActiveGoals() {
    return _powerSync
        .watch(
          "SELECT * FROM fitness_goals WHERE status = 'active' ORDER BY priority ASC, created_at DESC",
        )
        .map((goalRows) => goalRows.mapL(FitnessGoal.fromRow));
  }

  Future<void> saveGoal(FitnessGoal goal) async {
    final now = DateTime.now().toIso8601String();
    final resolvedGoal = goal.id.isEmpty ? goal.copyWith(id: _uuid.v4()) : goal;

    await _powerSync.upsert('fitness_goals', {
      ...resolvedGoal.toRow(),
      'created_at': goal.createdAt?.toIso8601String() ?? now,
      'updated_at': now,
    });
  }

  Future<void> updateGoalStatus(String goalId, GoalStatus status) async {
    final now = DateTime.now().toIso8601String();
    await _powerSync.execute(
      'UPDATE fitness_goals SET status = ?, updated_at = ? WHERE id = ?',
      [status.name, now, goalId],
    );
  }

  Future<void> updateGoalPriority(String goalId, int priority) async {
    final now = DateTime.now().toIso8601String();
    await _powerSync.execute(
      'UPDATE fitness_goals SET priority = ?, updated_at = ? WHERE id = ?',
      [priority, now, goalId],
    );
  }

  Future<void> deleteGoal(String goalId) async {
    await _powerSync.execute('DELETE FROM fitness_goals WHERE id = ?', [goalId]);
  }
}

@riverpod
GoalsRepositoryPowerSync goalsRepositoryPowerSync(Ref ref) {
  final powerSyncDatabaseAsync = ref.watch(powerSyncDatabaseProvider);
  final powerSyncDatabase = powerSyncDatabaseAsync.value;
  if (powerSyncDatabase == null) {
    throw StateError('PowerSync database not initialized');
  }
  return GoalsRepositoryPowerSync(powerSyncDatabase);
}
