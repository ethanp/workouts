import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';

class const WorkoutFollowupAnswer({
  required final String answer,
  required final bool answering,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (answer.isNotEmpty) _answerCard(),
        if (answering) ...[
          if (answer.isNotEmpty) const SizedBox(height: ELayout.spaceMd),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  Widget _answerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Text(
        answer,
        style: EText.body.medium.copyWith(color: EColors.textSecondary),
      ),
    );
  }
}
