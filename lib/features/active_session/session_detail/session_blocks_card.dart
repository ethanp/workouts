import 'package:flutter/cupertino.dart';
import 'package:workouts/features/active_session/session_detail/session_set_log_row.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/expandable_cues.dart';

class SessionDetailBlockCard extends StatelessWidget {
  const SessionDetailBlockCard({required this.block, required this.index});

  final SessionBlock block;
  final int index;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Block ${index + 1}: ${titleCase(block.type.name)}',
                style: AppTypography.title,
              ),
              if (block.totalRounds != null)
                Text(
                  'Round ${block.roundIndex}/${block.totalRounds}',
                  style: AppTypography.caption,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...block.exercises.map((exercise) => _buildExercise(exercise)),
        ],
      ),
    );
  }

  String titleCase(String name) {
    final spacesAdded = name
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
        .trim();
    return '${spacesAdded[0].toUpperCase()}${spacesAdded.substring(1)}';
  }

  Widget _buildExercise(WorkoutExercise exercise) {
    final exerciseLogs = block.logs
        .where((log) => log.exerciseId == exercise.id)
        .toList();
    final completedSets = exerciseLogs.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(exercise.name, style: AppTypography.subtitle),
              ),
              Text(
                '$completedSets/${exercise.effectiveTargetSets} sets',
                style: AppTypography.caption.copyWith(
                  color: completedSets >= exercise.effectiveTargetSets
                      ? AppColors.success
                      : AppColors.textColor3,
                ),
              ),
            ],
          ),
          if (exercise.restDuration != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Rest: ${_getDurationText(exercise.restDuration)}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor3,
              ),
            ),
          ],
          if (exercise.cues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ExpandableCues(cues: exercise.cues),
          ],
          if (exerciseLogs.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...exerciseLogs.map(
              (log) => SessionSetLogRow(log: log, exercise: exercise),
            ),
          ],
        ],
      ),
    );
  }

  String _getDurationText(Duration? duration) {
    if (duration == null) return 'N/A';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}
