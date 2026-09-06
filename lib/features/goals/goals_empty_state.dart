import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';

class const GoalsEmptyState({required final VoidCallback onAddGoal})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ELayout.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: EColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.flag,
                size: 32,
                color: EColors.accent,
              ),
            ),
            const SizedBox(height: ELayout.spaceXl),
            Text('No Goals Yet', style: EText.title),
            const SizedBox(height: ELayout.spaceSm),
            Text(
              'Add goals to personalise your training and track what matters.',
              style: EText.body.medium.copyWith(color: EColors.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: onAddGoal,
              child: const Text(
                'Add Your First Goal',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
