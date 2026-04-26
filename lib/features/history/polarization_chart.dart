import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/training_load_calculator.dart';

String _formatMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
}

/// Formats a zone range label, e.g. `_formatZoneRange(1, 2)` → `"Z1–2 · 93–145"`.
String _formatZoneRange(int fromZone, [int? toZone]) {
  toZone ??= fromZone;
  final lower = TrainingLoadCalculator.zoneBoundaries[fromZone - 1];
  final upper = TrainingLoadCalculator.zoneUpperBounds[toZone - 1];
  final zoneLabel = fromZone == toZone ? 'Z$fromZone' : 'Z$fromZone–$toZone';
  return '$zoneLabel · $lower–$upper';
}

const _z1Color = Color(0xFF5BB5EA); // sky blue — recovery
const _z2Color = Color(0xFF36BF7E); // emerald — aerobic base
const _z3Color = Color(0xFFECC048); // golden amber — tempo / gray zone
const _z4Color = Color(0xFFE87838); // burnt orange — threshold
const _z5Color = Color(0xFFDC4858); // crimson — VO₂max

const _zoneColors = [_z1Color, _z2Color, _z3Color, _z4Color, _z5Color];
const _zoneNames = [
  'Z1 Recovery',
  'Z2 Aerobic',
  'Z3 Tempo',
  'Z4 Threshold',
  'Z5 VO₂max',
];
const _zoneShortNames = ['Recovery', 'Aerobic', 'Tempo', 'Threshold', 'VO₂max'];
const _kAerobicBaseTargetSeconds = 90 * 60; // 90 min/week aerobic base target

/// Stacked weekly bar chart showing time in each of the 5 HR zones.
///
/// Bar height encodes total zone volume; color segments encode zone split.
/// Both are simultaneously visible, so a polarized week (lots of blue/green
/// and red, little amber) is visually distinct from a gray-zone-heavy week.
///
/// Horizontal drag activates a scrub cursor and live readout panel.
class PolarizationChart extends StatefulWidget {
  const PolarizationChart({super.key, required this.weeks});

  final List<WeekZoneData> weeks;

  @override
  State<PolarizationChart> createState() => _PolarizationChartState();
}

class _PolarizationChartState extends State<PolarizationChart> {
  int? _scrubIndex;
  bool _legendExpanded = false;

