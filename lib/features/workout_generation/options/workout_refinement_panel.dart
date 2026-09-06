import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:workouts/features/workout_generation/options/workout_followup_answer.dart';
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
        const SizedBox(height: ELayout.spaceMd),
        if (followupAnswer != null && followupAnswer!.isNotEmpty) ...[
          WorkoutFollowupAnswer(answer: followupAnswer!, answering: false),
          const SizedBox(height: ELayout.spaceMd),
        ],
        TextField(
          controller: feedbackController,
          decoration: InputDecoration(
            hintText: isAskMode
                ? 'Ask about this workout...'
                : 'Tell me what to change...',
          ),
          maxLines: 2,
          onChanged: (_) => onFeedbackChanged(),
        ),
        const SizedBox(height: ELayout.spaceMd),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
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
      child: SegmentedButton<RefinementMode>(
        segments: const [
          ButtonSegment(value: RefinementMode.refine, label: Text('Refine')),
          ButtonSegment(value: RefinementMode.ask, label: Text('Ask')),
        ],
        selected: {mode},
        onSelectionChanged: (modes) => onModeChanged(modes.single),
      ),
    );
  }
}
