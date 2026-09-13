import 'dart:math' as math;

import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/models/speed_sample.dart';
import 'package:workouts/theme/hr_zone_palette.dart';

class const HeartRateAndSpeedChart({
  required final List<HeartRateSample> samples,
  final List<SpeedSample> speedSamples = const [],
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (samples.length < 2) {
      return Container(
        decoration: BoxDecoration(
          color: EColors.surface,
          borderRadius: BorderRadius.circular(ELayout.radiusSm),
          border: Border.all(color: EColors.border),
        ),
        child: Center(
          child: Text(
            samples.isEmpty ? 'No samples yet' : '${samples.first.bpm} BPM',
            style: EText.caption.copyWith(color: EColors.textTertiary),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: EColors.surface,
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
        border: Border.all(color: EColors.border),
      ),
      child: CustomPaint(
        painter: _HeartRateAndSpeedPainter(
          samples: samples,
          speedSamples: speedSamples,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

enum CardioChartSeries({required final Color color}) {
  heartRate(color: EColors.danger),
  speed(color: EColors.success);
}

class _HeartRateAndSpeedPainter({
  required final List<HeartRateSample> samples,
  required final List<SpeedSample> speedSamples,
}) extends CustomPainter {
  static const _leftAxisWidth = 38.0;
  static const _rightPadding = 8.0;
  static const _topPadding = 8.0;
  static const _bottomAxisHeight = 22.0;
  static const _axisLabelFontSize = 10.0;
  static const _heartRateSmoothingWindowSize = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final timeDomain = _resolveTimeDomain();
    if (timeDomain == null) return;

    final plot = _ElapsedTimePlot(size: size, timeDomain: timeDomain);
    final heartRateScale = _heartRateScale();
    if (heartRateScale == null) return;

    _paintHeartRateZonesAndElapsedTimeAxes(
      canvas,
      plot,
      heartRateScale,
    );
    _strokeSmoothedHeartRateOverElapsedTime(
      canvas,
      plot,
      heartRateScale,
    );
    _strokeSpeedOverElapsedTime(canvas, plot);
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

  void _paintHeartRateZonesAndElapsedTimeAxes(
    Canvas canvas,
    _ElapsedTimePlot plot,
    _HeartRateScale heartRateScale,
  ) {
    _paintHeartRateZonesAsFaintBands(canvas, plot, heartRateScale);

    final gridPaint = Paint()
      ..color = EColors.border.withValues(alpha: 0.6)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    final axisPaint = Paint()
      ..color = EColors.textMuted.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    for (final tickBpm in heartRateScale.tickBpms) {
      final gridLineY = plot.yForNormalizedValue(
        heartRateScale.normalize(tickBpm),
      );
      canvas.drawLine(
        Offset(plot.left, gridLineY),
        Offset(plot.right, gridLineY),
        gridPaint,
      );
      _paintElapsedTimeOrBpmLabel(
        canvas,
        '$tickBpm',
        Offset(plot.left - 6, gridLineY),
        textAlign: TextAlign.right,
        anchor: _LabelAnchor.centerRight,
      );
    }

    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(plot.left, plot.top),
      Offset(plot.left, plot.bottom),
      axisPaint,
    );

    _paintElapsedTimeTickMarks(canvas, plot, axisPaint);
    _paintElapsedTimeLabels(canvas, plot);
  }

  void _paintHeartRateZonesAsFaintBands(
    Canvas canvas,
    _ElapsedTimePlot plot,
    _HeartRateScale heartRateScale,
  ) {
    for (
      var zoneIndex = 0;
      zoneIndex < HrZonePalette.zoneColors.length;
      zoneIndex++
    ) {
      final zoneBand = heartRateScale.visibleZoneBand(zoneIndex);
      if (zoneBand == null) continue;

      final bandTop = plot.yForNormalizedValue(
        heartRateScale.normalize(zoneBand.upperBpm),
      );
      final bandBottom = plot.yForNormalizedValue(
        heartRateScale.normalize(zoneBand.lowerBpm),
      );
      final bandRect = Rect.fromLTRB(
        plot.left,
        bandTop,
        plot.right,
        bandBottom,
      );
      canvas.drawRect(
        bandRect,
        Paint()
          ..color = HrZonePalette.zoneColors[zoneIndex].withValues(alpha: 0.08),
      );
    }
  }

  void _paintElapsedTimeLabels(Canvas canvas, _ElapsedTimePlot plot) {
    for (final elapsedTick in plot.elapsedTimeTicks) {
      final anchor = switch (elapsedTick.position) {
        _ElapsedTickPosition.start => _LabelAnchor.topLeft,
        _ElapsedTickPosition.middle => _LabelAnchor.topCenter,
        _ElapsedTickPosition.end => _LabelAnchor.topRight,
      };
      final textAlign = elapsedTick.position == _ElapsedTickPosition.end
          ? TextAlign.right
          : TextAlign.center;
      _paintElapsedTimeOrBpmLabel(
        canvas,
        Duration(milliseconds: elapsedTick.elapsedMilliseconds)
            .formattedElapsed,
        Offset(elapsedTick.x, plot.bottom + 7),
        textAlign: textAlign,
        anchor: anchor,
      );
    }
  }

  void _paintElapsedTimeTickMarks(
    Canvas canvas,
    _ElapsedTimePlot plot,
    Paint axisPaint,
  ) {
    for (final elapsedTick in plot.elapsedTimeTicks) {
      if (elapsedTick.position != _ElapsedTickPosition.middle) continue;
      canvas.drawLine(
        Offset(elapsedTick.x, plot.bottom),
        Offset(elapsedTick.x, plot.bottom + 4),
        axisPaint,
      );
    }
  }

  void _paintElapsedTimeOrBpmLabel(
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
          color: EColors.textMuted,
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

  void _strokeSmoothedHeartRateOverElapsedTime(
    Canvas canvas,
    _ElapsedTimePlot plot,
    _HeartRateScale heartRateScale,
  ) {
    final heartRatePaint = Paint()
      ..color = CardioChartSeries.heartRate.color
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
      final pointX = plot.xForTime(smoothedHeartRatePoint.timestamp);
      final pointY = plot.yForNormalizedValue(
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

  void _strokeSpeedOverElapsedTime(Canvas canvas, _ElapsedTimePlot plot) {
    if (speedSamples.length < 2) return;

    final minSpeed = speedSamples
        .map((speedSample) => speedSample.speedKmh)
        .min;
    final maxSpeed = speedSamples
        .map((speedSample) => speedSample.speedKmh)
        .max;
    final speedRange = (maxSpeed - minSpeed).clamp(0.1, double.infinity);

    final speedPaint = Paint()
      ..color = CardioChartSeries.speed.color.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final speedPath = Path();
    for (
      var sampleIndex = 0;
      sampleIndex < speedSamples.length;
      sampleIndex++
    ) {
      final speedSample = speedSamples[sampleIndex];
      final pointX = plot.xForTime(speedSample.timestamp);
      final normalizedSpeed = (speedSample.speedKmh - minSpeed) / speedRange;
      final pointY = plot.yForNormalizedValue(normalizedSpeed);
      if (sampleIndex == 0) {
        speedPath.moveTo(pointX, pointY);
      } else {
        speedPath.lineTo(pointX, pointY);
      }
    }
    canvas.drawPath(speedPath, speedPaint);
  }

  @override
  bool shouldRepaint(covariant _HeartRateAndSpeedPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.speedSamples != speedSamples;
  }
}

enum _LabelAnchor() {
  centerRight,
  topLeft,
  topCenter,
  topRight,
}

enum _ElapsedTickPosition() {
  start,
  middle,
  end,
}

class const _ElapsedTimeTick({
  required final double x,
  required final int elapsedMilliseconds,
  required final _ElapsedTickPosition position,
});

class _ElapsedTimePlot({
  required Size size,
  required final _TimeDomain timeDomain,
}) {
  this {
    left = _HeartRateAndSpeedPainter._leftAxisWidth;
    right = size.width - _HeartRateAndSpeedPainter._rightPadding;
    top = _HeartRateAndSpeedPainter._topPadding;
    bottom = size.height - _HeartRateAndSpeedPainter._bottomAxisHeight;
    width = right - left;
    height = bottom - top;
  }

  static const _minuteMilliseconds = 60 * 1000;
  static const _minimumElapsedLabelGapWidth = 44.0;
  static const _minuteSteps = [1, 2, 5, 10, 15, 20, 30, 60, 90, 120];

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

class const _HeartRateScale({
  required final int minBpm,
  required final int maxBpm,
}) {
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
    final rawLowerBpm = HrZone.values[zoneIndex].lowerBpm;
    final rawUpperBpm = zoneIndex == HrZonePalette.zoneColors.length - 1
        ? math.max(maxBpm, HrZone.values[zoneIndex].upperBpm)
        : HrZone.values[zoneIndex].upperBpm;

    final visibleLowerBpm = math.max(minBpm, rawLowerBpm);
    final visibleUpperBpm = math.min(maxBpm, rawUpperBpm);
    if (visibleUpperBpm <= visibleLowerBpm) return null;

    return _VisibleHeartRateZoneBand(
      lowerBpm: visibleLowerBpm,
      upperBpm: visibleUpperBpm,
    );
  }
}

class const _VisibleHeartRateZoneBand({
  required final int lowerBpm,
  required final int upperBpm,
});

class const _SmoothedHeartRatePoint({
  required final DateTime timestamp,
  required final double bpm,
});

class const _TimeDomain({
  required final DateTime startTime,
  required final int durationMilliseconds,
}) {
  double normalizedTime(DateTime sampleTime) {
    return sampleTime.difference(startTime).inMilliseconds /
        durationMilliseconds;
  }
}

