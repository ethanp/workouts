import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:workouts/features/history/charts/polarization_formatting.dart';
import 'package:workouts/theme/hr_zone_palette.dart';

class const PolarizationLegend({
  required final bool isExpanded,
  required final VoidCallback onToggle,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _compactLegend(),
        if (isExpanded) ...[
          const SizedBox(height: ELayout.spaceXs),
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
            if (zoneIndex > 0) const SizedBox(width: ELayout.spaceSm),
            _legendDot(
              HrZonePalette.zoneColors[zoneIndex],
              'Z${zoneIndex + 1}',
            ),
          ],
          const SizedBox(width: 5),
          Icon(
            Icons.info_outline,
            size: 12,
            color: isExpanded
                ? EColors.textTertiary
                : EColors.textMuted.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }

  Widget _expandedLegend() {
    return Wrap(
      spacing: ELayout.spaceMd,
      runSpacing: ELayout.spaceXs,
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
          style: const TextStyle(fontSize: 10, color: EColors.textMuted),
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
              style: const TextStyle(fontSize: 10, color: EColors.textMuted),
            ),
            Text(
              range,
              style: const TextStyle(fontSize: 8, color: EColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}
