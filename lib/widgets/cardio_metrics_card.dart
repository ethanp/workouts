import 'dart:math' as math;

import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';

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
      height: 120,
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

  final List<HeartRateSample> samples;
  final List<SpeedSample> speedSamples;

  @override
  void paint(Canvas canvas, Size size) {
    final timeDomain = _resolveTimeDomain();
    if (timeDomain == null) return;
    _drawHeartRateSeries(canvas, size, timeDomain);
    _drawSpeedSeries(canvas, size, timeDomain);
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

  void _drawHeartRateSeries(Canvas canvas, Size size, _TimeDomain timeDomain) {
    if (samples.length < 2) return;

    final minBpm = samples.map((sample) => sample.bpm).min;
    final maxBpm = samples.map((sample) => sample.bpm).max;
    final bpmRange = (maxBpm - minBpm).clamp(1, 999).toDouble();

    double bpmToY(int bpm) =>
        _normalizedY(size: size, normalizedValue: (bpm - minBpm) / bpmRange);

    _drawHeartRateGrid(canvas, size, minBpm, maxBpm, bpmToY);
    _drawHeartRatePath(canvas, size, timeDomain, bpmToY);
  }

  void _drawHeartRateGrid(
    Canvas canvas,
    Size size,
    int minBpm,
    int maxBpm,
    double Function(int bpm) bpmToY,
  ) {
    final gridPaint = Paint()
      ..color = AppColors.borderDepth1.withValues(alpha: 0.6)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final firstTick = (minBpm / 10).ceil() * 10;
    for (var tickBpm = firstTick; tickBpm <= maxBpm; tickBpm += 10) {
      final gridLineY = bpmToY(tickBpm);
      canvas.drawLine(
        Offset(0, gridLineY),
        Offset(size.width, gridLineY),
        gridPaint,
      );
    }
  }

  void _drawHeartRatePath(
    Canvas canvas,
    Size size,
    _TimeDomain timeDomain,
    double Function(int bpm) bpmToY,
  ) {
    final heartRatePaint = Paint()
      ..color = _hrColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final heartRatePath = Path();
    for (var sampleIndex = 0; sampleIndex < samples.length; sampleIndex++) {
      final sample = samples[sampleIndex];
      final pointX = timeDomain.timeToX(sample.timestamp, size.width);
      final pointY = bpmToY(sample.bpm);
      if (sampleIndex == 0) {
        heartRatePath.moveTo(pointX, pointY);
      } else {
        heartRatePath.lineTo(pointX, pointY);
      }
    }
    canvas.drawPath(heartRatePath, heartRatePaint);
  }

  void _drawSpeedSeries(Canvas canvas, Size size, _TimeDomain timeDomain) {
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
      final pointX = timeDomain.timeToX(speedSample.timestamp, size.width);
      final normalizedSpeed = (speedSample.speedKmh - minSpeed) / speedRange;
      final pointY = _normalizedY(size: size, normalizedValue: normalizedSpeed);
      if (sampleIndex == 0) {
        speedPath.moveTo(pointX, pointY);
      } else {
        speedPath.lineTo(pointX, pointY);
      }
    }
    canvas.drawPath(speedPath, speedPaint);
  }

  double _normalizedY({required Size size, required double normalizedValue}) {
    return size.height -
        normalizedValue * size.height * 0.9 -
        size.height * 0.05;
  }

  @override
  bool shouldRepaint(covariant _DualMetricPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.speedSamples != speedSamples;
  }
}

class _TimeDomain {
  const _TimeDomain({
    required this.startTime,
    required this.durationMilliseconds,
  });

  final DateTime startTime;
  final int durationMilliseconds;

  double timeToX(DateTime sampleTime, double chartWidth) {
    return sampleTime.difference(startTime).inMilliseconds /
        durationMilliseconds *
        chartWidth;
  }
}

class SpeedSample {
  const SpeedSample({required this.timestamp, required this.speedKmh});

  final DateTime timestamp;
  final double speedKmh;
}

List<SpeedSample> _computeSpeedSamples(List<CardioRoutePoint> points) {
  final timedPoints = points
      .whereL((routePoint) => routePoint.recordedAt != null)
    ..sortOn((routePoint) => routePoint.recordedAt!);

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
