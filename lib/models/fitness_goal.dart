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
}
