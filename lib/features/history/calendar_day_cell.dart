import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/utils/run_formatting.dart';

class const WeekMax({
  required final double maxCardioMeters,
  required final int maxSessionMinutes,
});

class const CalendarDayCell({
  required final DateTime date,
  required final ActivityCalendarDay? entry,
  required final WeekMax globalMax,
  required final VoidCallback onActivated,
}) extends StatelessWidget {
  static const cellSize = 39.0;
  static const cellMargin = 2.0;
  static const cellExtent = cellSize + cellMargin * 2;

  static double intensityForDay({
    required double cardioMeters,
    required int sessionMinutes,
    required WeekMax globalMax,
  }) {
    if (cardioMeters > 0 && globalMax.maxCardioMeters > 0) {
      return (cardioMeters / globalMax.maxCardioMeters).clamp(0.0, 1.0);
    }
    if (sessionMinutes > 0 && globalMax.maxSessionMinutes > 0) {
      return (sessionMinutes / globalMax.maxSessionMinutes).clamp(0.0, 1.0) *
          0.5;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final hasActivity = entry?.hasActivity ?? false;
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final intensity = hasActivity
        ? intensityForDay(
            cardioMeters: entry!.outdoorRunDistanceMeters,
            sessionMinutes: entry!.totalSessionDurationSeconds ~/ 60,
            globalMax: globalMax,
          )
        : 0.0;
    final cellColor = hasActivity
        ? EHeatmapIntensity.colorAt(intensity)
        : EHeatmapIntensity.none.color;

    return GestureDetector(
      onTap: onActivated,
      child: Container(
        width: cellSize,
        height: cellSize,
        margin: const EdgeInsets.all(cellMargin),
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isToday
                ? EHeatmapIntensity.todayRing
                : hasActivity
                ? cellColor.withValues(alpha: 0.6)
                : EHeatmapIntensity.cellHairline.color,
            width: isToday ? 1.5 : EHeatmapIntensity.cellHairline.width,
          ),
          boxShadow: hasActivity
              ? [
                  BoxShadow(
                    color: cellColor.withValues(alpha: 0.3),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: hasActivity ? _activeContent(intensity) : _inactiveContent(),
      ),
    );
  }

  Widget _inactiveContent() {
    return Center(
      child: Text(
        '${date.day}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: EColors.textMuted.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _activeContent(double intensity) {
    final Color labelInk = EHeatmapIntensity.inkAt(intensity);

    return Stack(
      children: [
        Positioned(left: 3, top: 2, child: _dayNumber(labelInk)),
        Positioned(right: 2, top: 12, child: _activityLabel(labelInk)),
        Positioned(right: 2, bottom: 2, child: _zoneLabel(labelInk)),
      ],
    );
  }

  Widget _dayNumber(Color textColor) {
    return Text(
      '${date.day}',
      style: TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w500,
        color: textColor.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _activityLabel(Color textColor) {
    final parts = <String>[];
    if (entry!.outdoorRunDistanceMeters > 0) {
      parts.add(Format.distanceCompact(entry!.outdoorRunDistanceMeters));
    }
    if (entry!.totalCardioDurationSeconds > 0 &&
        entry!.outdoorRunDistanceMeters <= 0) {
      parts.add('${entry!.totalCardioDurationSeconds ~/ 60}m');
    }
    if (entry!.totalSessionDurationSeconds > 0) {
      parts.add('${entry!.totalSessionDurationSeconds ~/ 60}m');
    }
    return Text(
      parts.isEmpty ? '-' : parts.join(' · '),
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w300,
        color: textColor,
      ),
    );
  }

  Widget _zoneLabel(Color textColor) {
    if (!entry!.cardioHasHrData || entry!.cardioZoneTime.gteZone2Minutes <= 0) {
      return const SizedBox.shrink();
    }
    return Text(
      '${entry!.cardioZoneTime.gteZone2Minutes}z2-5',
      textAlign: TextAlign.right,
      style: TextStyle(fontSize: 8, color: textColor.withValues(alpha: 0.75)),
    );
  }
}

class const EmptyDayCell() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: CalendarDayCell.cellExtent,
      height: CalendarDayCell.cellExtent,
    );
  }
}
