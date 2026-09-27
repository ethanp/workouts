import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:workouts/features/history/charts/chart_inspect_expander.dart';
import 'package:workouts/features/history/charts/rolling_daily_painter.dart';
import 'package:workouts/features/history/charts/rolling_daily_point.dart';

/// A smoothed trailing-7-day line chart with goal reference lines. Expand
/// Inspect to pin a day — the latest visible day starts selected — then tap
/// or drag the plot to move it.
class const RollingDailyChart({
  required final String title,
  required final List<RollingDailyPoint> points,
  required final List<RollingDailyGoal> goals,
  required final Color lineColor,
  required final String Function(double value) formatValue,
  final String summarySuffix = '',
  final String emptySummaryLabel = 'No data yet',
  final bool showGoalDailyPace = false,
  final DateTime? displayStart,
  final DateTime? displayEnd,
  final Widget? rangeScrubber,
  final bool clockMinuteAxis = false,
}) extends StatefulWidget {
  @override
  State<RollingDailyChart> createState() => _RollingDailyChartState();
}

class _RollingDailyChartState() extends State<RollingDailyChart> {
  bool _inspecting = false;
  DateTime? _inspectedDate;

  @override
  Widget build(BuildContext context) => _chartCard();

  Widget _chartCard() {
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
          const SizedBox(height: ELayout.spaceSm),
          _goalLegend(),
          const SizedBox(height: ELayout.spaceMd),
          _chartArea(),
          ..._rangeScrubber(),
          const SizedBox(height: ELayout.spaceSm),
          _inspectExpander(),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.title, style: EText.section),
        _currentSummary(),
      ],
    );
  }

  Widget _currentSummary() {
    final latestPoint = _latestVisiblePoint();
    if (latestPoint == null) {
      return Text(
        widget.emptySummaryLabel,
        style: EText.caption.copyWith(color: EColors.textMuted),
      );
    }

    return Text(
      '${widget.formatValue(latestPoint.smoothedValue)}${widget.summarySuffix}',
      style: EText.caption.copyWith(
        color: _summaryColor(latestPoint.smoothedValue),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _goalLegend() {
    return Wrap(
      spacing: ELayout.spaceMd,
      runSpacing: ELayout.spaceXs,
      children: widget.goals
          .map(
            (goal) => _GoalChip(
              label: widget.showGoalDailyPace
                  ? goal.legendWithDailyPace()
                  : goal.label,
              color: goal.color,
            ),
          )
          .toList(),
    );
  }

  Widget _chartArea() {
    if (widget.points.length < 2) return _emptyState();

    return SizedBox(
      height: 180,
      child: LayoutBuilder(
        builder: (context, constraints) => _plot(constraints),
      ),
    );
  }

  Widget _plot(BoxConstraints constraints) {
    final plot = CustomPaint(
      size: Size(constraints.maxWidth, constraints.maxHeight),
      painter: RollingDailyPainter(
        points: widget.points,
        goals: widget.goals,
        lineColor: widget.lineColor,
        formatValue: widget.formatValue,
        displayStart: widget.displayStart,
        displayEnd: widget.displayEnd,
        inspectedPoint: _visibleInspectedPoint(),
        clockMinuteAxis: widget.clockMinuteAxis,
      ),
    );
    if (!_inspecting) return plot;
    return MouseRegion(
      onHover: (event) => _inspectAt(event.localPosition, constraints),
      child: GestureDetector(
        onTapDown: (details) => _inspectAt(details.localPosition, constraints),
        onPanUpdate: (details) =>
            _inspectAt(details.localPosition, constraints),
        child: plot,
      ),
    );
  }

  Widget _inspectExpander() {
    final RollingDailyPoint? inspectedPoint = _visibleInspectedPoint();
    return ChartInspectExpander(
      isExpanded: _inspecting,
      onToggle: _toggleInspecting,
      detail: inspectedPoint == null ? null : _inspectedSummary(inspectedPoint),
    );
  }

  Widget _inspectedSummary(RollingDailyPoint inspectedPoint) {
    return Text(
      '${_formatDate(inspectedPoint.date)} · '
      '${widget.formatValue(inspectedPoint.smoothedValue)} smoothed '
      '(${widget.formatValue(inspectedPoint.rollingValue)} raw)',
      style: EText.caption.copyWith(color: EColors.textTertiary),
    );
  }

  void _toggleInspecting() {
    setState(() {
      _inspecting = !_inspecting;
      if (_inspecting) _inspectedDate = _latestVisiblePoint()?.date;
    });
  }

  void _inspectAt(Offset position, BoxConstraints constraints) {
    final RollingDailyPoint? nearestPoint = _nearestPoint(
      position,
      constraints,
    );
    if (nearestPoint == null) return;
    setState(() => _inspectedDate = nearestPoint.date);
  }

  List<Widget> _rangeScrubber() {
    if (widget.rangeScrubber == null) return const [];
    return [const SizedBox(height: ELayout.spaceSm), widget.rangeScrubber!];
  }

  Widget _emptyState() {
    return SizedBox(
      height: 180,
      child: Center(child: Text('Need 2+ days of data', style: EText.caption)),
    );
  }

  RollingDailyPoint? _visibleInspectedPoint() {
    if (!_inspecting) return null;
    final List<RollingDailyPoint> visiblePoints = _visiblePoints();
    if (visiblePoints.isEmpty) return null;
    final DateTime? inspectedDate = _inspectedDate;
    if (inspectedDate == null) return visiblePoints.last;
    return visiblePoints.reduce((nearestPoint, point) {
      final int pointDistance = point.date
          .difference(inspectedDate)
          .inSeconds
          .abs();
      final int nearestDistance = nearestPoint.date
          .difference(inspectedDate)
          .inSeconds
          .abs();
      return pointDistance < nearestDistance ? point : nearestPoint;
    });
  }

  RollingDailyPoint? _latestVisiblePoint() {
    final visiblePoints = _visiblePoints();
    if (visiblePoints.isEmpty) return null;
    return visiblePoints.last;
  }

  List<RollingDailyPoint> _visiblePoints() {
    final displayStart = widget.displayStart;
    final displayEnd = widget.displayEnd;
    return widget.points.where((point) {
      if (displayStart != null && point.date.isBefore(displayStart)) {
        return false;
      }
      if (displayEnd != null && point.date.isAfter(displayEnd)) {
        return false;
      }
      return true;
    }).toList();
  }

  RollingDailyPoint? _nearestPoint(
    Offset position,
    BoxConstraints constraints,
  ) {
    final visiblePoints = _visiblePoints();
    if (visiblePoints.isEmpty) return null;

    final minDate = widget.displayStart ?? visiblePoints.first.date;
    final maxDate = widget.displayEnd ?? visiblePoints.last.date;
    final chartWidth =
        constraints.maxWidth -
        RollingDailyPainter.leftPadding -
        RollingDailyPainter.rightPadding;
    if (chartWidth <= 0) return visiblePoints.last;

    final chartX = (position.dx - RollingDailyPainter.leftPadding).clamp(
      0.0,
      chartWidth,
    );
    final dateRangeSeconds = maxDate.difference(minDate).inSeconds.toDouble();
    if (dateRangeSeconds <= 0) return visiblePoints.last;

    final hoveredDate = minDate.add(
      Duration(seconds: (dateRangeSeconds * chartX / chartWidth).round()),
    );
    return visiblePoints.reduce(
      (nearestPoint, point) =>
          _distanceFromDate(point, hoveredDate) <
              _distanceFromDate(nearestPoint, hoveredDate)
          ? point
          : nearestPoint,
    );
  }

  int _distanceFromDate(RollingDailyPoint point, DateTime date) =>
      point.date.difference(date).inSeconds.abs();

  Color _summaryColor(double value) {
    final goalsByValue = [...widget.goals]
      ..sort((first, second) => first.value.compareTo(second.value));
    var summaryColor = EColors.textTertiary;
    for (final goal in goalsByValue) {
      if (value >= goal.value) summaryColor = goal.color;
    }
    return summaryColor;
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';
}

class const _GoalChip({required final String label, required final Color color})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: EText.caption.copyWith(color: EColors.textMuted, fontSize: 10),
        ),
      ],
    );
  }
}
