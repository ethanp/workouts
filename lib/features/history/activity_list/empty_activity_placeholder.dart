import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';

class const EmptyActivityPlaceholder({final VoidCallback? onImport})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 64, color: EColors.textMuted),
          const SizedBox(height: ELayout.spaceLg),
          Text(
            'No activity yet',
            style: EText.title.copyWith(color: EColors.textTertiary),
          ),
          const SizedBox(height: ELayout.spaceSm),
          Text(
            'Import cardio workouts from Apple Health or complete workout sessions '
            'to see them here.',
            textAlign: TextAlign.center,
            style: EText.body.medium.copyWith(color: EColors.textMuted),
          ),
          if (onImport != null) ...[
            const SizedBox(height: ELayout.spaceLg),
            FilledButton(
              onPressed: onImport,
              child: const Text('Import Workouts'),
            ),
          ],
        ],
      ),
    );
  }
}
