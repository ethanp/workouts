import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/models/run_route_point.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';

class RunMetricsCard extends ConsumerWidget {
  const RunMetricsCard({
    super.key,
    required this.samples,
    this.routePoints = const [],
  });

  final List<HeartRateSample> samples;
  final List<RunRoutePoint> routePoints;

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
  final List<_SpeedSample> speedSamples;
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
    final bpmValues = samples.map((s) => s.bpm).toList();
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
    final speeds = speedSamples.map((s) => s.speedKmh).toList();
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
  final List<_SpeedSample> speedSamples;

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
  final List<_SpeedSample> speedSamples;

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
  final List<_SpeedSample> speedSamples;

  @override
  void paint(Canvas canvas, Size size) {
    final allTimes = [
      ...samples.map((s) => s.timestamp),
      ...speedSamples.map((s) => s.timestamp),
    ];
    if (allTimes.isEmpty) return;

    final startTime = allTimes.reduce((a, b) => a.isBefore(b) ? a : b);
    final endTime = allTimes.reduce((a, b) => a.isAfter(b) ? a : b);
    final totalMs = endTime.difference(startTime).inMilliseconds;
    if (totalMs <= 0) return;

    double timeToX(DateTime t) =>
        t.difference(startTime).inMilliseconds / totalMs * size.width;

    if (samples.length >= 2) {
      final minBpm = samples.map((s) => s.bpm).reduce(math.min);
      final maxBpm = samples.map((s) => s.bpm).reduce(math.max);
      final bpmRange = (maxBpm - minBpm).clamp(1, 999).toDouble();

      double bpmToY(int bpm) {
        final normalized = (bpm - minBpm) / bpmRange;
        return size.height - normalized * size.height * 0.9 - size.height * 0.05;
      }

      // Horizontal grid lines every 10 bpm, drawn before the data line.
      final gridPaint = Paint()
        ..color = AppColors.borderDepth1.withValues(alpha: 0.6)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;

      final firstTick = (minBpm / 10).ceil() * 10;
      for (var tick = firstTick; tick <= maxBpm; tick += 10) {
        final y = bpmToY(tick);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }

      final hrPaint = Paint()
        ..color = _hrColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final hrPath = Path();
      for (var i = 0; i < samples.length; i++) {
        final x = timeToX(samples[i].timestamp);
        final y = bpmToY(samples[i].bpm);
        if (i == 0) {
          hrPath.moveTo(x, y);
        } else {
          hrPath.lineTo(x, y);
        }
      }
      canvas.drawPath(hrPath, hrPaint);
    }

    if (speedSamples.length >= 2) {
      final minSpeed = speedSamples.map((s) => s.speedKmh).reduce(math.min);
      final maxSpeed = speedSamples.map((s) => s.speedKmh).reduce(math.max);
      final speedRange = (maxSpeed - minSpeed).clamp(0.1, double.infinity);

      final speedPaint = Paint()
        ..color = _speedColor.withValues(alpha: 0.8)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final speedPath = Path();
      for (var i = 0; i < speedSamples.length; i++) {
        final x = timeToX(speedSamples[i].timestamp);
        final normalized = (speedSamples[i].speedKmh - minSpeed) / speedRange;
        final y = size.height - normalized * size.height * 0.9 - size.height * 0.05;
        if (i == 0) {
          speedPath.moveTo(x, y);
        } else {
          speedPath.lineTo(x, y);
        }
      }
      canvas.drawPath(speedPath, speedPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DualMetricPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.speedSamples != speedSamples;
  }
}

class _SpeedSample {
  const _SpeedSample({required this.timestamp, required this.speedKmh});

  final DateTime timestamp;
  final double speedKmh;
}

List<_SpeedSample> _computeSpeedSamples(List<RunRoutePoint> points) {
  final timedPoints = points
      .where((p) => p.recordedAt != null)
      .toList()
    ..sort((a, b) => a.recordedAt!.compareTo(b.recordedAt!));

  if (timedPoints.length < 2) return [];

  const maxReasonableSpeedKmh = 35.0;
  final rawSamples = <_SpeedSample>[];

  for (var i = 1; i < timedPoints.length; i++) {
    final prev = timedPoints[i - 1];
    final curr = timedPoints[i];
    final timeDeltaSeconds =
        curr.recordedAt!.difference(prev.recordedAt!).inMilliseconds / 1000.0;
    if (timeDeltaSeconds <= 0) continue;

    final distanceMeters = _haversineMeters(
      prev.latitude,
      prev.longitude,
      curr.latitude,
      curr.longitude,
    );
    final speedKmh = (distanceMeters / timeDeltaSeconds) * 3.6;
    if (speedKmh > maxReasonableSpeedKmh) continue;

    final midMs =
        curr.recordedAt!.difference(prev.recordedAt!).inMilliseconds ~/ 2;
    final midTime = prev.recordedAt!.add(Duration(milliseconds: midMs));
    rawSamples.add(_SpeedSample(timestamp: midTime, speedKmh: speedKmh));
  }

  return _rollingAverage(rawSamples, windowSize: 9);
}

double _haversineMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadius = 6371000.0;
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dPhi = (lat2 - lat1) * math.pi / 180;
  final dLambda = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(phi1) *
          math.cos(phi2) *
          math.sin(dLambda / 2) *
          math.sin(dLambda / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

List<_SpeedSample> _rollingAverage(
  List<_SpeedSample> samples, {
  required int windowSize,
}) {
  if (samples.length <= windowSize) return samples;
  final half = windowSize ~/ 2;
  return List.generate(samples.length, (i) {
    final start = (i - half).clamp(0, samples.length - 1);
    final end = (i + half + 1).clamp(0, samples.length);
    final window = samples.sublist(start, end);
    final avg =
        window.map((s) => s.speedKmh).reduce((a, b) => a + b) / window.length;
    return _SpeedSample(timestamp: samples[i].timestamp, speedKmh: avg);
  });
}
