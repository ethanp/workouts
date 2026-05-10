import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/features/history/charts/polarization_legend.dart';
import 'package:workouts/features/history/charts/polarization_scrub_detail_panel.dart';
import 'package:workouts/features/history/charts/week_zone_data.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/theme/hr_zone_palette.dart';

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
            PolarizationScrubDetailPanel(
              week: _scrubIndex != null ? weeks[_scrubIndex!] : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text('Polarization', style: AppTypography.subtitle)),
        PolarizationLegend(
          isExpanded: _legendExpanded,
          onToggle: () => setState(() => _legendExpanded = !_legendExpanded),
        ),
      ],
    );
  }

  Widget _barsSection() {
    final yearBoundaryIndices = _yearBoundaryIndices();
    if (yearBoundaryIndices.isEmpty) return _barsArea();
    return LayoutBuilder(
      builder: (context, constraints) =>
          _barsAreaWithYearBoundaries(constraints, yearBoundaryIndices),
    );
  }

  Widget _barsArea() {
    return Column(
      children: [
        DecoratedBox(
          decoration: _barsAreaDecoration(),
          child: SizedBox(height: 140, child: _barsWithScrub()),
        ),
      ],
    );
  }

  BoxDecoration _barsAreaDecoration() {
    return BoxDecoration(
      border: Border(
        bottom: BorderSide(color: AppColors.textColor4.withValues(alpha: 0.4)),
      ),
    );
  }

  Widget _barsAreaWithYearBoundaries(
    BoxConstraints constraints,
    List<int> yearBoundaryIndices,
  ) {
    final barSpacing = _barSpacing();
    final barWidth = _chartBarWidth(constraints, barSpacing);
    return Stack(
      children: [
        _barsArea(),
        for (final boundaryIndex in yearBoundaryIndices)
          _yearBoundaryLine(boundaryIndex, barWidth, barSpacing),
      ],
    );
  }

  Widget _yearBoundaryLine(
    int boundaryIndex,
    double barWidth,
    double barSpacing,
  ) {
    return Positioned(
      left: _yearBoundaryLeft(boundaryIndex, barWidth, barSpacing),
      top: 0,
      bottom: 0,
      child: Container(
        width: 1,
        color: AppColors.textColor4.withValues(alpha: 0.3),
      ),
    );
  }

  double _yearBoundaryLeft(
    int boundaryIndex,
    double barWidth,
    double barSpacing,
  ) => boundaryIndex * (barWidth + barSpacing) - barSpacing / 2;

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
              if (_scrubIndex != null) _scrubCursor(barWidth, barSpacing),
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

  Widget _referenceLine(
    double referenceFraction,
    double chartHeight,
    String label,
  ) {
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
              color: HrZonePalette.zone2.withValues(alpha: 0.6),
            ),
          ),
          Container(
            height: 1,
            color: HrZonePalette.zone2.withValues(alpha: 0.35),
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

  Widget _stackedBar(HrZoneTime zoneTime, int maxTotalSeconds, int weekIndex) {
    final isActive = _scrubIndex == weekIndex;

    return MouseRegion(
      onEnter: (_) => setState(() => _scrubIndex = weekIndex),
      onExit: (_) {
        if (_scrubIndex == weekIndex) setState(() => _scrubIndex = null);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (zoneTime.total == 0) return const SizedBox.expand();

          final totalFraction = (zoneTime.total / maxTotalSeconds).clamp(
            0.0,
            1.0,
          );
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
                      HrZonePalette.zoneColors[zoneIndex],
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
    return SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, constraints) => _labelStack(constraints),
      ),
    );
  }

  Widget _labelStack(BoxConstraints constraints) {
    final barSpacing = _barSpacing();
    final barWidth = _chartBarWidth(constraints, barSpacing);
    return Stack(
      clipBehavior: Clip.none,
      children: _weekLabels(barWidth, barSpacing),
    );
  }

  double _chartBarWidth(BoxConstraints constraints, double barSpacing) {
    final weekCount = weeks.length;
    return (constraints.maxWidth - barSpacing * (weekCount - 1)) / weekCount;
  }

  List<Widget> _weekLabels(double barWidth, double barSpacing) {
    final weekLabels = <Widget>[];
    for (var weekIndex = 0; weekIndex < weeks.length; weekIndex++) {
      if (!_showsWeekLabel(weekIndex)) continue;
      weekLabels.add(_positionedWeekLabel(weekIndex, barWidth, barSpacing));
    }
    return weekLabels;
  }

  bool _showsWeekLabel(int weekIndex) =>
      weekIndex % _labelStride() == 0 || weeks[weekIndex].isCurrent;

  int _labelStride() => switch (weeks.length) {
    > 40 => 8,
    > 24 => 4,
    > 16 => 2,
    _ => 1,
  };

  Widget _positionedWeekLabel(
    int weekIndex,
    double barWidth,
    double barSpacing,
  ) {
    final week = weeks[weekIndex];
    return Positioned(
      left: _weekLabelLeft(weekIndex, barWidth, barSpacing),
      top: 0,
      child: SizedBox(width: 40, child: _weekLabelText(week)),
    );
  }

  double _weekLabelLeft(int weekIndex, double barWidth, double barSpacing) =>
      weekIndex * (barWidth + barSpacing) + barWidth / 2 - 20;

  Widget _weekLabelText(WeekZoneData week) {
    return Text(
      week.label,
      textAlign: TextAlign.center,
      style: _weekLabelStyle(week),
      maxLines: 1,
    );
  }

  TextStyle _weekLabelStyle(WeekZoneData week) {
    return TextStyle(
      fontSize: 9,
      color: week.isCurrent ? AppColors.accentPrimary : AppColors.textColor4,
      fontWeight: week.isCurrent ? FontWeight.w600 : FontWeight.normal,
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
