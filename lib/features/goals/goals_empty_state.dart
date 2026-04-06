import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';

class GoalsEmptyState extends StatelessWidget {
  const GoalsEmptyState({super.key, required this.onAddGoal});

  final VoidCallback onAddGoal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                CupertinoIcons.flag_fill,
                size: 32,
                color: AppColors.accentPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('No Goals Yet', style: AppTypography.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add goals to personalise your training and track what matters.',
              style: AppTypography.body.copyWith(color: AppColors.textColor3),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            CupertinoButton.filled(
              onPressed: onAddGoal,
              child: const Text(
                'Add Your First Goal',
                style: TextStyle(
                  color: CupertinoColors.white,
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
