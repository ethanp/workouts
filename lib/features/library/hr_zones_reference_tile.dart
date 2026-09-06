import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:workouts/theme/hr_zone_palette.dart';
import 'package:workouts/utils/hr_zone_classifier.dart';

/// Read-only reference table showing the fixed 5-zone bpm boundaries.
class const HrZonesReferenceTile() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: ELayout.spaceMd),
          _zoneTable(),
        ],
      ),
    );
  }

  Widget _header() => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: EColors.surface,
          borderRadius: BorderRadius.circular(ELayout.radiusSm),
        ),
        child: const Icon(Icons.favorite, color: EColors.danger, size: 18),
      ),
      const SizedBox(width: ELayout.spaceMd),
      Text('Heart Rate Zones', style: EText.section),
    ],
  );

  Widget _zoneTable() {
    final zoneCodeStyle = EText.caption.copyWith(fontWeight: FontWeight.w600);
    final zoneCodeWidth = [
      for (var zoneIndex = 0; zoneIndex < 5; zoneIndex++) 'Z${zoneIndex + 1}',
    ].widestLaidOutWidth(zoneCodeStyle);

    return Column(
      children: [
        for (var zoneIndex = 0; zoneIndex < 5; zoneIndex++)
          _zoneRow(
            zoneIndex: zoneIndex,
            zoneCodeWidth: zoneCodeWidth,
            zoneCodeStyle: zoneCodeStyle,
          ),
      ],
    );
  }

  Widget _zoneRow({
    required int zoneIndex,
    required double zoneCodeWidth,
    required TextStyle zoneCodeStyle,
  }) {
    final lowerBpm = HrZoneClassifier.zoneBoundaries[zoneIndex];
    final upperBpm = HrZoneClassifier.zoneUpperBounds[zoneIndex];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          _zoneSwatch(zoneIndex),
          const SizedBox(width: ELayout.spaceSm),
          SizedBox(
            width: zoneCodeWidth,
            child: Text(
              'Z${zoneIndex + 1}',
              style: zoneCodeStyle.copyWith(
                color: HrZonePalette.zoneColors[zoneIndex],
              ),
              maxLines: 1,
              softWrap: false,
            ),
          ),
          const SizedBox(width: ELayout.spaceSm),
          Expanded(
            child: Text(
              HrZonePalette.zoneShortNames[zoneIndex],
              style: EText.caption.copyWith(color: EColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: ELayout.spaceMd),
          Text(
            '$lowerBpm–$upperBpm bpm',
            style: EText.caption.copyWith(color: EColors.textTertiary),
            maxLines: 1,
            softWrap: false,
          ),
        ],
      ),
    );
  }

  Widget _zoneSwatch(int zoneIndex) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: HrZonePalette.zoneColors[zoneIndex],
      shape: BoxShape.circle,
    ),
  );
}
