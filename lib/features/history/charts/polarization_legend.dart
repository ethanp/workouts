import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/theme/hr_zone_palette.dart';

class const PolarizationLegend() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: EColors.surfaceRaised,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final zone in HrZone.values) ...[
                if (zone.index > 0)
                  ColoredBox(
                    color: EColors.textMuted.withValues(alpha: 0.28),
                    child: const SizedBox(width: 1),
                  ),
                _zone(HrZonePalette.zoneColors[zone.index], zone),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _zone(Color color, HrZone zone) {
    return ColoredBox(
      color: color.withValues(alpha: 0.16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  'Z${zone.index + 1}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: EColors.textTertiary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            Text(
              '${zone.lowerBpm}–${zone.upperBpm}',
              style: const TextStyle(
                fontSize: 8,
                color: EColors.textTertiary,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
