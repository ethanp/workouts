import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';

class WeeklyBarChart extends StatefulWidget {
  const WeeklyBarChart({
    super.key,
    required this.title,
    required this.weeks,
    this.barColor,
    this.valueSuffix = '',
    this.formatValue,
  });

  final String title;
  final List<WeekData> weeks;
  final Color? barColor;
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

    final averageable = weeks.where((w) => w.includeInAverage).toList();
    final total = averageable.fold(0.0, (sum, w) => sum + w.value);
    final avg = averageable.isEmpty ? 0.0 : total / averageable.length;

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

    final maxValue = weeks.fold(0.0, (m, w) => math.max(m, w.value));
    final effectiveMax = maxValue > 0 ? maxValue : 1.0;
    final color = widget.barColor ?? AppColors.accentPrimary;
    final barSpacing = _barSpacing();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < weeks.length; i++) ...[
          if (i > 0) SizedBox(width: barSpacing),
          Expanded(
            child: _interactiveBar(i, effectiveMax, color),
          ),
        ],
      ],
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
        onTapDown: (_) => setState(
          () => _activeIndex = _activeIndex == index ? null : index,
        ),
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
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isActive
                            ? color
                            : color.withValues(alpha: 0.3 + fraction * 0.6),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
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

  Widget _labels() {
    final count = weeks.length;
    final (labelStride, barSpacing) = switch (count) {
      > 40 => (8, 1.0),
      > 24 => (4, 1.0),
      > 16 => (2, 2.0),
      _    => (1, 4.0),
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

class WeekData {
  const WeekData({
    required this.label,
    required this.value,
    required this.weekStart,
    this.isCurrent = false,
    this.includeInAverage = true,
  });

  final String label;
  final double value;
  final DateTime weekStart;
  final bool isCurrent;
  final bool includeInAverage;
}