  List<WeekZoneData> get weeks => widget.weeks;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _scrubIndex = null),
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
            _barsSection(),
            const SizedBox(height: AppSpacing.sm),
            _labels(),
            const SizedBox(height: AppSpacing.sm),
            _ScrubDetailPanel(
              week: _scrubIndex != null ? weeks[_scrubIndex!] : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Polarization', style: AppTypography.subtitle),
            ),
            _compactLegend(),
          ],
        ),
        if (_legendExpanded) ...[
          const SizedBox(height: AppSpacing.xs),
          _expandedLegend(),
        ],
      ],
    );
  }

  Widget _compactLegend() {
    return GestureDetector(
      onTap: () => setState(() => _legendExpanded = !_legendExpanded),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var zoneIndex = 0; zoneIndex < 5; zoneIndex++) ...[
            if (zoneIndex > 0) const SizedBox(width: AppSpacing.sm),
            _legendDot(_zoneColors[zoneIndex], 'Z${zoneIndex + 1}'),
          ],
          const SizedBox(width: 5),
          Icon(
            CupertinoIcons.info_circle,
            size: 12,
            color: _legendExpanded
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
            _zoneColors[zoneIndex],
            _zoneShortNames[zoneIndex],
            _formatZoneRange(zoneIndex + 1),
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

  Widget _barsSection() {
    final yearBoundaries = _yearBoundaryIndices();

    final barsArea = Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.textColor4.withValues(alpha: 0.4),
              ),
            ),
          ),
          child: SizedBox(height: 140, child: _barsWithScrub()),
        ),
      ],
    );

    if (yearBoundaries.isEmpty) return barsArea;

    final count = weeks.length;
    final barSpacing = _barSpacing();

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth =
            (constraints.maxWidth - barSpacing * (count - 1)) / count;
        return Stack(
          children: [
            barsArea,
            for (final boundaryIndex in yearBoundaries)
              Positioned(
                left: boundaryIndex * (barWidth + barSpacing) -
                    barSpacing / 2,
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

  Widget _barsWithScrub() {
    if (weeks.isEmpty) {
      return const Center(
        child: Text('No data yet', style: AppTypography.caption),
      );
    }

    final zoneTimes = weeks.map((week) => week.zoneTime).toList();
    final maxTotal = zoneTimes.fold(
      0,
      (maxSoFar, zoneTime) => math.max(maxSoFar, zoneTime.total),
    );
    final effectiveMax = maxTotal > 0 ? maxTotal : 1;
    final barSpacing = _barSpacing();
    final referenceFraction = _kAerobicBaseTargetSeconds / effectiveMax;

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth =
            (constraints.maxWidth - barSpacing * (weeks.length - 1)) /
            weeks.length;

        return GestureDetector(
          onHorizontalDragStart: (details) => _updateScrubFromOffset(
            details.localPosition.dx,
            barWidth,
            barSpacing,
            weeks.length,
          ),
          onHorizontalDragUpdate: (details) => _updateScrubFromOffset(
            details.localPosition.dx,
            barWidth,
            barSpacing,
            weeks.length,
          ),
          onHorizontalDragEnd: (_) => setState(() => _scrubIndex = null),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              _barsRow(zoneTimes, effectiveMax, barSpacing),
              if (referenceFraction <= 1.0)
                _referenceLine(
                  referenceFraction,
                  constraints.maxHeight,
                  '90m aerobic base',
                ),
              if (_scrubIndex != null)
                _scrubCursor(barWidth, barSpacing),
            ],
          ),
        );
      },
    );
  }

  Widget _barsRow(
    List<HrZoneTime> zoneTimes,
    int effectiveMax,
    double barSpacing,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var weekIndex = 0; weekIndex < weeks.length; weekIndex++) ...[
          if (weekIndex > 0) SizedBox(width: barSpacing),
          Expanded(
            child: _stackedBar(zoneTimes[weekIndex], effectiveMax, weekIndex),
          ),
        ],
      ],
    );
  }

  Widget _referenceLine(double referenceFraction, double chartHeight, String label) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: referenceFraction * chartHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              color: _z2Color.withValues(alpha: 0.6),
            ),
          ),
          Container(
            height: 1,
            color: _z2Color.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }

  Widget _scrubCursor(double barWidth, double barSpacing) {
    return Positioned(
      left: _scrubIndex! * (barWidth + barSpacing) + barWidth / 2,
      top: 0,
      bottom: 0,
      child: Container(
        width: 1,
        color: AppColors.textColor3.withValues(alpha: 0.6),
      ),
    );
  }

  void _updateScrubFromOffset(
    double dx,
    double barWidth,
    double barSpacing,
    int count,
  ) {
    final rawIndex = (dx / (barWidth + barSpacing)).floor();
    final clampedIndex = rawIndex.clamp(0, count - 1);
    if (_scrubIndex != clampedIndex) {
      setState(() => _scrubIndex = clampedIndex);
    }
  }

  Widget _stackedBar(
    HrZoneTime zoneTime,
    int maxTotalSeconds,
    int weekIndex,
  ) {
    final isActive = _scrubIndex == weekIndex;

    return MouseRegion(
      onEnter: (_) => setState(() => _scrubIndex = weekIndex),
      onExit: (_) {
        if (_scrubIndex == weekIndex) setState(() => _scrubIndex = null);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (zoneTime.total == 0) return const SizedBox.expand();

          final totalFraction =
              (zoneTime.total / maxTotalSeconds).clamp(0.0, 1.0);
          final barHeight = totalFraction * constraints.maxHeight;

          return Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: barHeight,
              width: double.infinity,
              child: Column(
                children: [
                  for (var zoneIndex = 4; zoneIndex >= 0; zoneIndex--)
                    _zoneSegment(
                      zoneTime.asList[zoneIndex],
                      zoneTime.total,
                      _zoneColors[zoneIndex],
                      isActive: isActive,
                      isTop: zoneIndex == 4,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _zoneSegment(
    int seconds,
    int totalSeconds,
    Color color, {
    bool isActive = false,
    bool isTop = false,
  }) {
    if (seconds == 0 || totalSeconds == 0) return const SizedBox.shrink();
    return Flexible(
      flex: (seconds / totalSeconds * 1000).round(),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.75),
          borderRadius: isTop
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
          final barWidth =
              (constraints.maxWidth - barSpacing * (count - 1)) / count;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var weekIndex = 0; weekIndex < count; weekIndex++)
                if (weekIndex % labelStride == 0 ||
                    weeks[weekIndex].isCurrent)
                  Positioned(
                    left: weekIndex * (barWidth + barSpacing) +
                        barWidth / 2 -
                        20,
                    top: 0,
                    child: SizedBox(
                      width: 40,
                      child: Text(
                        weeks[weekIndex].label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          color: weeks[weekIndex].isCurrent
                              ? AppColors.accentPrimary
                              : AppColors.textColor4,
                          fontWeight: weeks[weekIndex].isCurrent
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

  double _barSpacing() => switch (weeks.length) {
    > 24 => 1.0,
    > 16 => 2.0,
    _ => 4.0,
  };

  List<int> _yearBoundaryIndices() {
    final indices = <int>[];
    for (var weekIndex = 1; weekIndex < weeks.length; weekIndex++) {
      if (weeks[weekIndex].weekStart.year !=
          weeks[weekIndex - 1].weekStart.year) {
        indices.add(weekIndex);
      }
    }
    return indices;
  }
}

class _ScrubDetailPanel extends StatelessWidget {
  const _ScrubDetailPanel({required this.week});

  final WeekZoneData? week;

  @override
  Widget build(BuildContext context) {
    if (week == null) return _emptyState();
    if (week!.zoneTime.total == 0) return _noDataState(week!);
    return _dataState(week!);
  }

  Widget _emptyState() {
    return Text(
      'Drag to inspect a week',
      style: AppTypography.caption.copyWith(color: AppColors.textColor4),
    );
  }

  Widget _noDataState(WeekZoneData week) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Week of ${week.label}',
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'No HR data — manual activity or HR not recorded.',
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
        ),
      ],
    );
  }

  Widget _dataState(WeekZoneData week) {
    final zoneTime = week.zoneTime;
    final totalSeconds = zoneTime.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _weekHeader(week, totalSeconds ~/ 60),
        const SizedBox(height: AppSpacing.xs),
        for (var zoneIndex = 0; zoneIndex < 5; zoneIndex++) ...[
          if (zoneIndex > 0) const SizedBox(height: 2),
          _zoneRow(
            _zoneNames[zoneIndex],
            _zoneColors[zoneIndex],
            _formatZoneRange(zoneIndex + 1),
            zoneTime[zoneIndex],
            totalSeconds,
          ),
        ],
      ],
    );
  }

  Widget _weekHeader(WeekZoneData week, int totalMinutes) {
    return Row(
      children: [
        Text(
          'Week of ${week.label}',
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '· Total zone time: ${_formatMinutes(totalMinutes)}',
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
        ),
      ],
    );
  }

  Widget _zoneRow(
    String label,
    Color color,
    String range,
    int seconds,
    int totalSeconds,
  ) {
    final fraction = totalSeconds > 0 ? seconds / totalSeconds : 0.0;
    final percent = (fraction * 100).round().clamp(0, 100);
    return Row(
      children: [
        _zoneLabel(label, range),
        Expanded(child: _fractionBar(color, fraction)),
        const SizedBox(width: AppSpacing.sm),
        _percentLabel(percent),
        const SizedBox(width: AppSpacing.sm),
        _minutesLabel(seconds ~/ 60),
      ],
    );
  }

  Widget _zoneLabel(String label, String range) {
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
          ),
          Text(
            range,
            style: const TextStyle(fontSize: 8, color: AppColors.textColor4),
          ),
        ],
      ),
    );
  }

  Widget _fractionBar(Color color, double fraction) {
    return Stack(
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.backgroundDepth4,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _percentLabel(int percent) {
    return SizedBox(
      width: 34,
      child: Text(
        '$percent%',
        textAlign: TextAlign.right,
        style: AppTypography.caption.copyWith(color: AppColors.textColor3),
      ),
    );
  }

  Widget _minutesLabel(int minutes) {
    return SizedBox(
      width: 40,
      child: Text(
        _formatMinutes(minutes),
        textAlign: TextAlign.right,
        style: AppTypography.caption.copyWith(color: AppColors.textColor4),
      ),
    );
  }
}

/// Data type for [PolarizationChart] — same as [WeekZoneData] for drop-in
/// replacement of [WeeklyStackedZoneChart].
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
