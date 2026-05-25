import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/theme/hr_zone_palette.dart';
import 'package:workouts/utils/hr_zone_classifier.dart';

/// Read-only reference table showing the fixed 5-zone bpm boundaries.
///
/// Lives under Diagnostics because it's reference, not a setting — there's
/// nothing to change here.
class HrZonesReferenceTile extends StatelessWidget {
  const HrZonesReferenceTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.md),
          _zoneTable(),
        ],
      ),
    );
  }

  Widget _header() => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Icon(
          CupertinoIcons.heart_fill,
          color: AppColors.error,
          size: 22,
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Text('Heart Rate Zones', style: AppTypography.subtitle),
    ],
  );

  Widget _zoneTable() => Column(
    children: List.generate(5, (zoneIndex) {
      final lower = HrZoneClassifier.zoneBoundaries[zoneIndex];
      final upper = HrZoneClassifier.zoneUpperBounds[zoneIndex];
      return _zoneRow(zoneIndex, lower, upper);
    }),
  );

  Widget _zoneRow(int zoneIndex, int lower, int upper) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: HrZonePalette.zoneColors[zoneIndex],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 20,
          child: Text(
            'Z${zoneIndex + 1}',
            style: AppTypography.caption.copyWith(
              color: HrZonePalette.zoneColors[zoneIndex],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          HrZonePalette.zoneShortNames[zoneIndex],
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
        ),
        const Spacer(),
        Text(
          '$lower – $upper bpm',
          style: AppTypography.caption.copyWith(color: AppColors.textColor3),
        ),
      ],
    ),
  );
}
