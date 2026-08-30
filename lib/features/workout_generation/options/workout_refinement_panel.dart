import 'package:flutter/cupertino.dart';
import 'package:workouts/features/workout_generation/options/workout_followup_answer.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/connection_gated_widget.dart';

enum RefinementMode() {
  refine,
  ask,
}

class const WorkoutRefinementPanel({
  required final RefinementMode mode,
  required final TextEditingController feedbackController,
  required final ValueChanged<RefinementMode> onModeChanged,
  required final VoidCallback onFeedbackChanged,
  required final ValueChanged<String> onAsk,
  required final ValueChanged<String> onRefine,
  final String? followupAnswer,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ConnectionGatedWidget(child: _panel());
  }

  Widget _panel() {
    final isAskMode = mode == RefinementMode.ask;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _modePicker(),
        const SizedBox(height: AppSpacing.md),
        if (followupAnswer != null && followupAnswer!.isNotEmpty) ...[
          WorkoutFollowupAnswer(answer: followupAnswer!, answering: false),
          const SizedBox(height: AppSpacing.md),
        ],
        CupertinoTextField(
          controller: feedbackController,
          placeholder: isAskMode
              ? 'Ask about this workout...'
              : 'Tell me what to change...',
          placeholderStyle: AppTypography.body.copyWith(
            color: AppColors.textColor3,
          ),
          style: AppTypography.body,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundDepth2,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderDepth1),
          ),
          maxLines: 2,
          onChanged: (_) => onFeedbackChanged(),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: AppColors.backgroundDepth3,
            onPressed: feedbackController.text.isEmpty
                ? null
                : isAskMode
                ? () => onAsk(feedbackController.text)
                : () => onRefine(feedbackController.text),
            child: Text(isAskMode ? 'Ask' : 'Refine'),
          ),
        ),
      ],
    );
  }

  Widget _modePicker() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<RefinementMode>(
        groupValue: mode,
        onValueChanged: (selectedMode) {
          if (selectedMode != null) onModeChanged(selectedMode);
        },
        children: const {
          RefinementMode.refine: Text('Refine'),
          RefinementMode.ask: Text('Ask'),
        },
      ),
    );
  }
}
