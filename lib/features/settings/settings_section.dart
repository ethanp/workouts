import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';

/// A section of the settings screen with a header label and stacked tiles.
///
/// Tiles are spaced with [AppSpacing.md] between each other and the section
/// itself is padded with [AppSpacing.lg] below the header for breathing room.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: AppColors.textColor4,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
        for (var childIndex = 0; childIndex < children.length; childIndex++) ...[
          children[childIndex],
          if (childIndex < children.length - 1)
            const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
