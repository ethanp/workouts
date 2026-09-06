import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/features/active_session/session_detail/exercise_progress_card.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';

class const SessionDetailBlockCard({
  required final SessionBlock block,
  required final int index,
  required final DateTime sessionDate,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ELayout.spaceLg),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusXl),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _blockHeader(),
          const SizedBox(height: ELayout.spaceMd),
          for (
            var exerciseIndex = 0;
            exerciseIndex < block.exercises.length;
            exerciseIndex++
          ) ...[
            _exerciseCard(block.exercises[exerciseIndex]),
            if (exerciseIndex < block.exercises.length - 1)
              const SizedBox(height: ELayout.spaceSm),
          ],
        ],
      ),
    );
  }

  Widget _blockHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Block ${index + 1}: ${_titleCase(block.type.name)}',
          style: EText.title,
        ),
        if (block.totalRounds != null)
          Text(
            'Round ${block.roundIndex}/${block.totalRounds}',
            style: EText.caption,
          ),
      ],
    );
  }

  Widget _exerciseCard(WorkoutExercise exercise) {
    final exerciseLogs = block.logs
        .where((log) => log.exerciseId == exercise.id)
        .toList();
    return ExerciseProgressCard(
      exercise: exercise,
      exerciseLogs: exerciseLogs,
      sessionDate: sessionDate,
    );
  }

  String _titleCase(String name) {
    final spacesAdded = name
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
        .trim();
    return '${spacesAdded[0].toUpperCase()}${spacesAdded.substring(1)}';
  }
}
