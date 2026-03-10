import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/theme/app_theme.dart';

const _zoneColors = [
  Color(0xFF8E8E93), // Z1 gray
  Color(0xFF30D158), // Z2 green
  Color(0xFFFFD60A), // Z3 yellow
  Color(0xFFFF9F0A), // Z4 orange
  Color(0xFFFF453A), // Z5 red
];

class WeeklyStackedZoneChart extends StatefulWidget {
  const WeeklyStackedZoneChart({super.key, required this.weeks});

  final List<WeekZoneData> weeks;

  @override
  State<WeeklyStackedZoneChart> createState() => _WeeklyStackedZoneChartState();
}

class _WeeklyStackedZoneChartState extends State<WeeklyStackedZoneChart> {
  int? _activeIndex;

  List<WeekZoneData> get weeks => widget.weeks;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _activeIndex = null),
      behavior: HitTestBehavior.opaque,
      child: Container(
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
            _barsWithYearBoundaries(),
            const SizedBox(height: AppSpacing.sm),
            _legend(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Text('HR Zone Breakdown', style: AppTypography.subtitle);
  }

  Widget _legend() {
    const labels = ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var z = 0; z < 5; z++) ...[
          if (z > 0) const SizedBox(width: AppSpacing.md),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _zoneColors[z],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            labels[z],
            style: TextStyle(fontSize: 10, color: AppColors.textColor3),
          ),
        ],
      ],
    );
  }

  List<int> _yearBoundaryIndices() {
    final indices = <int>[];
    for (var i = 1; i < weeks.length; i++) {
      if (weeks[i].weekStart.year != weeks[i - 1].weekStart.year) {
        indices.add(i);
      }
    }
    return indices;
  }

  double _barSpacing() => switch (weeks.length) {
        > 24 => 1.0,
        > 16 => 2.0,
        _ => 4.0,
      };

  Widget _barsWithYearBoundaries() {
    final boundaries = _yearBoundaryIndices();
    final barsAndLabels = Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.textColor4.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: SizedBox(height: 140, child: _bars()),
        ),
        const SizedBox(height: AppSpacing.xs),
        _labels(),
      ],
    );

    if (boundaries.isEmpty) return barsAndLabels;

    final count = weeks.length;
    final barSpacing = _barSpacing();

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = barSpacing * (count - 1);
        final barWidth = (constraints.maxWidth - totalSpacing) / count;

        return Stack(
          children: [
            barsAndLabels,
            for (final boundaryIndex in boundaries)
              Positioned(
                left: boundaryIndex * (barWidth + barSpacing) - barSpacing / 2,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 1,
                  color: AppColors.textColor4.withValues(alpha: 0.3),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _bars() {
    if (weeks.isEmpty) {
      return const Center(
        child: Text('No data yet', style: AppTypography.caption),
      );
    }

    final maxTotal =
        weeks.fold(0, (m, w) => math.max(m, w.zoneTime.total));
    final effectiveMax = maxTotal > 0 ? maxTotal : 1;
    final barSpacing = _barSpacing();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < weeks.length; i++) ...[
          if (i > 0) SizedBox(width: barSpacing),
          Expanded(child: _stackedBar(i, effectiveMax)),
        ],
      ],
    );
  }

  Widget _stackedBar(int index, int maxTotal) {
    final week = weeks[index];
    final isActive = _activeIndex == index;

    return MouseRegion(
      onEnter: (_) => setState(() => _activeIndex = index),
      onExit: (_) => setState(() => _activeIndex = null),
      child: GestureDetector(
        onTapDown: (_) => setState(
          () => _activeIndex = _activeIndex == index ? null : index,
        ),
        behavior: HitTestBehavior.opaque,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalFraction =
                (week.zoneTime.total / maxTotal).clamp(0.0, 1.0);
            final totalBarHeight = totalFraction * constraints.maxHeight;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: totalBarHeight,
                    width: double.infinity,
                    child: Column(
                      children: [
                        for (var z = 4; z >= 0; z--)
                          _zoneSegment(week, z, isActive),
                      ],
                    ),
                  ),
                ),
                if (isActive && week.zoneTime.total > 0)
                  Positioned(
                    bottom: totalBarHeight + 2,
                    left: -12,
                    right: -12,
                    child: Text(
                      '${week.zoneTime.totalMinutes}m',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textColor2,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.visible,
                      maxLines: 1,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _zoneSegment(WeekZoneData week, int zoneIndex, bool isActive) {
    final zoneValue = week.zoneTime[zoneIndex];
    if (week.zoneTime.total == 0 || zoneValue == 0) {
      return const SizedBox.shrink();
    }
    final fraction = zoneValue / week.zoneTime.total;
    final color = _zoneColors[zoneIndex];
    return Flexible(
      flex: (fraction * 1000).round(),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.7),
          borderRadius: zoneIndex == 4
              ? const BorderRadius.vertical(top: Radius.circular(3))
              : null,
        ),
      ),
    );
  }

  Widget _labels() {
    final count = weeks.length;
    final (labelStride, barSpacing) = switch (count) {
      > 40 => (8, 1.0),
      > 24 => (4, 1.0),
      > 16 => (2, 2.0),
      _ => (1, 4.0),
    };

    return SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalSpacing = barSpacing * (count - 1);
          final barWidth = (constraints.maxWidth - totalSpacing) / count;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < count; i++)
                if (i % labelStride == 0 || weeks[i].isCurrent)
                  Positioned(
                    left: i * (barWidth + barSpacing) + barWidth / 2 - 20,
                    top: 0,
                    child: SizedBox(
                      width: 40,
                      child: Text(
                        weeks[i].label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          color: weeks[i].isCurrent
                              ? AppColors.accentPrimary
                              : AppColors.textColor4,
                          fontWeight: weeks[i].isCurrent
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class WeekZoneData {
  const WeekZoneData({
    required this.label,
    required this.weekStart,
    required this.zoneTime,
    this.isCurrent = false,
    this.includeInAverage = true,
  });

  final String label;
  final DateTime weekStart;
  final HrZoneTime zoneTime;
  final bool isCurrent;
  final bool includeInAverage;
}
