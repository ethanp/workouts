import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/models/polarization_week.dart';
import 'package:workouts/theme/app_theme.dart';

const _aerobicColor = Color(0xFF3FB37F); // teal-green — Z1+Z2
const _grayZoneColor = Color(0xFFF0B347); // amber — Z3
const _vo2maxColor = Color(0xFFE15A64); // red-orange — Z4+Z5

/// Replaces [WeeklyStackedZoneChart] with three functional buckets relevant to
/// longevity: Aerobic Base (Z1+Z2), Gray Zone (Z3), VO₂max Stimulus (Z4+Z5).
///
/// Bar height encodes volume; color proportions encode quality. Both dimensions
/// are simultaneously visible, so a low-volume well-polarized week is visually
/// distinct from a high-volume Z3-heavy week.
///
/// Horizontal drag activates a scrub cursor and live readout panel — the Brett
/// Victor "feel the data" paradigm.
class PolarizationChart extends StatefulWidget {
  const PolarizationChart({super.key, required this.weeks});

  final List<WeekZoneData> weeks;

  @override
  State<PolarizationChart> createState() => _PolarizationChartState();
}

class _PolarizationChartState extends State<PolarizationChart> {
  int? _scrubIndex;

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
    return Row(
      children: [
        Expanded(
          child: Text('Polarization', style: AppTypography.subtitle),
        ),
        _legend(),
      ],
    );
  }

  Widget _legend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendDot(_aerobicColor, 'Base'),
        const SizedBox(width: AppSpacing.sm),
        _legendDot(_grayZoneColor, 'Gray'),
        const SizedBox(width: AppSpacing.sm),
        _legendDot(_vo2maxColor, 'VO₂max'),
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
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textColor4),
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

    final polarizationWeeks = weeks
        .map((week) => PolarizationWeek.fromHrZoneTime(week.zoneTime))
        .toList();

    final maxTotal = polarizationWeeks.fold(
      0,
      (maxSoFar, week) => math.max(maxSoFar, week.totalZoneSeconds),
    );
    final effectiveMax = maxTotal > 0 ? maxTotal : 1;
    final maxAerobicBase = polarizationWeeks.fold(
      0,
      (maxSoFar, week) => math.max(maxSoFar, week.aerobicBaseSeconds),
    );
    final barSpacing = _barSpacing();

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth =
            (constraints.maxWidth - barSpacing * (weeks.length - 1)) /
            weeks.length;
        final referenceFraction =
            maxAerobicBase > 0 ? (maxAerobicBase * 0.8) / effectiveMax : null;

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
              _barsRow(polarizationWeeks, effectiveMax, barSpacing),
              if (referenceFraction != null)
                _referenceLine(referenceFraction, constraints.maxHeight),
              if (_scrubIndex != null)
                _scrubCursor(barWidth, barSpacing),
            ],
          ),
        );
      },
    );
  }

  Widget _barsRow(
    List<PolarizationWeek> polarizationWeeks,
    int effectiveMax,
    double barSpacing,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var weekIndex = 0; weekIndex < weeks.length; weekIndex++) ...[
          if (weekIndex > 0) SizedBox(width: barSpacing),
          Expanded(
            child: _stackedBar(
              polarizationWeeks[weekIndex],
              effectiveMax,
              weekIndex,
            ),
          ),
        ],
      ],
    );
  }

  Widget _referenceLine(double referenceFraction, double chartHeight) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: referenceFraction * chartHeight,
      child: Container(
        height: 1,
        color: _aerobicColor.withValues(alpha: 0.35),
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
    PolarizationWeek week,
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
          if (!week.hasData) {
            return const SizedBox.expand();
          }

          final totalFraction =
              (week.totalZoneSeconds / maxTotalSeconds).clamp(0.0, 1.0);
          final barHeight = totalFraction * constraints.maxHeight;

          return Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: barHeight,
              width: double.infinity,
              child: Column(
                children: [
                  _bucketSegment(
                    week.vo2maxSeconds,
                    week.totalZoneSeconds,
                    _vo2maxColor,
                    isActive: isActive,
                    isTop: true,
                  ),
                  _bucketSegment(
                    week.grayZoneSeconds,
                    week.totalZoneSeconds,
                    _grayZoneColor,
                    isActive: isActive,
                  ),
                  _bucketSegment(
                    week.aerobicBaseSeconds,
                    week.totalZoneSeconds,
                    _aerobicColor,
                    isActive: isActive,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _bucketSegment(
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
    final polarization = PolarizationWeek.fromHrZoneTime(week!.zoneTime);
    if (!polarization.hasData) return _noDataState(week!);
    return _dataState(week!, polarization);
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

  Widget _dataState(WeekZoneData week, PolarizationWeek polarization) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
              '· Total zone time: ${_formatMinutes(polarization.totalZoneMinutes)}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor4,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _bucketRow(
          'Aerobic Base',
          _aerobicColor,
          polarization.aerobicFraction,
          polarization.aerobicBaseMinutes,
        ),
        const SizedBox(height: 2),
        _bucketRow(
          'Gray Zone',
          _grayZoneColor,
          polarization.grayFraction,
          polarization.grayZoneMinutes,
        ),
        const SizedBox(height: 2),
        _bucketRow(
          'VO₂max',
          _vo2maxColor,
          polarization.vo2maxFraction,
          polarization.vo2maxMinutes,
        ),
      ],
    );
  }

  Widget _bucketRow(
    String label,
    Color color,
    double fraction,
    int minutes,
  ) {
    final barFlex = (fraction * 100).round().clamp(0, 100);
    return Row(
      children: [
        _bucketLabel(label),
        Expanded(child: _bucketFractionBar(color, fraction)),
        const SizedBox(width: AppSpacing.sm),
        _bucketPercentLabel(barFlex),
        const SizedBox(width: AppSpacing.sm),
        _bucketMinutesLabel(minutes),
      ],
    );
  }

  Widget _bucketLabel(String label) {
    return SizedBox(
      width: 80,
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: AppColors.textColor3),
      ),
    );
  }

  Widget _bucketFractionBar(Color color, double fraction) {
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

  Widget _bucketPercentLabel(int percent) {
    return SizedBox(
      width: 34,
      child: Text(
        '$percent%',
        textAlign: TextAlign.right,
        style: AppTypography.caption.copyWith(color: AppColors.textColor3),
      ),
    );
  }

  Widget _bucketMinutesLabel(int minutes) {
    return SizedBox(
      width: 40,
      child: Text(
        _formatMinutes(minutes),
        textAlign: TextAlign.right,
        style: AppTypography.caption.copyWith(color: AppColors.textColor4),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
    return '${minutes}m';
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
