import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/services/powersync_database_provider.dart';

part 'goals_repository_powersync.g.dart';

const _uuid = Uuid();

class GoalsRepositoryPowerSync {
  GoalsRepositoryPowerSync(this._db);

  final PowerSyncDatabase _db;

  Future<List<FitnessGoal>> fetchGoals() async {
    final rows = await _db.getAll(
      'SELECT * FROM fitness_goals ORDER BY priority ASC, created_at DESC',
    );
    return rows.map(_goalFromRow).toList();
  }

  Stream<List<FitnessGoal>> watchGoals() {
    return _db
        .watch(
          'SELECT * FROM fitness_goals ORDER BY priority ASC, created_at DESC',
        )
        .map((rows) => rows.map(_goalFromRow).toList());
  }

  Stream<List<FitnessGoal>> watchActiveGoals() {
    return _db
        .watch(
          "SELECT * FROM fitness_goals WHERE status = 'active' ORDER BY priority ASC, created_at DESC",
        )
        .map((rows) => rows.map(_goalFromRow).toList());
  }

  Future<void> saveGoal(FitnessGoal goal) async {
    final now = DateTime.now().toIso8601String();
    final id = goal.id.isEmpty ? _uuid.v4() : goal.id;

    await _db.execute(
      '''
      INSERT OR REPLACE INTO fitness_goals (
        id, title, description, category, priority, 
        target_date, status, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        goal.title,
        goal.description,
        goal.category.name,
        goal.priority,
        goal.targetDate?.toIso8601String(),
        goal.status.name,
        goal.createdAt?.toIso8601String() ?? now,
        now,
      ],
    );
  }

  Future<void> updateGoalStatus(String goalId, GoalStatus status) async {
    final now = DateTime.now().toIso8601String();
    await _db.execute(
      'UPDATE fitness_goals SET status = ?, updated_at = ? WHERE id = ?',
      [status.name, now, goalId],
    );
  }

  Future<void> updateGoalPriority(String goalId, int priority) async {
    final now = DateTime.now().toIso8601String();
    await _db.execute(
      'UPDATE fitness_goals SET priority = ?, updated_at = ? WHERE id = ?',
      [priority, now, goalId],
    );
  }

  Future<void> deleteGoal(String goalId) async {
    await _db.execute('DELETE FROM fitness_goals WHERE id = ?', [goalId]);
  }

  FitnessGoal _goalFromRow(Map<String, dynamic> row) {
    return FitnessGoal(
      id: row['id'] as String,
      title: row['title'] as String,
      description: (row['description'] as String?) ?? '',
      category: GoalCategory.values.firstWhere(
        (c) => c.name == row['category'],
        orElse: () => GoalCategory.strength,
      ),
      priority: (row['priority'] as int?) ?? 1,
      targetDate: row['target_date'] != null
          ? DateTime.tryParse(row['target_date'] as String)
          : null,
      status: GoalStatus.values.firstWhere(
        (s) => s.name == row['status'],
        orElse: () => GoalStatus.active,
      ),
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'] as String)
          : null,
    );
  }
}

@riverpod
GoalsRepositoryPowerSync goalsRepositoryPowerSync(Ref ref) {
  final dbAsync = ref.watch(powerSyncDatabaseProvider);
  final db = dbAsync.value;
  if (db == null) {
    throw StateError('PowerSync database not initialized');
  }
  return GoalsRepositoryPowerSync(db);
}
