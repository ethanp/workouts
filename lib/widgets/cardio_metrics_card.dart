import 'dart:math' as math;

import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/features/settings/unit_system_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/theme/hr_zone_palette.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/utils/training_load_calculator.dart';

class CardioMetricsCard extends ConsumerWidget {
  const CardioMetricsCard({
    super.key,
    required this.samples,
    this.routePoints = const [],
  });

  final List<HeartRateSample> samples;
  final List<CardioRoutePoint> routePoints;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitSystem = ref.watch(unitSystemProvider);
    final speedSamples = _computeSpeedSamples(routePoints);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetricsHeader(
            samples: samples,
            speedSamples: speedSamples,
            unitSystem: unitSystem,
          ),
          const SizedBox(height: AppSpacing.md),
          _TimelinePreview(samples: samples, speedSamples: speedSamples),
        ],
      ),
    );
  }
}

class _MetricsHeader extends StatelessWidget {
  const _MetricsHeader({
    required this.samples,
    required this.speedSamples,
    required this.unitSystem,
  });

  final List<HeartRateSample> samples;
  final List<SpeedSample> speedSamples;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (samples.isNotEmpty) ..._heartRateSection() else ..._waitingState(),
        if (speedSamples.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.md),
          _speedSection(),
        ],
      ],
    );
  }

  List<Widget> _heartRateSection() {
    final bpmValues = samples.mapL((heartRateSample) => heartRateSample.bpm);
    final avg = (bpmValues.reduce((a, b) => a + b) / bpmValues.length).round();
    final max = bpmValues.reduce((a, b) => a > b ? a : b);

    return [
      _LegendDot(color: _hrColor),
      const SizedBox(width: AppSpacing.xs),
      Text(
        'Avg $avg · Max $max',
        style: AppTypography.caption.copyWith(color: AppColors.textColor3),
      ),
    ];
  }

  List<Widget> _waitingState() => [
    const Icon(CupertinoIcons.heart, color: AppColors.textColor3, size: 20),
    const SizedBox(width: AppSpacing.xs),
    Text(
      'No heart rate data',
      style: AppTypography.caption.copyWith(color: AppColors.textColor3),
    ),
  ];

  Widget _speedSection() {
    final speeds = speedSamples.mapL(
      (cardioSpeedSample) => cardioSpeedSample.speedKmh,
    );
    final avgKmh = speeds.reduce((a, b) => a + b) / speeds.length;
    final maxKmh = speeds.reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        _LegendDot(color: _speedColor),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'Avg ${Format.speed(avgKmh, unitSystem)} · Max ${Format.speed(maxKmh, unitSystem)}',
          style: AppTypography.caption.copyWith(color: AppColors.textColor3),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _TimelinePreview extends StatelessWidget {
  const _TimelinePreview({required this.samples, required this.speedSamples});

  final List<HeartRateSample> samples;
  final List<SpeedSample> speedSamples;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: MetricsMiniChart(samples: samples, speedSamples: speedSamples),
    );
  }
}

class MetricsMiniChart extends StatelessWidget {
  const MetricsMiniChart({
    super.key,
    required this.samples,
    this.speedSamples = const [],
  });

  final List<HeartRateSample> samples;
  final List<SpeedSample> speedSamples;

