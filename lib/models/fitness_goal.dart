import 'package:freezed_annotation/freezed_annotation.dart';

part 'fitness_goal.freezed.dart';
part 'fitness_goal.g.dart';

enum GoalCategory {
  strength,
  power,
  endurance,
  mobility,
  balance,
  coordination,
  quickness,
  physique,
  posture,
  rehabilitation,
  longevity,
  skill,
}

enum GoalStatus { active, achieved, paused }

@freezed
abstract class FitnessGoal with _$FitnessGoal {
  const FitnessGoal._();

  const factory FitnessGoal({
    required String id,
    required String title,
    required GoalCategory category,
    @Default('') String description,
    @Default(1) int priority,
    DateTime? targetDate,
    @Default(GoalStatus.active) GoalStatus status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _FitnessGoal;

  factory FitnessGoal.fromJson(Map<String, dynamic> json) =>
      _$FitnessGoalFromJson(json);

  factory FitnessGoal.fromRow(Map<String, dynamic> goalRow) {
    return FitnessGoal(
      id: goalRow['id'] as String,
      title: goalRow['title'] as String,
      description: (goalRow['description'] as String?) ?? '',
      category: GoalCategory.values.firstWhere(
        (goalCategory) => goalCategory.name == goalRow['category'],
        orElse: () => GoalCategory.strength,
      ),
      priority: (goalRow['priority'] as int?) ?? 1,
      targetDate: _asDateTime(goalRow['target_date']),
      status: GoalStatus.values.firstWhere(
        (goalStatus) => goalStatus.name == goalRow['status'],
        orElse: () => GoalStatus.active,
      ),
      createdAt: _asDateTime(goalRow['created_at']),
      updatedAt: _asDateTime(goalRow['updated_at']),
    );
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category.name,
    'priority': priority,
    'target_date': targetDate?.toIso8601String(),
    'status': status.name,
  };
}

DateTime? _asDateTime(Object? rawValue) {
  final String? maybeDateTime = rawValue as String?;
  return maybeDateTime == null ? null : DateTime.tryParse(maybeDateTime);
}
