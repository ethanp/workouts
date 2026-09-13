import 'package:ethan_utils/ethan_utils.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/cardio/cardio_detail_screen.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/theme/cardio_type_palette.dart';
import 'package:workouts/theme/hr_zone_palette.dart';
import 'package:workouts/utils/run_formatting.dart';

class const CardioWorkoutListTile({required final CardioWorkout workout})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.push(CardioDetailScreen(workout: workout)),
      child: _tileCard(),
    );
  }

  Widget _tileCard() => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: ELayout.spaceMd,
      vertical: ELayout.spaceSm,
    ),
    decoration: BoxDecoration(
      color: EColors.backgroundLift,
      borderRadius: BorderRadius.circular(ELayout.radiusMd),
      border: Border.all(color: EColors.border),
    ),
    child: Row(
      children: [
        _activityTypeColorBar(),
        const SizedBox(width: ELayout.spaceSm),
        Expanded(child: _workoutInfo()),
        ..._trailingIcons(),
      ],
    ),
  );

  Widget _activityTypeColorBar() => Container(
    width: 3,
    height: 42,
    decoration: BoxDecoration(
      color: workout.activityType.color,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _workoutInfo() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _activityHeader(),
      const SizedBox(height: 2),
      _summaryLine(),
      if (_showsZoneBreakdown()) ...[
        const SizedBox(height: ELayout.spaceXs),
        _zoneBreakdown(),
      ],
    ],
  );

  Widget _activityHeader() => Row(
    children: [
      Text(
        workout.activityType.displayName,
        style: EText.caption.copyWith(
          color: workout.activityType.color,
          fontWeight: FontWeight.w600,
        ),
      ),
      Text(
        '  ·  ${Format.dateIso(workout.startedAt)}',
        style: EText.caption.copyWith(color: EColors.textTertiary),
      ),
    ],
  );

  Widget _summaryLine() => Text(
    _summaryText(),
    style: EText.body.medium.copyWith(color: EColors.textPrimary),
  );

  List<Widget> _trailingIcons() => [
    if (workout.activityType.hasRoute && workout.routeAvailable)
      Padding(
        padding: const EdgeInsets.only(left: ELayout.spaceSm),
        child: Icon(Icons.map, color: workout.activityType.color, size: 16),
      ),
    const SizedBox(width: ELayout.spaceXs),
    const Icon(
      Icons.chevron_right,
      color: EColors.textMuted,
      size: 14,
    ),
  ];

  String _summaryText() {
    final duration = Format.duration(workout.durationSeconds);
    if (workout.displayDistanceMeters <= 0) {
      final flightsClimbed = workout.flightsClimbed;
      if (flightsClimbed != null && flightsClimbed > 0) {
        return '${flightsClimbed.round()} flights  ·  $duration';
      }
      return duration;
    }
    return '${Format.distance(workout.displayDistanceMeters)}  ·  '
        '$duration  ·  '
        '${Format.pace(workout.durationSeconds, workout.displayDistanceMeters)}';
  }

  bool _showsZoneBreakdown() =>
      workout.hasHrSamples && workout.zoneTime.total > 0;

  Widget _zoneBreakdown() {
    return Wrap(
      spacing: ELayout.spaceSm,
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
          style: const TextStyle(fontSize: 10, color: EColors.textMuted),
        ),
      ],
    );
  }
}
