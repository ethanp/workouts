import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/metric_trend.dart';
import 'package:workouts/widgets/metric_trend_painter.dart';

class const MetricTrendChart({
  required final String title,
  required final List<MetricTrend> trends,
  final DateTime? displayStart,
  final DateTime? displayEnd,

  /// If non-null, points whose date falls on the same day get a ring
  /// drawn around them so the user can spot a specific session in a
  /// trend line.
  final DateTime? highlightDate,
}) extends StatefulWidget {
  @override
  State<MetricTrendChart> createState() => _MetricTrendChartState();
}

class _MetricTrendChartState() extends State<MetricTrendChart> {
  final Set<String> _hiddenTrendLabels = {};
  Offset? _hoverPosition;

  List<MetricTrend> _visibleTrends() {
    return widget.trends
        .where((metricTrend) => !_hiddenTrendLabels.contains(metricTrend.label))
        .toList();
  }

  bool _hasEnoughData() {
    return widget.trends.any((metricTrend) => metricTrend.points.length >= 2);
  }

  @override
  Widget build(BuildContext context) {
    final visibleTrends = _visibleTrends();
    return _chartCard(
      children: [
        _title(),
        const SizedBox(height: AppSpacing.sm),
        _legend(),
        const SizedBox(height: AppSpacing.md),
        _chartArea(visibleTrends),
      ],
    );
  }

  Widget _chartCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _title() {
    return Text(widget.title, style: AppTypography.subtitle);
  }

  Widget _legend() {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: IntrinsicColumnWidth(),
        2: IntrinsicColumnWidth(),
      },
      children: widget.trends.mapL(_legendRow),
    );
  }

  TableRow _legendRow(MetricTrend metricTrend) {
    final isHidden = _hiddenTrendLabels.contains(metricTrend.label);
    final latestAndSlope = _latestValueAndMonthlySlope(metricTrend);

    return TableRow(
      children: [
        _labelCell(metricTrend, isHidden),
        _latestValueCell(
          metricTrend.label,
          isHidden,
          latestAndSlope.latest,
        ),
        _slopeCell(metricTrend.label, isHidden, latestAndSlope.slope),
      ],
    );
  }

  Widget _labelCell(MetricTrend metricTrend, bool isHidden) {
    return _tappableCell(
      metricTrend.label,
      isHidden,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _colorDot(metricTrend.color),
          const SizedBox(width: 6),
          Text(
            metricTrend.label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textColor3,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _latestValueCell(String label, bool isHidden, String latest) {
    return _tappableCell(
      label,
      isHidden,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: Text(
          latest,
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor4,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _slopeCell(String label, bool isHidden, String slope) {
    return _tappableCell(
      label,
      isHidden,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        child: Text(
          slope,
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor4,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _tappableCell(String label, bool isHidden, {required Widget child}) {
    return GestureDetector(
      onTap: () => _toggleTrendVisibility(label),
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: isHidden ? 0.3 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: child,
        ),
      ),
    );
  }

  void _toggleTrendVisibility(String label) {
    setState(() {
      if (_hiddenTrendLabels.contains(label)) {
        _hiddenTrendLabels.remove(label);
      } else {
        _hiddenTrendLabels.add(label);
      }
    });
  }

  Widget _colorDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  _LegendLatestAndMonthlySlope _latestValueAndMonthlySlope(
    MetricTrend metricTrend,
  ) {
    if (metricTrend.points.isEmpty) {
      return const _LegendLatestAndMonthlySlope(latest: '', slope: '');
    }
    final latestFormatted = metricTrend.formatValue(
      metricTrend.points.last.value,
    );
    if (metricTrend.points.length < 2) {
      return _LegendLatestAndMonthlySlope(latest: latestFormatted, slope: '');
    }

    final trend = leastSquaresTrend(
      metricTrend.points,
      metricTrend.points.first.date,
    );
    final sign = trend.slopePerMonth >= 0 ? '+' : '-';
    final slopeFormatted =
        '$sign${metricTrend.formatValue(trend.slopePerMonth.abs())}/mo';
    return _LegendLatestAndMonthlySlope(
      latest: latestFormatted,
      slope: slopeFormatted,
    );
  }

  Widget _chartArea(List<MetricTrend> visibleTrends) {
    if (!_hasEnoughData()) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Need 2+ workouts for trends',
            style: AppTypography.caption,
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return MouseRegion(
            onHover: (event) =>
                setState(() => _hoverPosition = event.localPosition),
            onExit: (_) => setState(() => _hoverPosition = null),
            child: GestureDetector(
              onTapDown: (details) =>
                  setState(() => _hoverPosition = details.localPosition),
              onTapUp: (_) => setState(() => _hoverPosition = null),
              onTapCancel: () => setState(() => _hoverPosition = null),
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: MetricTrendPainter(
                  visibleTrends: visibleTrends,
                  displayStart: widget.displayStart,
                  displayEnd: widget.displayEnd,
                  hoverPosition: _hoverPosition,
                  highlightDate: widget.highlightDate,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class const _LegendLatestAndMonthlySlope({
  required final String latest,
  required final String slope,
});
