import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/features/workout_generation/options/workout_option_card.dart';
import 'package:workouts/models/llm_workout_option.dart';

class const WorkoutOptionsList({
  required final LlmWorkoutResponse response,
  required final String? expandedOptionId,
  required final void Function(String optionId) onToggleOption,
  required final void Function(LlmWorkoutOption option) onSelectOption,
  final bool showExplanation = true,
  final Widget? footer,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(ELayout.spaceLg),
      children: [
        if (showExplanation) _explanation(),
        ...response.options.map(
          (option) => WorkoutOptionCard(
            option: option,
            isExpanded: expandedOptionId == option.id,
            onExpansionToggled: () => onToggleOption(option.id),
            onWorkoutSelected: () => onSelectOption(option),
          ),
        ),
        if (footer != null) ...[const SizedBox(height: ELayout.spaceXl), footer!],
      ],
    );
  }

  Widget _explanation() {
    return Container(
      padding: const EdgeInsets.all(ELayout.spaceMd),
      margin: const EdgeInsets.only(bottom: ELayout.spaceLg),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Text(
        response.explanation,
        style: EText.body.medium.copyWith(
          color: EColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
