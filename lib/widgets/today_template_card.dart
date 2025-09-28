import 'package:flutter/cupertino.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/theme/app_theme.dart';

class TodayTemplateCard extends StatelessWidget {
  const TodayTemplateCard({
    super.key,
    required this.template,
    required this.onStart,
  });

  final WorkoutTemplate template;
  final VoidCallback onStart;

  int get totalDuration => template.blocks
      .map((block) => block.targetDuration.inMinutes)
      .fold(0, (value, minutes) => value + minutes);

  int get totalSets => template.blocks
      .map((block) => block.exercises.length)
      .fold(0, (value, count) => value + count);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDepth2),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(template.name, style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          Text(template.goal, style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _buildStat('Duration', '${totalDuration}m'),
              const SizedBox(width: AppSpacing.lg),
              _buildStat('Blocks', '${template.blocks.length}'),
              const SizedBox(width: AppSpacing.lg),
              _buildStat('Exercises', '$totalSets'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onPressed: onStart,
              child: const Text(
                'Begin Session',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppTypography.caption),
      ],
    );
  }
}
