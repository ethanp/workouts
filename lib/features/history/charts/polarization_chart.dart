import 'dart:math' as math;

import 'package:ethan_ui/ethan_ui.dart';

import 'package:flutter/material.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/features/history/charts/chart_inspect_expander.dart';
import 'package:workouts/features/history/charts/polarization_legend.dart';
import 'package:workouts/features/history/charts/polarization_minute_axis.dart';
import 'package:workouts/features/history/charts/polarization_scrub_detail_panel.dart';
import 'package:workouts/features/history/charts/week_zone_data.dart';
import 'package:workouts/theme/goal_priority_palette.dart';
import 'package:workouts/theme/hr_zone_palette.dart';

const _kAerobicBaseTargetSeconds = 90 * 60; // 90 min/week aerobic base target
const _kPriorityTwoTargetSeconds = 150 * 60; // 150 min/week priority 2 target

/// Stacked weekly bar chart showing time in each of the 5 HR zones.
///
/// Bar height encodes total zone volume; color segments encode zone split.
/// Both are simultaneously visible, so a polarized week (lots of blue/green
/// and red, little amber) is visually distinct from a gray-zone-heavy week.
///
/// Expand Inspect to pin a week — the latest visible week starts selected —
/// then tap or drag the bars to move it.
class const PolarizationChart({
  required final List<WeekZoneData> weeks,
  final Widget? rangeScrubber,
}) extends StatefulWidget {
  @override
  State<PolarizationChart> createState() => _PolarizationChartState();
}

