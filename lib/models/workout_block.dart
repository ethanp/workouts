import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:workouts/models/workout_exercise.dart';

part 'workout_block.freezed.dart';
part 'workout_block.g.dart';

enum WorkoutBlockType { warmup, animalFlow, strength, mobility, cooldown }

@freezed
class WorkoutBlock with _$WorkoutBlock {
  const factory WorkoutBlock({
    required String id,
    required WorkoutBlockType type,
    required String title,
    required Duration targetDuration,
    required List<WorkoutExercise> exercises,
    @Default('') String description,
  }) = _WorkoutBlock;

  factory WorkoutBlock.fromJson(Map<String, dynamic> json) =>
      _$WorkoutBlockFromJson(json);
}
