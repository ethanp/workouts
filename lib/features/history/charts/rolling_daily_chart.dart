import 'package:flutter/cupertino.dart';
import 'package:workouts/features/history/charts/rolling_daily_painter.dart';
import 'package:workouts/features/history/charts/rolling_daily_point.dart';
import 'package:workouts/theme/app_theme.dart';

/// A smoothed trailing-7-day line chart with goal reference lines and a
/// drag-to-inspect readout. Driven entirely by configuration so it can render
/// any daily metric (Z2-5 minutes, active days, etc.).
class RollingDailyChart extends StatefulWidget {
  const RollingDailyChart({
    super.key,
    required this.title,
    required this.points,
    required this.goals,
    required this.lineColor,
    required this.formatValue,
    this.summarySuffix = '',
    this.inspectHint = 'Drag to inspect the trailing 7-day total',
    this.emptySummaryLabel = 'No data yet',
    this.displayStart,
    this.displayEnd,
  });

  final String title;
  final List<RollingDailyPoint> points;
  final List<RollingDailyGoal> goals;
  final Color lineColor;
  final String Function(double value) formatValue;
  final String summarySuffix;
  final String inspectHint;
  final String emptySummaryLabel;
  final DateTime? displayStart;
  final DateTime? displayEnd;

  @override
  State<RollingDailyChart> createState() => _RollingDailyChartState();
}

class _RollingDailyChartState extends State<RollingDailyChart> {
  Offset? _hoverPosition;
  RollingDailyPoint? _hoveredPoint;

  List<RollingDailyPoint> get points => widget.points;

  @override
  Widget build(BuildContext context) => _chartCard();

  Widget _chartCard() {
    return GestureDetector(
      onTap: _clearHoverPosition,
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
            const SizedBox(height: AppSpacing.sm),
            _goalLegend(),
            const SizedBox(height: AppSpacing.md),
            _chartArea(),
            const SizedBox(height: AppSpacing.sm),
            _hoveredPointSummary(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.title, style: AppTypography.subtitle),
        _currentSummary(),
      ],
    );
  }

  Widget _currentSummary() {
    final latestPoint = _latestVisiblePoint();
    if (latestPoint == null) {
      return Text(
        widget.emptySummaryLabel,
        style: AppTypography.caption.copyWith(color: AppColors.textColor4),
      );
    }

    return Text(
      '${widget.formatValue(latestPoint.smoothedValue)}${widget.summarySuffix}',
      style: AppTypography.caption.copyWith(
        color: _summaryColor(latestPoint.smoothedValue),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _goalLegend() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: widget.goals
          .map((goal) => _GoalChip(label: goal.label, color: goal.color))
          .toList(),
    );
  }

  Widget _chartArea() {
    if (points.length < 2) return _emptyState();

    return SizedBox(
      height: 180,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return MouseRegion(
            onHover: (event) =>
                _updateHoverPosition(event.localPosition, constraints),
            onExit: (_) => _clearHoverPosition(),
            child: GestureDetector(
              onTapDown: (details) =>
                  _updateHoverPosition(details.localPosition, constraints),
              onPanUpdate: (details) =>
                  _updateHoverPosition(details.localPosition, constraints),
              onPanEnd: (_) => _clearHoverPosition(),
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: RollingDailyPainter(
                  points: points,
                  goals: widget.goals,
                  lineColor: widget.lineColor,
                  formatValue: widget.formatValue,
                  displayStart: widget.displayStart,
                  displayEnd: widget.displayEnd,
                  hoverPosition: _hoverPosition,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return const SizedBox(
      height: 180,
      child: Center(
        child: Text('Need 2+ days of data', style: AppTypography.caption),
      ),
    );
  }

  Widget _hoveredPointSummary() {
    final hoveredPoint = _hoveredPoint;
    if (hoveredPoint == null) {
      return Text(
        widget.inspectHint,
        style: AppTypography.caption.copyWith(color: AppColors.textColor4),
      );
    }

    return Text(
      '${_formatDate(hoveredPoint.date)} · '
      '${widget.formatValue(hoveredPoint.smoothedValue)} smoothed '
      '(${widget.formatValue(hoveredPoint.rollingValue)} raw)',
      style: AppTypography.caption.copyWith(color: AppColors.textColor3),
    );
  }

  void _updateHoverPosition(Offset position, BoxConstraints constraints) {
    setState(() {
      _hoverPosition = position;
      _hoveredPoint = _nearestPoint(position, constraints);
    });
  }

  void _clearHoverPosition() {
    if (_hoverPosition == null && _hoveredPoint == null) return;
    setState(() {
      _hoverPosition = null;
      _hoveredPoint = null;
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
    return points.where((point) {
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
    var summaryColor = AppColors.textColor3;
    for (final goal in goalsByValue) {
      if (value >= goal.value) summaryColor = goal.color;
    }
    return summaryColor;
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({required this.label, required this.color});

  final String label;
  final Color color;

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
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor4,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
