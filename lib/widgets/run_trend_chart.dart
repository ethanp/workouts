import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/run_trend_painter.dart';
import 'package:workouts/widgets/trend_series.dart';

export 'package:workouts/widgets/trend_series.dart';

class RunTrendChart extends StatefulWidget {
  const RunTrendChart({
    super.key,
    required this.title,
    required this.series,
    this.displayStart,
    this.displayEnd,
  });

  final String title;
  final List<TrendSeries> series;
  final DateTime? displayStart;
  final DateTime? displayEnd;

  @override
  State<RunTrendChart> createState() => _RunTrendChartState();
}

class _RunTrendChartState extends State<RunTrendChart> {
  final Set<String> _hiddenSeries = {};
  Offset? _hoverPosition;

  List<TrendSeries> _visibleSeries() {
    return widget.series
        .where((s) => !_hiddenSeries.contains(s.label))
        .toList();
  }

  bool _hasEnoughData() {
    return widget.series.any((s) => s.points.length >= 2);
  }

  @override
  Widget build(BuildContext context) {
    final visibleSeries = _visibleSeries();
    return _chartCard(
      children: [
        _title(),
        const SizedBox(height: AppSpacing.sm),
        _legend(),
        const SizedBox(height: AppSpacing.md),
        _chartArea(visibleSeries),
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
      children: widget.series.map(_legendRow).toList(),
    );
  }

  TableRow _legendRow(TrendSeries series) {
    final isHidden = _hiddenSeries.contains(series.label);
    final trend = _seriesTrend(series);

    return TableRow(
      children: [
        _labelCell(series, isHidden),
        _latestValueCell(series.label, isHidden, trend.latest),
        _slopeCell(series.label, isHidden, trend.slope),
      ],
    );
  }

  Widget _labelCell(TrendSeries series, bool isHidden) {
    return _tappableCell(
      series.label,
      isHidden,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _colorDot(series.color),
          const SizedBox(width: 6),
          Text(
            series.label,
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
      onTap: () => _toggleSeries(label),
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

  void _toggleSeries(String label) {
    setState(() {
      if (_hiddenSeries.contains(label)) {
        _hiddenSeries.remove(label);
      } else {
        _hiddenSeries.add(label);
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

  ({String latest, String slope}) _seriesTrend(TrendSeries series) {
    if (series.points.isEmpty) return (latest: '', slope: '');
    final latestFormatted = series.formatValue(series.points.last.value);
    if (series.points.length < 2) return (latest: latestFormatted, slope: '');

    final trend = computeTrendLine(series.points, series.points.first.date);
    final sign = trend.slopePerMonth >= 0 ? '+' : '-';
    final slopeFormatted =
        '$sign${series.formatValue(trend.slopePerMonth.abs())}/mo';
    return (latest: latestFormatted, slope: slopeFormatted);
  }

  Widget _chartArea(List<TrendSeries> visibleSeries) {
    if (!_hasEnoughData()) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text('Need 2+ runs for trends', style: AppTypography.caption),
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
                painter: RunTrendPainter(
                  visibleSeries: visibleSeries,
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
}
