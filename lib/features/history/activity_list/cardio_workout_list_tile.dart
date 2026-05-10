import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/cardio/cardio_detail_screen.dart';
import 'package:workouts/features/settings/unit_system_provider.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/theme/cardio_type_palette.dart';
import 'package:workouts/theme/hr_zone_palette.dart';
import 'package:workouts/utils/run_formatting.dart';

class CardioWorkoutListTile extends ConsumerWidget {
  const CardioWorkoutListTile({super.key, required this.workout});

  final CardioWorkout workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitSystem = ref.watch(unitSystemProvider);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => context.push(CardioDetailScreen(workout: workout)),
      child: _tileCard(unitSystem),
    );
  }

  Widget _tileCard(UnitSystem unitSystem) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: AppColors.backgroundDepth2,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.borderDepth1),
    ),
    child: Row(
      children: [
        _typeStripe(),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _workoutInfo(unitSystem)),
        ..._trailingIcons(),
      ],
    ),
  );

  Widget _typeStripe() => Container(
    width: 3,
    height: 42,
    decoration: BoxDecoration(
      color: _typeColor(),
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _workoutInfo(UnitSystem unitSystem) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _activityHeader(),
      const SizedBox(height: 2),
      _summaryLine(unitSystem),
      if (_showsZoneBreakdown()) ...[
        const SizedBox(height: AppSpacing.xs),
        _zoneBreakdown(),
      ],
    ],
  );

  Widget _activityHeader() => Row(
    children: [
      Text(
        workout.activityType.displayName,
        style: AppTypography.caption.copyWith(
          color: _typeColor(),
          fontWeight: FontWeight.w600,
        ),
      ),
      Text(
        '  ·  ${Format.dateIso(workout.startedAt)}',
        style: AppTypography.caption.copyWith(color: AppColors.textColor3),
      ),
    ],
  );

  Widget _summaryLine(UnitSystem unitSystem) => Text(
    _summaryText(unitSystem),
    style: AppTypography.body.copyWith(color: AppColors.textColor1),
  );

  List<Widget> _trailingIcons() => [
    if (workout.activityType.hasRoute && workout.routeAvailable)
      Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        child: Icon(CupertinoIcons.map, color: _typeColor(), size: 16),
      ),
    const SizedBox(width: AppSpacing.xs),
    const Icon(
      CupertinoIcons.chevron_right,
      color: AppColors.textColor4,
      size: 14,
    ),
  ];

  String _summaryText(UnitSystem unitSystem) {
    final duration = Format.duration(workout.durationSeconds);
    if (!workout.activityType.hasDistance || workout.distanceMeters <= 0) {
      return duration;
    }
    return '${Format.distance(workout.distanceMeters, unitSystem)}  ·  '
        '$duration  ·  '
        '${Format.pace(workout.durationSeconds, workout.distanceMeters, unitSystem)}';
  }

  Color _typeColor() => CardioTypePalette.colorFor(workout.activityType);

  bool _showsZoneBreakdown() =>
      workout.hasHrSamples && workout.zoneTime.total > 0;

  Widget _zoneBreakdown() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: 2,
      children: [
        for (
          var zoneIndex = 0;
          zoneIndex < HrZonePalette.zoneColors.length;
          zoneIndex++
        )
          if (workout.zoneTime[zoneIndex] > 0) _zoneChip(zoneIndex),
      ],
    );
  }

  Widget _zoneChip(int zoneIndex) {
    final zoneSeconds = workout.zoneTime[zoneIndex];
    final percent = (zoneSeconds / workout.zoneTime.total * 100).round();
    final minutes = zoneSeconds ~/ 60;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: HrZonePalette.zoneColors[zoneIndex],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          'Z${zoneIndex + 1} ${minutes}m $percent%',
          style: const TextStyle(fontSize: 10, color: AppColors.textColor4),
        ),
      ],
    );
  }
}
