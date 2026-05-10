import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';

class EmptyActivityPlaceholder extends StatelessWidget {
  const EmptyActivityPlaceholder({super.key, this.onImport});

  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.clock, size: 64, color: AppColors.textColor4),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No activity yet',
            style: AppTypography.title.copyWith(color: AppColors.textColor3),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Import cardio workouts from Apple Health or complete workout sessions '
            'to see them here.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textColor4),
          ),
          if (onImport != null) ...[
            const SizedBox(height: AppSpacing.lg),
            CupertinoButton.filled(
              onPressed: onImport,
              child: const Text('Import Workouts'),
            ),
          ],
        ],
      ),
    );
  }
}
