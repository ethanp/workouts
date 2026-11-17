import 'dart:math' as math;

import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/same_type_workout_comparison.dart';

import 'cardio_detail_card.dart';
import 'same_type_metric.dart';

class const SameTypeComparisonCard({
  required final SameTypeWorkoutComparison comparison,
}) extends StatefulWidget {
  @override
  State<SameTypeComparisonCard> createState() => _SameTypeComparisonCardState();
}

class _SameTypeComparisonCardState() extends State<SameTypeComparisonCard> {
  static const _chartHeight = 180.0;

  String? _selectedWorkoutId;

  SameTypeWorkoutComparison get _comparison => widget.comparison;

  CardioWorkout get _selectedWorkout =>
      _comparison.peers
          .where((peer) => peer.id == _selectedWorkoutId)
          .firstOrNull ??
      _comparison.thisWorkout;

  bool get _selectedIsThisWorkout =>
      _selectedWorkout.id == _comparison.thisWorkout.id;

  @override
  Widget build(BuildContext context) {
    final metrics = SameTypeMetric.forType(_comparison.thisWorkout.activityType)
        .where((metric) => metric.valuesAcross(_comparison.peers).length >= 2)
        .toList();
    return CardioDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_comparison.thisWorkout.activityType.displayName} sessions',
            style: EText.section,
          ),
          const SizedBox(height: ELayout.spaceXs),
          Text(
            'Each line is scaled to its own range. Tap a session to compare.',
            style: EText.caption.copyWith(color: EColors.textMuted),
          ),
          const SizedBox(height: ELayout.spaceSm),
          if (metrics.isNotEmpty)
            SizedBox(height: _chartHeight, child: _chart(metrics)),
          const SizedBox(height: ELayout.spaceSm),
          Text(
            _selectionCaption,
            style: EText.caption.copyWith(
              color: EColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          EChartLegend(entries: metrics.mapL(_legendEntry)),
        ],
      ),
    );
  }

  String get _selectionCaption {
    final dayKey = _selectedWorkout.startedAt.dayKey;
    if (_selectedIsThisWorkout) return '$dayKey  ·  this workout';
    return dayKey;
  }

  Widget _chart(List<SameTypeMetric> metrics) {
    final peers = _comparison.peers;
    final first = peers.first.startedAt;
    final last = peers.last.startedAt;
    final padding = Duration(
      seconds: math.max(
        const Duration(hours: 12).inSeconds,
        (last.difference(first).inSeconds * 0.04).round(),
      ),
    );
    return EChart<String>(
      start: first.subtract(padding),
      end: last.add(padding),
      valueScale: const EChartValueScale(min: 0, max: 1, ticks: [0, 0.5, 1]),
      paintsValueTicks: false,
      leftPadding: 4,
      rightPadding: 4,
      series: metrics.mapL(_series),
      annotations: [
        if (!_selectedIsThisWorkout)
          _WorkoutMarker(
            date: _selectedWorkout.startedAt,
            color: EColors.textMuted.withValues(alpha: 0.5),
          ),
        _WorkoutMarker(
          date: _comparison.thisWorkout.startedAt,
          color: EColors.accent.withValues(alpha: 0.7),
        ),
      ],
      onPointSelected: (point) =>
          setState(() => _selectedWorkoutId = point?.pointId),
    );
  }

  EChartSeries<String> _series(SameTypeMetric metric) {
    final normalize = metric.normalizerAcross(_comparison.peers);
    return EChartSeries<String>.lineAndDots(
      id: metric.id,
      color: metric.color,
      strokeWidth: 1.6,
      points: [
        for (final peer in _comparison.peers)
          if (metric.valueOf(peer) case final value?)
            EChartPoint<String>(
              date: peer.startedAt,
              value: normalize(value),
              id: peer.id,
              color: metric.color,
              dotRadius: _dotRadius(peer),
            ),
      ],
    );
  }

  double _dotRadius(CardioWorkout peer) {
    if (peer.id == _comparison.thisWorkout.id) return 5;
    if (peer.id == _selectedWorkout.id) return 4;
    return 2.5;
  }

  EChartLegendEntry _legendEntry(SameTypeMetric metric) {
    return EChartLegendEntry(
      swatch: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: metric.color, shape: BoxShape.circle),
      ),
      label: metric.label,
      value: metric.captionFor(_selectedWorkout),
    );
  }
}

class _WorkoutMarker({required final DateTime date, required final Color color})
    extends EChartAnnotation {
  @override
  void paint(Canvas canvas, EChartPlot plot) {
    final x = plot.xForDate(date);
    canvas.drawLine(
      Offset(x, plot.top),
      Offset(x, plot.bottom),
      Paint()
        ..color = color
        ..strokeWidth = 1.5,
    );
  }
}
