import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/models/cardio_route_point.dart';
import 'package:workouts/models/speed_sample.dart';

import 'heart_rate_and_speed_chart.dart';

class const CardioMetricsCard({
  required final List<HeartRateSample> samples,
  final List<CardioRoutePoint> routePoints = const [],
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speedSamples = SpeedSample.fromRoutePoints(routePoints);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardioMetricsHeader(samples: samples, speedSamples: speedSamples),
          const SizedBox(height: ELayout.spaceMd),
          CardioMetricsTimeline(samples: samples, speedSamples: speedSamples),
        ],
      ),
    );
  }
}

class const CardioMetricsHeader({
  required final List<HeartRateSample> samples,
  required final List<SpeedSample> speedSamples,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (samples.isNotEmpty) ..._heartRateSection() else ..._waitingState(),
        if (speedSamples.isNotEmpty) ...[
          const SizedBox(width: ELayout.spaceMd),
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
      CardioChartLegendDot(color: CardioChartSeries.heartRate.color),
      const SizedBox(width: ELayout.spaceXs),
      Text(
        'Avg $avg · Max $max',
        style: EText.caption.copyWith(color: EColors.textTertiary),
      ),
    ];
  }

  List<Widget> _waitingState() => [
    const Icon(Icons.favorite_border, color: EColors.textTertiary, size: 20),
    const SizedBox(width: ELayout.spaceXs),
    Text(
      'No heart rate data',
      style: EText.caption.copyWith(color: EColors.textTertiary),
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
        CardioChartLegendDot(color: CardioChartSeries.speed.color),
        const SizedBox(width: ELayout.spaceXs),
        Text(
          'Avg ${_mphCaption(avgKmh)} · Max ${_mphCaption(maxKmh)}',
          style: EText.caption.copyWith(color: EColors.textTertiary),
        ),
      ],
    );
  }

  String _mphCaption(double speedKmh) =>
      '${(speedKmh * 0.621371).toStringAsFixed(1)} mph';
}

class const CardioChartLegendDot({required final Color color})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class const CardioMetricsTimeline({
  required final List<HeartRateSample> samples,
  required final List<SpeedSample> speedSamples,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: HeartRateAndSpeedChart(
        samples: samples,
        speedSamples: speedSamples,
      ),
    );
  }
}
