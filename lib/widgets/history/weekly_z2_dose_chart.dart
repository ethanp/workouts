import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/history/polarization_chart.dart';

/// Shows weekly Zone 2 minutes against a user-owned draggable target line.
///
/// The target line is Victor-style direct manipulation: dragging it up or down
/// updates the target in real time, persisting to SharedPreferences. Bar colors
/// flip green/gray against the current target as you drag.
class WeeklyZ2DoseChart extends ConsumerStatefulWidget {
  const WeeklyZ2DoseChart({super.key, required this.weeks});

  final List<WeekZoneData> weeks;

  @override
  ConsumerState<WeeklyZ2DoseChart> createState() =>
      _WeeklyZ2DoseChartState();
}

class _WeeklyZ2DoseChartState extends ConsumerState<WeeklyZ2DoseChart> {
  // Local target override during a drag; null means use the persisted value.
  int? _dragTargetMinutes;
  double? _chartHeight;

  static const double _kChartHeight = 120;
  static const double _kMinTarget = 30;
  static const double _kMaxTarget = 600;
  static const double _kHandleRadius = 6.0;
  static const double _kHandleAreaWidth = 40.0;

  @override
  Widget build(BuildContext context) {
    final persistedTarget =
        ref.watch(weeklyZ2TargetMinutesProvider);
    final displayTarget = _dragTargetMinutes ?? persistedTarget;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(displayTarget),
          const SizedBox(height: AppSpacing.md),
          _chartArea(displayTarget),
          const SizedBox(height: AppSpacing.sm),
          _labels(),
        ],
      ),
    );
  }

  Widget _header(int targetMinutes) {
    return Row(
      children: [
        Expanded(
          child: Text('Weekly Zone 2', style: AppTypography.subtitle),
        ),
        Text(
          _formatMinutes(targetMinutes),
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor4,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          'target',
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
        ),
      ],
    );
  }

  Widget _chartArea(int targetMinutes) {
    final weeks = widget.weeks;
    if (weeks.isEmpty) {
      return const SizedBox(
        height: _kChartHeight,
        child: Center(child: Text('No data yet', style: AppTypography.caption)),
      );
    }

    final z2Minutes = weeks.map((week) => week.zoneTime.zone2Minutes).toList();
    final maxZ2 = z2Minutes.fold(0, math.max);
    final yMax = math.max(maxZ2.toDouble(), targetMinutes * 1.2);
    final rollingAvg = _rollingAverage(z2Minutes, 8);

    return LayoutBuilder(
      builder: (context, constraints) {
        _chartHeight = _kChartHeight;
        final chartWidth = constraints.maxWidth;
        final count = weeks.length;
        final barSpacing = count > 16 ? 2.0 : 4.0;
        final barWidth = (chartWidth - barSpacing * (count - 1)) / count;
        final targetFraction = (targetMinutes / yMax).clamp(0.0, 1.0);
        final targetY = _kChartHeight * (1 - targetFraction);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            _barsRow(z2Minutes, yMax, targetMinutes, count, barSpacing),
            _rollingAverageOverlay(rollingAvg, yMax, barWidth, barSpacing, chartWidth),
            _targetLine(
              targetY: targetY,
              chartWidth: chartWidth,
              targetMinutes: targetMinutes,
              yMax: yMax,
            ),
          ],
        );
      },
    );
  }

  Widget _barsRow(
    List<int> z2Minutes,
    double yMax,
    int targetMinutes,
    int count,
    double barSpacing,
  ) {
    return SizedBox(
      height: _kChartHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var weekIndex = 0; weekIndex < count; weekIndex++) ...[
            if (weekIndex > 0) SizedBox(width: barSpacing),
            Expanded(
              child: _bar(
                z2Minutes[weekIndex],
                yMax,
                targetMinutes,
                widget.weeks[weekIndex].isCurrent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rollingAverageOverlay(
    List<double?> rollingAvg,
    double yMax,
    double barWidth,
    double barSpacing,
    double chartWidth,
  ) {
    return CustomPaint(
      size: Size(chartWidth, _kChartHeight),
      painter: _RollingAveragePainter(
        values: rollingAvg,
        maxY: yMax,
        barWidth: barWidth,
        barSpacing: barSpacing,
      ),
    );
  }

  Widget _bar(
    int z2Minutes,
    double yMax,
    int targetMinutes,
    bool isCurrent,
  ) {
    if (z2Minutes == 0) return const SizedBox.expand();
    final fraction = (z2Minutes / yMax).clamp(0.0, 1.0);
    final metTarget = z2Minutes >= targetMinutes;
    final barColor = metTarget ? AppColors.success : AppColors.textColor4;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: fraction * constraints.maxHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isCurrent
                  ? barColor
                  : barColor.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _targetLine({
    required double targetY,
    required double chartWidth,
    required int targetMinutes,
    required double yMax,
  }) {
    return Positioned(
      top: targetY - 1,
      left: 0,
      right: 0,
      child: GestureDetector(
        onVerticalDragUpdate: (details) => _onTargetDrag(details, yMax),
        onVerticalDragEnd: (_) => _commitTargetDrag(),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: _kHandleRadius * 2 + 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _targetLineStem(),
              _targetLineHandle(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _targetLineStem() {
    return Positioned(
      top: _kHandleRadius,
      left: 0,
      right: _kHandleAreaWidth,
      child: Container(
        height: 1,
        color: AppColors.success.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _targetLineHandle() {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        width: _kHandleRadius * 2,
        height: _kHandleRadius * 2,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  void _onTargetDrag(DragUpdateDetails details, double yMax) {
    final chartHeight = _chartHeight ?? _kChartHeight;
    final int currentTarget =
        _dragTargetMinutes ?? ref.read(weeklyZ2TargetMinutesProvider);
    final deltaFraction = -details.delta.dy / chartHeight;
    final deltaMinutes = (deltaFraction * yMax).round();
    final newTarget = (currentTarget + deltaMinutes).clamp(
      _kMinTarget.toInt(),
      _kMaxTarget.toInt(),
    );
    if (newTarget != _dragTargetMinutes) {
      setState(() => _dragTargetMinutes = newTarget);
    }
  }

  Future<void> _commitTargetDrag() async {
    final newTarget = _dragTargetMinutes;
    setState(() => _dragTargetMinutes = null);
    if (newTarget != null) {
      await ref
          .read(weeklyZ2TargetMinutesProvider.notifier)
          .setTarget(newTarget);
    }
  }

  Widget _labels() {
    final weeks = widget.weeks;
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
                if (weekIndex % labelStride == 0 || weeks[weekIndex].isCurrent)
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

  List<double?> _rollingAverage(List<int> values, int window) {
    return List.generate(values.length, (index) {
      final start = math.max(0, index - window + 1);
      final slice = values.sublist(start, index + 1);
      if (slice.isEmpty) return null;
      return slice.reduce((a, b) => a + b) / slice.length;
    });
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

class _RollingAveragePainter extends CustomPainter {
  _RollingAveragePainter({
    required this.values,
    required this.maxY,
    required this.barWidth,
    required this.barSpacing,
  });

  final List<double?> values;
  final double maxY;
  final double barWidth;
  final double barSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final pathPoints = _buildPathPoints(size);
    if (pathPoints.length < 2) return;

    final continuousPath = _buildContinuousPath(pathPoints);
    final dashedPath = _buildDashedPath(continuousPath);

    final paint = Paint()
      ..color = AppColors.textColor4.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(dashedPath, paint);
  }

  List<Offset> _buildPathPoints(Size size) {
    final pathPoints = <Offset>[];
    for (var weekIndex = 0; weekIndex < values.length; weekIndex++) {
      final averageValue = values[weekIndex];
      if (averageValue == null) continue;
      final barCenterX = weekIndex * (barWidth + barSpacing) + barWidth / 2;
      final yFraction = (averageValue / maxY).clamp(0.0, 1.0);
      pathPoints.add(Offset(barCenterX, size.height * (1 - yFraction)));
    }
    return pathPoints;
  }

  Path _buildContinuousPath(List<Offset> pathPoints) {
    final path = Path()..moveTo(pathPoints.first.dx, pathPoints.first.dy);
    for (final point in pathPoints.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path;
  }

  ui.Path _buildDashedPath(Path continuousPath) {
    const dashLength = 4.0;
    const gapLength = 3.0;

    final dashedPath = ui.Path();
    var distance = 0.0;
    var drawing = true;

    for (final metric in continuousPath.computeMetrics()) {
      while (distance < metric.length) {
        final segmentLength = drawing ? dashLength : gapLength;
        final end = math.min(distance + segmentLength, metric.length);
        if (drawing) {
          dashedPath.addPath(metric.extractPath(distance, end), Offset.zero);
        }
        distance += segmentLength;
        drawing = !drawing;
      }
    }
    return dashedPath;
  }

  @override
  bool shouldRepaint(_RollingAveragePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.maxY != maxY;
}
