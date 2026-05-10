import 'package:flutter/cupertino.dart';
import 'package:workouts/features/workout_generation/options/workout_option_card.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/theme/app_theme.dart';

class WorkoutOptionsList extends StatelessWidget {
  const WorkoutOptionsList({
    super.key,
    required this.response,
    required this.expandedOptionId,
    required this.onToggleOption,
    required this.onSelectOption,
    this.showExplanation = true,
    this.footer,
  });

  final LlmWorkoutResponse response;
  final String? expandedOptionId;
  final void Function(String optionId) onToggleOption;
  final void Function(LlmWorkoutOption option) onSelectOption;
  final bool showExplanation;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (showExplanation) _explanation(),
        ...response.options.map(
          (option) => WorkoutOptionCard(
            option: option,
            isExpanded: expandedOptionId == option.id,
            onTap: () => onToggleOption(option.id),
            onSelect: () => onSelectOption(option),
          ),
        ),
        if (footer != null) ...[const SizedBox(height: AppSpacing.xl), footer!],
      ],
    );
  }

  Widget _explanation() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Text(
        response.explanation,
        style: AppTypography.body.copyWith(
          color: AppColors.textColor2,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
