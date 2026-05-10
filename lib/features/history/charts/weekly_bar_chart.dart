import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';

class WeeklyBarChart extends StatefulWidget {
  const WeeklyBarChart({
    super.key,
    required this.title,
    required this.weeks,
    this.barColor,
    this.goalLine,
    this.valueSuffix = '',
    this.formatValue,
  });

  final String title;
  final List<WeekData> weeks;
  final Color? barColor;
  final ChartGoalLine? goalLine;
  final String valueSuffix;
  final String Function(double value)? formatValue;

  @override
  State<WeeklyBarChart> createState() => _WeeklyBarChartState();
}

class _WeeklyBarChartState extends State<WeeklyBarChart> {
  int? _activeIndex;

  List<WeekData> get weeks => widget.weeks;

  String _formatValue(double value) => widget.formatValue != null
      ? widget.formatValue!(value)
      : '${value.toStringAsFixed(1)}${widget.valueSuffix}';

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
          ],
        ),
      ),
    );
  }

  Widget _header() {
    if (weeks.isEmpty) {
      return Text(widget.title, style: AppTypography.subtitle);
    }

    final averageableWeeks = weeks
        .where((weekData) => weekData.includeInAverage)
        .toList();
    final total = averageableWeeks.fold(
      0.0,
      (sum, weekData) => sum + weekData.value,
    );
    final avg = averageableWeeks.isEmpty
        ? 0.0
        : total / averageableWeeks.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.title, style: AppTypography.subtitle),
        Text(
          'avg ${_formatValue(avg)}/wk',
          style: AppTypography.caption.copyWith(color: AppColors.textColor3),
        ),
      ],
    );
  }

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

    final highestWeekValue = weeks.fold(
      0.0,
      (maxSoFar, weekData) => math.max(maxSoFar, weekData.value),
    );
    final chartMax = _chartMaxValue(highestWeekValue);
    final color = widget.barColor ?? AppColors.accentPrimary;
    final barSpacing = _barSpacing();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            _barsRow(chartMax, color, barSpacing),
            if (widget.goalLine != null)
              _goalLine(widget.goalLine!, chartMax, constraints.maxHeight),
          ],
        );
      },
    );
  }

  double _chartMaxValue(double highestWeekValue) {
    final goalLine = widget.goalLine;
    final baselineMax = highestWeekValue > 0 ? highestWeekValue : 1.0;
    if (goalLine == null) return baselineMax;
    return math.max(baselineMax, goalLine.target * 1.15);
  }

  Widget _barsRow(double maxValue, Color color, double barSpacing) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var weekIndex = 0; weekIndex < weeks.length; weekIndex++) ...[
          if (weekIndex > 0) SizedBox(width: barSpacing),
          Expanded(child: _interactiveBar(weekIndex, maxValue, color)),
        ],
      ],
    );
  }

  Widget _goalLine(
    ChartGoalLine goalLine,
    double maxValue,
    double chartHeight,
  ) {
    final referenceFraction = (goalLine.target / maxValue).clamp(0.0, 1.0);
    return Positioned(
      left: 0,
      right: 0,
      bottom: referenceFraction * chartHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            goalLine.label,
            style: TextStyle(
              fontSize: 8,
              color: goalLine.color.withValues(alpha: 0.6),
            ),
          ),
          Container(height: 1, color: goalLine.color.withValues(alpha: 0.35)),
        ],
      ),
    );
  }

  Widget _interactiveBar(int index, double maxValue, Color color) {
    final WeekData week = weeks[index];
    final double fraction = (week.value / maxValue).clamp(0.0, 1.0);
    final double barFraction = fraction == 0 ? 0.0 : math.max(fraction, 0.04);
    final bool isActive = _activeIndex == index;

    return MouseRegion(
      onEnter: (_) => setState(() => _activeIndex = index),
      onExit: (_) => setState(() => _activeIndex = null),
      child: GestureDetector(
        onTapDown: (_) =>
            setState(() => _activeIndex = _activeIndex == index ? null : index),
        behavior: HitTestBehavior.opaque,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double barHeight = barFraction * constraints.maxHeight;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: barHeight,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: isActive
                                  ? color
                                  : color.withValues(
                                      alpha: 0.3 + fraction * 0.6,
                                    ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        if (week.accentColors.isNotEmpty)
                          _accentColorRug(week.accentColors, isActive),
                      ],
                    ),
                  ),
                ),
                if (isActive && week.value > 0)
                  Positioned(
                    bottom: barHeight + 2,
                    left: -12,
                    right: -12,
                    child: Text(
                      _formatValue(week.value),
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

  Widget _accentColorRug(List<Color> accentColors, bool isActive) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Row(
        children: [
          for (final accentColor in accentColors)
            Expanded(
              child: Container(
                height: 3,
                color: accentColor.withValues(alpha: isActive ? 1.0 : 0.75),
              ),
            ),
        ],
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
              for (var weekIndex = 0; weekIndex < count; weekIndex++)
                if (weekIndex % labelStride == 0 || weeks[weekIndex].isCurrent)
                  Positioned(
                    left:
                        weekIndex * (barWidth + barSpacing) + barWidth / 2 - 20,
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
}

class ChartGoalLine {
  const ChartGoalLine({
    required this.target,
    required this.label,
    required this.color,
  });

  final double target;
  final String label;
  final Color color;
}

class WeekData {
  const WeekData({
    required this.label,
    required this.value,
    required this.weekStart,
    this.accentColors = const [],
    this.isCurrent = false,
    this.includeInAverage = true,
  });

  final String label;
  final double value;
  final DateTime weekStart;
  final List<Color> accentColors;
  final bool isCurrent;
  final bool includeInAverage;
}
