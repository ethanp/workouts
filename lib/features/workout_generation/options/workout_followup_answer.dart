import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';

class WorkoutFollowupAnswer extends StatelessWidget {
  const WorkoutFollowupAnswer({
    super.key,
    required this.answer,
    required this.answering,
  });

  final String answer;
  final bool answering;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (answer.isNotEmpty) _answerCard(),
        if (answering) ...[
          if (answer.isNotEmpty) const SizedBox(height: AppSpacing.md),
          const Center(child: CupertinoActivityIndicator()),
        ],
      ],
    );
  }

  Widget _answerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Text(
        answer,
        style: AppTypography.body.copyWith(color: AppColors.textColor2),
      ),
    );
  }
}