  @override
  Widget build(BuildContext context) {
    if (samples.length < 2) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.borderDepth1),
        ),
        child: Center(
          child: Text(
            samples.isEmpty ? 'No samples yet' : '${samples.first.bpm} BPM',
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: CustomPaint(
        painter: _DualMetricPainter(
          samples: samples,
          speedSamples: speedSamples,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

const _hrColor = AppColors.error;
const _speedColor = AppColors.success;

class _DualMetricPainter extends CustomPainter {
  _DualMetricPainter({required this.samples, required this.speedSamples});

  static const _leftAxisWidth = 38.0;
  static const _rightPadding = 8.0;
  static const _topPadding = 8.0;
  static const _bottomAxisHeight = 22.0;
  static const _axisLabelFontSize = 10.0;
  static const _heartRateSmoothingWindowSize = 5;

  final List<HeartRateSample> samples;
  final List<SpeedSample> speedSamples;

  @override
  void paint(Canvas canvas, Size size) {
    final timeDomain = _resolveTimeDomain();
    if (timeDomain == null) return;

    final chartLayout = _MetricChartLayout(size: size, timeDomain: timeDomain);
    final heartRateScale = _heartRateScale();
    if (heartRateScale == null) return;

    _drawChartBackground(canvas, chartLayout, heartRateScale);
    _drawHeartRateSeries(canvas, chartLayout, heartRateScale);
    _drawSpeedSeries(canvas, chartLayout);
  }

  _TimeDomain? _resolveTimeDomain() {
    final sampleTimes = [
      ...samples.map((heartRateSample) => heartRateSample.timestamp),
      ...speedSamples.map((speedSample) => speedSample.timestamp),
    ];
    if (sampleTimes.isEmpty) return null;

    final startTime = sampleTimes.reduce(
      (earlierTime, laterTime) =>
          earlierTime.isBefore(laterTime) ? earlierTime : laterTime,
    );
    final endTime = sampleTimes.reduce(
      (earlierTime, laterTime) =>
          earlierTime.isAfter(laterTime) ? earlierTime : laterTime,
    );
    final durationMilliseconds = endTime.difference(startTime).inMilliseconds;
    if (durationMilliseconds <= 0) return null;

    return _TimeDomain(
      startTime: startTime,
      durationMilliseconds: durationMilliseconds,
    );
  }

  _HeartRateScale? _heartRateScale() {
    if (samples.length < 2) return null;

    final minBpm = samples.map((sample) => sample.bpm).min;
    final maxBpm = samples.map((sample) => sample.bpm).max;
    final axisMinBpm = (minBpm / 10).floor() * 10;
    final axisMaxBpm = (maxBpm / 10).ceil() * 10;

    return _HeartRateScale(
      minBpm: axisMinBpm,
      maxBpm: axisMaxBpm <= axisMinBpm ? axisMinBpm + 10 : axisMaxBpm,
    );
  }

  void _drawChartBackground(
    Canvas canvas,
    _MetricChartLayout chartLayout,
    _HeartRateScale heartRateScale,
  ) {
    _drawHeartRateZoneBands(canvas, chartLayout, heartRateScale);

    final gridPaint = Paint()
      ..color = AppColors.borderDepth1.withValues(alpha: 0.6)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    final axisPaint = Paint()
      ..color = AppColors.textColor4.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    for (final tickBpm in heartRateScale.tickBpms) {
      final gridLineY = chartLayout.yForNormalizedValue(
        heartRateScale.normalize(tickBpm),
      );
      canvas.drawLine(
        Offset(chartLayout.left, gridLineY),
        Offset(chartLayout.right, gridLineY),
        gridPaint,
      );
      _drawAxisLabel(
        canvas,
        '$tickBpm',
        Offset(chartLayout.left - 6, gridLineY),
        textAlign: TextAlign.right,
        anchor: _LabelAnchor.centerRight,
      );
    }

    canvas.drawLine(
      Offset(chartLayout.left, chartLayout.bottom),
      Offset(chartLayout.right, chartLayout.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chartLayout.left, chartLayout.top),
      Offset(chartLayout.left, chartLayout.bottom),
      axisPaint,
    );

    _drawElapsedTimeTickMarks(canvas, chartLayout, axisPaint);
    _drawElapsedTimeLabels(canvas, chartLayout);
  }

  void _drawHeartRateZoneBands(
    Canvas canvas,
    _MetricChartLayout chartLayout,
    _HeartRateScale heartRateScale,
  ) {
    for (
      var zoneIndex = 0;
      zoneIndex < HrZonePalette.zoneColors.length;
      zoneIndex++
    ) {
      final zoneBand = heartRateScale.visibleZoneBand(zoneIndex);
      if (zoneBand == null) continue;

      final bandTop = chartLayout.yForNormalizedValue(
        heartRateScale.normalize(zoneBand.upperBpm),
      );
      final bandBottom = chartLayout.yForNormalizedValue(
        heartRateScale.normalize(zoneBand.lowerBpm),
      );
      final bandRect = Rect.fromLTRB(
        chartLayout.left,
        bandTop,
        chartLayout.right,
        bandBottom,
      );
      canvas.drawRect(
        bandRect,
        Paint()
          ..color = HrZonePalette.zoneColors[zoneIndex].withValues(alpha: 0.08),
      );
    }
  }

  void _drawElapsedTimeLabels(Canvas canvas, _MetricChartLayout chartLayout) {
    for (final elapsedTick in chartLayout.elapsedTimeTicks) {
      final anchor = switch (elapsedTick.position) {
        _ElapsedTickPosition.start => _LabelAnchor.topLeft,
        _ElapsedTickPosition.middle => _LabelAnchor.topCenter,
        _ElapsedTickPosition.end => _LabelAnchor.topRight,
      };
      final textAlign = elapsedTick.position == _ElapsedTickPosition.end
          ? TextAlign.right
          : TextAlign.center;
      _drawAxisLabel(
        canvas,
        _formatElapsedTime(elapsedTick.elapsedMilliseconds),
        Offset(elapsedTick.x, chartLayout.bottom + 7),
        textAlign: textAlign,
        anchor: anchor,
      );
    }
  }

  void _drawElapsedTimeTickMarks(
    Canvas canvas,
    _MetricChartLayout chartLayout,
    Paint axisPaint,
  ) {
    for (final elapsedTick in chartLayout.elapsedTimeTicks) {
      if (elapsedTick.position != _ElapsedTickPosition.middle) continue;
      canvas.drawLine(
        Offset(elapsedTick.x, chartLayout.bottom),
        Offset(elapsedTick.x, chartLayout.bottom + 4),
        axisPaint,
      );
    }
  }

  void _drawAxisLabel(
    Canvas canvas,
    String text,
    Offset anchorPoint, {
    TextAlign textAlign = TextAlign.left,
    required _LabelAnchor anchor,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: AppColors.textColor4,
          fontSize: _axisLabelFontSize,
        ),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    )..layout();

    final labelOffset = switch (anchor) {
      _LabelAnchor.centerRight => Offset(
        anchorPoint.dx - textPainter.width,
        anchorPoint.dy - textPainter.height / 2,
      ),
      _LabelAnchor.topLeft => anchorPoint,
      _LabelAnchor.topCenter => Offset(
        anchorPoint.dx - textPainter.width / 2,
        anchorPoint.dy,
      ),
      _LabelAnchor.topRight => Offset(
        anchorPoint.dx - textPainter.width,
        anchorPoint.dy,
      ),
    };
    textPainter.paint(canvas, labelOffset);
  }

  String _formatElapsedTime(int durationMilliseconds) {
    final duration = Duration(milliseconds: durationMilliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '${duration.inMinutes}:$seconds';
  }

  void _drawHeartRateSeries(
    Canvas canvas,
    _MetricChartLayout chartLayout,
    _HeartRateScale heartRateScale,
  ) {
    _drawHeartRatePath(canvas, chartLayout, heartRateScale);
  }

  void _drawHeartRatePath(
    Canvas canvas,
    _MetricChartLayout chartLayout,
    _HeartRateScale heartRateScale,
  ) {
    final heartRatePaint = Paint()
      ..color = _hrColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final heartRatePath = Path();
    final smoothedHeartRatePoints = _smoothedHeartRatePoints();
    for (
      var pointIndex = 0;
      pointIndex < smoothedHeartRatePoints.length;
      pointIndex++
    ) {
      final smoothedHeartRatePoint = smoothedHeartRatePoints[pointIndex];
      final pointX = chartLayout.xForTime(smoothedHeartRatePoint.timestamp);
      final pointY = chartLayout.yForNormalizedValue(
        heartRateScale.normalize(smoothedHeartRatePoint.bpm),
      );
      if (pointIndex == 0) {
        heartRatePath.moveTo(pointX, pointY);
      } else {
        heartRatePath.lineTo(pointX, pointY);
      }
    }
    canvas.drawPath(heartRatePath, heartRatePaint);
  }

  List<_SmoothedHeartRatePoint> _smoothedHeartRatePoints() {
    if (samples.length <= _heartRateSmoothingWindowSize) {
      return samples
          .map(
            (sample) => _SmoothedHeartRatePoint(
              timestamp: sample.timestamp,
              bpm: sample.bpm.toDouble(),
            ),
          )
          .toList();
    }

    final halfWindow = _heartRateSmoothingWindowSize ~/ 2;
    return List.generate(samples.length, (sampleIndex) {
      final windowStart = math.max(0, sampleIndex - halfWindow);
      final windowEnd = math.min(samples.length, sampleIndex + halfWindow + 1);
      var bpmTotal = 0;
      for (
        var windowIndex = windowStart;
        windowIndex < windowEnd;
        windowIndex++
      ) {
        bpmTotal += samples[windowIndex].bpm;
      }
      return _SmoothedHeartRatePoint(
        timestamp: samples[sampleIndex].timestamp,
        bpm: bpmTotal / (windowEnd - windowStart),
      );
    });
  }

  void _drawSpeedSeries(Canvas canvas, _MetricChartLayout chartLayout) {
    if (speedSamples.length < 2) return;

    final minSpeed = speedSamples
        .map((speedSample) => speedSample.speedKmh)
        .min;
    final maxSpeed = speedSamples
        .map((speedSample) => speedSample.speedKmh)
        .max;
    final speedRange = (maxSpeed - minSpeed).clamp(0.1, double.infinity);

    final speedPaint = Paint()
      ..color = _speedColor.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final speedPath = Path();
    for (
      var sampleIndex = 0;
      sampleIndex < speedSamples.length;
      sampleIndex++
    ) {
      final speedSample = speedSamples[sampleIndex];
      final pointX = chartLayout.xForTime(speedSample.timestamp);
      final normalizedSpeed = (speedSample.speedKmh - minSpeed) / speedRange;
      final pointY = chartLayout.yForNormalizedValue(normalizedSpeed);
      if (sampleIndex == 0) {
        speedPath.moveTo(pointX, pointY);
      } else {
        speedPath.lineTo(pointX, pointY);
      }
    }
    canvas.drawPath(speedPath, speedPaint);
  }

  @override
  bool shouldRepaint(covariant _DualMetricPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.speedSamples != speedSamples;
  }
}

enum _LabelAnchor { centerRight, topLeft, topCenter, topRight }

enum _ElapsedTickPosition { start, middle, end }

class _ElapsedTimeTick {
  const _ElapsedTimeTick({
    required this.x,
    required this.elapsedMilliseconds,
    required this.position,
  });

  final double x;
  final int elapsedMilliseconds;
  final _ElapsedTickPosition position;
}

class _MetricChartLayout {
  _MetricChartLayout({required Size size, required this.timeDomain}) {
    left = _DualMetricPainter._leftAxisWidth;
    right = size.width - _DualMetricPainter._rightPadding;
    top = _DualMetricPainter._topPadding;
    bottom = size.height - _DualMetricPainter._bottomAxisHeight;
    width = right - left;
    height = bottom - top;
  }

  static const _minuteMilliseconds = 60 * 1000;
  static const _minimumElapsedLabelGapWidth = 44.0;
  static const _minuteSteps = [1, 2, 5, 10, 15, 20, 30, 60, 90, 120];

  final _TimeDomain timeDomain;
  late final double left;
  late final double right;
  late final double top;
  late final double bottom;
  late final double width;
  late final double height;

  double xForTime(DateTime sampleTime) {
    return left + timeDomain.normalizedTime(sampleTime) * width;
  }

  double xForElapsedMilliseconds(int elapsedMilliseconds) {
    return left + elapsedMilliseconds / timeDomain.durationMilliseconds * width;
  }

  double yForNormalizedValue(double normalizedValue) {
    return bottom - normalizedValue.clamp(0.0, 1.0) * height;
  }

  List<_ElapsedTimeTick> get elapsedTimeTicks {
    final maxLabelCount = (width / 70).round().clamp(3, 6);
    final elapsedTimeTicks = <_ElapsedTimeTick>[
      _ElapsedTimeTick(
        x: left,
        elapsedMilliseconds: 0,
        position: _ElapsedTickPosition.start,
      ),
    ];

    final minuteStep = _minuteStepFor(maxLabelCount);
    for (
      var elapsedMinutes = minuteStep;
      elapsedMinutes * _minuteMilliseconds < timeDomain.durationMilliseconds;
      elapsedMinutes += minuteStep
    ) {
      final elapsedMilliseconds = elapsedMinutes * _minuteMilliseconds;
      final tickX = xForElapsedMilliseconds(elapsedMilliseconds);
      if (right - tickX < _minimumElapsedLabelGapWidth) continue;
      elapsedTimeTicks.add(
        _ElapsedTimeTick(
          x: tickX,
          elapsedMilliseconds: elapsedMilliseconds,
          position: _ElapsedTickPosition.middle,
        ),
      );
    }

    elapsedTimeTicks.add(
      _ElapsedTimeTick(
        x: right,
        elapsedMilliseconds: timeDomain.durationMilliseconds,
        position: _ElapsedTickPosition.end,
      ),
    );
    return elapsedTimeTicks;
  }

  int _minuteStepFor(int maxLabelCount) {
    for (final minuteStep in _minuteSteps) {
      final stepMilliseconds = minuteStep * _minuteMilliseconds;
      final middleLabelCount =
          (timeDomain.durationMilliseconds - 1) ~/ stepMilliseconds;
      if (middleLabelCount + 2 <= maxLabelCount) return minuteStep;
    }

    final middleLabelCapacity = math.max(1, maxLabelCount - 2);
    final durationMinutes =
        (timeDomain.durationMilliseconds / _minuteMilliseconds).ceil();
    return (durationMinutes / middleLabelCapacity).ceil();
  }
}

class _HeartRateScale {
  const _HeartRateScale({required this.minBpm, required this.maxBpm});

  final int minBpm;
  final int maxBpm;

  List<int> get tickBpms {
    final bpmRange = maxBpm - minBpm;
    final tickStep = bpmRange <= 30 ? 10 : 20;
    final ticks = <int>[];
    for (var tickBpm = minBpm; tickBpm <= maxBpm; tickBpm += tickStep) {
      ticks.add(tickBpm);
    }
    if (ticks.last != maxBpm) ticks.add(maxBpm);
    return ticks;
  }

  double normalize(num bpm) {
    final bpmRange = maxBpm - minBpm;
    if (bpmRange <= 0) return 0.5;
    return (bpm - minBpm) / bpmRange;
  }

  _VisibleHeartRateZoneBand? visibleZoneBand(int zoneIndex) {
    final rawLowerBpm = TrainingLoadCalculator.zoneBoundaries[zoneIndex];
    final rawUpperBpm = zoneIndex == HrZonePalette.zoneColors.length - 1
        ? math.max(maxBpm, TrainingLoadCalculator.zoneUpperBounds[zoneIndex])
        : TrainingLoadCalculator.zoneUpperBounds[zoneIndex];

    final visibleLowerBpm = math.max(minBpm, rawLowerBpm);
    final visibleUpperBpm = math.min(maxBpm, rawUpperBpm);
    if (visibleUpperBpm <= visibleLowerBpm) return null;

    return _VisibleHeartRateZoneBand(
      lowerBpm: visibleLowerBpm,
      upperBpm: visibleUpperBpm,
    );
  }
}

class _VisibleHeartRateZoneBand {
  const _VisibleHeartRateZoneBand({
    required this.lowerBpm,
    required this.upperBpm,
  });

  final int lowerBpm;
  final int upperBpm;
}

class _SmoothedHeartRatePoint {
  const _SmoothedHeartRatePoint({required this.timestamp, required this.bpm});

  final DateTime timestamp;
  final double bpm;
}

class _TimeDomain {
  const _TimeDomain({
    required this.startTime,
    required this.durationMilliseconds,
  });

  final DateTime startTime;
  final int durationMilliseconds;

  double normalizedTime(DateTime sampleTime) {
    return sampleTime.difference(startTime).inMilliseconds /
        durationMilliseconds;
  }
}

class SpeedSample {
  const SpeedSample({required this.timestamp, required this.speedKmh});

  final DateTime timestamp;
  final double speedKmh;
}

List<SpeedSample> _computeSpeedSamples(List<CardioRoutePoint> points) {
  final timedPoints = points.whereL(
    (routePoint) => routePoint.recordedAt != null,
  )..sortOn((routePoint) => routePoint.recordedAt!);

  if (timedPoints.length < 2) return [];

  const maxReasonableSpeedKmh = 35.0;
  final rawSamples = <SpeedSample>[];

  for (var pointIndex = 1; pointIndex < timedPoints.length; pointIndex++) {
    final previousPoint = timedPoints[pointIndex - 1];
    final currentPoint = timedPoints[pointIndex];
    final timeDeltaSeconds =
        currentPoint.recordedAt!
            .difference(previousPoint.recordedAt!)
            .inMilliseconds /
        1000.0;
    if (timeDeltaSeconds <= 0) continue;

    final distanceMeters = _haversineMeters(
      previousPoint.latitude,
      previousPoint.longitude,
      currentPoint.latitude,
      currentPoint.longitude,
    );
    final speedKmh = (distanceMeters / timeDeltaSeconds) * 3.6;
    if (speedKmh > maxReasonableSpeedKmh) continue;

    final midMs =
        currentPoint.recordedAt!
            .difference(previousPoint.recordedAt!)
            .inMilliseconds ~/
        2;
    final midTime = previousPoint.recordedAt!.add(
      Duration(milliseconds: midMs),
    );
    rawSamples.add(SpeedSample(timestamp: midTime, speedKmh: speedKmh));
  }

  return _rollingAverage(rawSamples, windowSize: 9);
}

double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dPhi = (lat2 - lat1) * math.pi / 180;
  final dLambda = (lon2 - lon1) * math.pi / 180;
  final haversine =
      math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(phi1) *
          math.cos(phi2) *
          math.sin(dLambda / 2) *
          math.sin(dLambda / 2);
  return earthRadius *
      2 *
      math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
}

List<SpeedSample> _rollingAverage(
  List<SpeedSample> samples, {
  required int windowSize,
}) {
  if (samples.length <= windowSize) return samples;
  final half = windowSize ~/ 2;
  return List.generate(samples.length, (sampleIndex) {
    final start = (sampleIndex - half).clamp(0, samples.length - 1);
    final end = (sampleIndex + half + 1).clamp(0, samples.length);
    final window = samples.sublist(start, end);
    final averageSpeed =
        window
            .map((speedSample) => speedSample.speedKmh)
            .reduce((firstSpeed, secondSpeed) => firstSpeed + secondSpeed) /
        window.length;
    return SpeedSample(
      timestamp: samples[sampleIndex].timestamp,
      speedKmh: averageSpeed,
    );
  });
}
