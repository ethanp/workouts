import 'package:flutter/cupertino.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/theme/app_theme.dart';

class TodayTemplateCard extends StatefulWidget {
  const TodayTemplateCard({
    super.key,
    required this.template,
    required this.onStart,
  });

  final WorkoutTemplate template;
  final VoidCallback onStart;

  @override
  State<TodayTemplateCard> createState() => _TodayTemplateCardState();
}

class _TodayTemplateCardState extends State<TodayTemplateCard> {
  bool _isExpanded = false;

  WorkoutTemplate get template => widget.template;

  int get totalDuration => template.blocks
      .map((block) => block.targetDuration.inMinutes)
      .fold(0, (value, minutes) => value + minutes);

  int get exerciseCount => template.blocks
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
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.sm),
          _statsAndStartRow(),
          _expandToggle(),
          if (_isExpanded) ...[
            const SizedBox(height: AppSpacing.md),
            _blockList(),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(template.name, style: AppTypography.title),
        if (template.goal.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            template.goal,
            style: AppTypography.body.copyWith(color: AppColors.textColor2),
          ),
        ],
      ],
    );
  }

  Widget _statsAndStartRow() {
    return Row(
      children: [
        _stat('${totalDuration}m'),
        _statDivider(),
        _stat('${template.blocks.length} blocks'),
        _statDivider(),
        _stat('$exerciseCount exercises'),
        const Spacer(),
        _startButton(),
      ],
    );
  }

  Widget _stat(String value) {
    return Text(
      value,
      style: AppTypography.caption.copyWith(color: AppColors.textColor3),
    );
  }

  Widget _statDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Text(
        '·',
        style: AppTypography.caption.copyWith(color: AppColors.textColor3),
      ),
    );
  }

  Widget _startButton() {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.accentPrimary,
      borderRadius: BorderRadius.circular(AppRadius.md),
      minSize: 0,
      onPressed: widget.onStart,
      child: const Text(
        'Start',
        style: TextStyle(
          color: CupertinoColors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _expandToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isExpanded
                  ? CupertinoIcons.chevron_up
                  : CupertinoIcons.chevron_down,
              size: 18,
              color: AppColors.textColor3,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              _isExpanded ? 'Hide details' : 'Show details',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blockList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: template.blocks.map(_blockPreview).toList(),
    );
  }

  Widget _blockPreview(WorkoutBlock block) {
    final blockLabel = switch (block.type) {
      WorkoutBlockType.warmup => 'Warmup',
      WorkoutBlockType.animalFlow => 'Animal Flow',
      WorkoutBlockType.strength => 'Strength',
      WorkoutBlockType.mobility => 'Mobility',
      WorkoutBlockType.core => 'Core',
      WorkoutBlockType.conditioning => 'Conditioning',
      WorkoutBlockType.cooldown => 'Cooldown',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(blockLabel, style: AppTypography.subtitle),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (block.rounds > 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDepth2,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        '${block.rounds}x',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textColor3,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    '${block.targetDuration.inMinutes}m',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textColor3,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ...block.exercises.map(_exercisePreview),
        ],
      ),
    );
  }

  Widget _exercisePreview(WorkoutExercise exercise) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(exercise.name, style: AppTypography.body)),
          Text(
            exercise.prescription,
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
          ),
        ],
      ),
    );
  }
}
