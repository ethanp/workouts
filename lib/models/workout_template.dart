import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:workouts/models/workout_block.dart';

part 'workout_template.freezed.dart';
part 'workout_template.g.dart';

@freezed
abstract class WorkoutTemplate with _$WorkoutTemplate {
  const factory WorkoutTemplate({
    required String id,
    required String name,
    required String goal,
    required List<WorkoutBlock> blocks,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  }) = _WorkoutTemplate;

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) =>
      _$WorkoutTemplateFromJson(json);
}
