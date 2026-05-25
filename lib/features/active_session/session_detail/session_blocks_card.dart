import 'package:flutter/cupertino.dart';
import 'package:workouts/features/active_session/session_detail/exercise_progress_card.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/theme/app_theme.dart';

class SessionDetailBlockCard extends StatelessWidget {
  const SessionDetailBlockCard({
    required this.block,
    required this.index,
    required this.sessionDate,
  });

  final SessionBlock block;
  final int index;
  final DateTime sessionDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _blockHeader(),
          const SizedBox(height: AppSpacing.md),
          for (var exerciseIndex = 0;
              exerciseIndex < block.exercises.length;
              exerciseIndex++) ...[
            _exerciseCard(block.exercises[exerciseIndex]),
            if (exerciseIndex < block.exercises.length - 1)
              const SizedBox(height: AppSpacing.sm),
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
          style: AppTypography.title,
        ),
        if (block.totalRounds != null)
          Text(
            'Round ${block.roundIndex}/${block.totalRounds}',
            style: AppTypography.caption,
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
