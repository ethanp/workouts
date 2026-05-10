import 'package:flutter/cupertino.dart';
import 'package:workouts/features/history/charts/polarization_formatting.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/theme/hr_zone_palette.dart';

class PolarizationLegend extends StatelessWidget {
  const PolarizationLegend({
    super.key,
    required this.isExpanded,
    required this.onToggle,
  });

  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _compactLegend(),
        if (isExpanded) ...[
          const SizedBox(height: AppSpacing.xs),
          _expandedLegend(),
        ],
      ],
    );
  }

  Widget _compactLegend() {
    return GestureDetector(
      onTap: () => onToggle(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var zoneIndex = 0; zoneIndex < 5; zoneIndex++) ...[
            if (zoneIndex > 0) const SizedBox(width: AppSpacing.sm),
            _legendDot(
              HrZonePalette.zoneColors[zoneIndex],
              'Z${zoneIndex + 1}',
            ),
          ],
          const SizedBox(width: 5),
          Icon(
            CupertinoIcons.info_circle,
            size: 12,
            color: isExpanded
                ? AppColors.textColor3
                : AppColors.textColor4.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }

  Widget _expandedLegend() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        for (var zoneIndex = 0; zoneIndex < 5; zoneIndex++)
          _legendDotExpanded(
            HrZonePalette.zoneColors[zoneIndex],
            HrZonePalette.zoneShortNames[zoneIndex],
            formatPolarizationZoneRange(zoneIndex + 1),
          ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textColor4),
        ),
      ],
    );
  }

  Widget _legendDotExpanded(Color color, String name, String range) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 10, color: AppColors.textColor4),
            ),
            Text(
              range,
              style: const TextStyle(fontSize: 8, color: AppColors.textColor4),
            ),
          ],
        ),
      ],
    );
  }
}