class _PolarizationChartState() extends State<PolarizationChart> {
  bool _inspecting = false;
  int? _scrubIndex;

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
          _barsSection(),
          const SizedBox(height: ELayout.spaceSm),
          Padding(
            padding: const EdgeInsets.only(left: PolarizationMinuteAxis.width),
            child: _labels(),
          ),
          ..._rangeScrubber(),
          const SizedBox(height: ELayout.spaceSm),
          _inspectExpander(),
        ],
      ),
    );
  }

  Widget _inspectExpander() {
    final int? weekIndex = _shownWeekIndex();
    return ChartInspectExpander(
      isExpanded: _inspecting,
      onToggle: _toggleInspecting,
      detail: weekIndex == null
          ? null
          : PolarizationScrubDetailPanel(week: widget.weeks[weekIndex]),
    );
  }

  void _toggleInspecting() {
    setState(() {
      _inspecting = !_inspecting;
      _scrubIndex = _inspecting ? _lastWeekIndex() : null;
    });
  }

  int? _lastWeekIndex() {
    if (widget.weeks.isEmpty) return null;
    return widget.weeks.length - 1;
  }

  int? _shownWeekIndex() {
    if (!_inspecting || widget.weeks.isEmpty) return null;
    final int? scrubIndex = _scrubIndex;
    if (scrubIndex == null ||
        scrubIndex < 0 ||
        scrubIndex >= widget.weeks.length) {
      return widget.weeks.length - 1;
    }
    return scrubIndex;
  }

  List<Widget> _rangeScrubber() {
    if (widget.rangeScrubber == null) return const [];
    return [const SizedBox(height: ELayout.spaceSm), widget.rangeScrubber!];
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Polarization', style: EText.section),
        const SizedBox(width: ELayout.spaceSm),
        Expanded(child: PolarizationLegend()),
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

  EChartValueScale _minuteScale() {
    var peakSeconds = 0;
    for (final week in widget.weeks) {
      if (week.zoneTime.total > peakSeconds) peakSeconds = week.zoneTime.total;
    }
    return EChartValueScale.clockMinutes(
      math.max(peakSeconds / 60, _kPriorityTwoTargetSeconds / 60),
    );
  }

  Widget _barsArea() {
    final minuteScale = _minuteScale();
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            PolarizationMinuteAxis(scale: minuteScale),
            Expanded(
              child: DecoratedBox(
                decoration: _barsAreaDecoration(),
                child: SizedBox(
                  height: PolarizationMinuteAxis.plotHeight,
                  child: _barsWithScrub(minuteScale),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  BoxDecoration _barsAreaDecoration() {
    return BoxDecoration(
      border: Border(
        bottom: BorderSide(color: EColors.textMuted.withValues(alpha: 0.4)),
      ),
    );
  }

  Widget _barsAreaWithYearBoundaries(
    BoxConstraints constraints,
    List<int> yearBoundaryIndices,
  ) {
    final barSpacing = _barSpacing();
    final plotWidth = constraints.maxWidth - PolarizationMinuteAxis.width;
    final barWidth = _chartBarWidth(plotWidth, barSpacing);
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
        color: EColors.textMuted.withValues(alpha: 0.3),
      ),
    );
  }

  double _yearBoundaryLeft(
    int boundaryIndex,
    double barWidth,
    double barSpacing,
  ) =>
      PolarizationMinuteAxis.width +
      boundaryIndex * (barWidth + barSpacing) -
      barSpacing / 2;

  Widget _barsWithScrub(EChartValueScale minuteScale) {
    if (widget.weeks.isEmpty) {
      return Center(child: Text('No data yet', style: EText.caption));
    }

    final zoneTimes = widget.weeks.map((week) => week.zoneTime).toList();
    final scaleMaxSeconds = minuteScale.max * 60;
    final barSpacing = _barSpacing();
    final aerobicBaseFraction = _kAerobicBaseTargetSeconds / scaleMaxSeconds;
    final priorityTwoFraction = _kPriorityTwoTargetSeconds / scaleMaxSeconds;

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth =
            (constraints.maxWidth - barSpacing * (widget.weeks.length - 1)) /
            widget.weeks.length;

        return GestureDetector(
          onTapDown: _inspecting
              ? (details) => _scrubWeekUnderFinger(
                  details.localPosition.dx,
                  barWidth,
                  barSpacing,
                  widget.weeks.length,
                )
              : null,
          onHorizontalDragStart: _inspecting
              ? (details) => _scrubWeekUnderFinger(
                  details.localPosition.dx,
                  barWidth,
                  barSpacing,
                  widget.weeks.length,
                )
              : null,
          onHorizontalDragUpdate: _inspecting
              ? (details) => _scrubWeekUnderFinger(
                  details.localPosition.dx,
                  barWidth,
                  barSpacing,
                  widget.weeks.length,
                )
              : null,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              ..._minuteGridLines(minuteScale, constraints.maxHeight),
              _barsRow(zoneTimes, scaleMaxSeconds, barSpacing),
              if (aerobicBaseFraction <= 1.0)
                _weeklyMinuteGoal(
                  aerobicBaseFraction,
                  constraints.maxHeight,
                  '90m aerobic base',
                  HrZonePalette.zone2,
                ),
              if (priorityTwoFraction <= 1.0)
                _weeklyMinuteGoal(
                  priorityTwoFraction,
                  constraints.maxHeight,
                  '150m priority 2',
                  GoalPriorityPalette.priority2,
                ),
              if (_shownWeekIndex() != null) _scrubCursor(barWidth, barSpacing),
            ],
          ),
        );
      },
    );
  }

  Widget _barsRow(
    List<HrZoneTime> zoneTimes,
    double scaleMaxSeconds,
    double barSpacing,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (
          var weekIndex = 0;
          weekIndex < widget.weeks.length;
          weekIndex++
        ) ...[
          if (weekIndex > 0) SizedBox(width: barSpacing),
          Expanded(
            child: _stackedBar(
              zoneTimes[weekIndex],
              scaleMaxSeconds,
              weekIndex,
            ),
          ),
        ],
      ],
    );
  }

  Widget _weeklyMinuteGoal(
    double referenceFraction,
    double chartHeight,
    String label,
    Color color,
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
            style: TextStyle(fontSize: 8, color: color.withValues(alpha: 0.6)),
          ),
          Container(height: 1, color: color.withValues(alpha: 0.35)),
        ],
      ),
    );
  }

  Widget _scrubCursor(double barWidth, double barSpacing) {
    final int? weekIndex = _shownWeekIndex();
    if (weekIndex == null) return const SizedBox.shrink();
    return Positioned(
      left: weekIndex * (barWidth + barSpacing) + barWidth / 2,
      top: 0,
      bottom: 0,
      child: Container(
        width: 1,
        color: EColors.textTertiary.withValues(alpha: 0.6),
      ),
    );
  }

  void _scrubWeekUnderFinger(
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
    double scaleMaxSeconds,
    int weekIndex,
  ) {
    final isActive = _shownWeekIndex() == weekIndex;

    return MouseRegion(
      onEnter: (_) {
        if (!_inspecting) return;
        setState(() => _scrubIndex = weekIndex);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (zoneTime.total == 0) return const SizedBox.expand();

          final totalFraction = (zoneTime.total / scaleMaxSeconds).clamp(
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
    final barWidth = _chartBarWidth(constraints.maxWidth, barSpacing);
    return Stack(
      clipBehavior: Clip.none,
      children: _weekLabels(barWidth, barSpacing),
    );
  }

  List<Widget> _minuteGridLines(
    EChartValueScale minuteScale,
    double plotHeight,
  ) {
    return [
      for (final tick in minuteScale.ticks)
        if (tick > 0 && tick < minuteScale.max)
          Positioned(
            left: 0,
            right: 0,
            bottom: minuteScale.fractionFromBottom(tick) * plotHeight,
            child: Container(
              height: 1,
              color: EColors.border.withValues(alpha: 0.4),
            ),
          ),
    ];
  }

  double _chartBarWidth(double plotWidth, double barSpacing) {
    final weekCount = widget.weeks.length;
    if (weekCount == 0) return 0;
    return (plotWidth - barSpacing * (weekCount - 1)) / weekCount;
  }

  List<Widget> _weekLabels(double barWidth, double barSpacing) {
    final weekLabels = <Widget>[];
    for (var weekIndex = 0; weekIndex < widget.weeks.length; weekIndex++) {
      if (!_showsWeekLabel(weekIndex)) continue;
      weekLabels.add(_positionedWeekLabel(weekIndex, barWidth, barSpacing));
    }
    return weekLabels;
  }

  bool _showsWeekLabel(int weekIndex) =>
      weekIndex % _labelStride() == 0 || widget.weeks[weekIndex].isCurrent;

  int _labelStride() => switch (widget.weeks.length) {
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
    final week = widget.weeks[weekIndex];
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
      color: week.isCurrent ? EColors.accent : EColors.textMuted,
      fontWeight: week.isCurrent ? FontWeight.w600 : FontWeight.normal,
    );
  }

  double _barSpacing() => switch (widget.weeks.length) {
    > 24 => 1.0,
    > 16 => 2.0,
    _ => 4.0,
  };

  List<int> _yearBoundaryIndices() {
    final indices = <int>[];
    for (var weekIndex = 1; weekIndex < widget.weeks.length; weekIndex++) {
      if (widget.weeks[weekIndex].weekStart.year !=
          widget.weeks[weekIndex - 1].weekStart.year) {
        indices.add(weekIndex);
      }
    }
    return indices;
  }
}
